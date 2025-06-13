import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_app_asm/startupapproval.dart';
import 'package:mobile_app_asm/admin_forum.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:collection';
import 'package:intl/intl.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  String _selectedRange = 'Day';

  Future<Map<String, dynamic>> _fetchStatistics() async {
    final posts = await FirebaseFirestore.instance
        .collection('posts')
        .where('status', isEqualTo: 'Approved')
        .get();
    final rejected = await FirebaseFirestore.instance.collection('rejectedPosts').get();
    final startups = await FirebaseFirestore.instance
        .collection('startups')
        .where('status', isEqualTo: 'Pending')
        .get();

    return {
      'posts': posts.docs.length,
      'rejected': rejected.docs.length,
      'startups': startups.docs.length,
    };
  }

  Future<Map<String, int>> _fetchPostsByDate() async {
    final posts = await FirebaseFirestore.instance.collection('posts').get();
    final map = SplayTreeMap<String, int>();

    for (var doc in posts.docs) {
      Timestamp timestamp = doc['timestamp'];
      DateTime date = timestamp.toDate();
      String formattedDate;

      if (_selectedRange == 'Day') {
        formattedDate = DateFormat('MM/dd').format(date);
      } else if (_selectedRange == '24 Hour') {
        formattedDate = DateFormat.H().format(date); // Hour only: '0' to '23'
      } else {
        formattedDate = DateFormat('yyyy').format(date);
      }

      map.update(formattedDate, (value) => value + 1, ifAbsent: () => 1);
    }
    return map;
  }

  Widget _buildStatContainer(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildModuleCard({required String label, required String imagePath, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
        ),
        height: 150,
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black45, offset: Offset(2, 2), blurRadius: 5)],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Admin Dashboard"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Log Out",
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Get.offAllNamed('/');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = userSnapshot.data!.docs;
          final onlineUsers = users.where((doc) => doc['isOnline'] == true).length;
          final offlineUsers = users.length - onlineUsers;

          return FutureBuilder<Map<String, dynamic>>(
            future: _fetchStatistics(),
            builder: (context, statSnapshot) {
              if (!statSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              final stats = statSnapshot.data!;
              stats['users'] = users.length;
              stats['online'] = onlineUsers;
              stats['offline'] = offlineUsers;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "STATISTICS",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(child: _buildStatContainer("Online", stats['online'].toString(), Icons.circle, Colors.green)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildStatContainer("Offline", stats['offline'].toString(), Icons.circle, Colors.red)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Posts Over Time", style: TextStyle(color: Colors.white, fontSize: 16)),
                          DropdownButton(
                            value: _selectedRange,
                            dropdownColor: Colors.grey[900],
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white),
                            items: const ["Day", "24 Hour", "Year"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (val) => setState(() => _selectedRange = val!),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<Map<String, int>>(
                        future: _fetchPostsByDate(),
                        builder: (context, snap) {
                          if (!snap.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                          final data = snap.data!;
                          if (data.length <= 1 && _selectedRange == 'Year') {
                            return const Center(
                              child: Text("Not enough yearly data to plot.",
                                  style: TextStyle(color: Colors.white)),
                            );
                          }

                          return Container(
                            height: 200,
                            decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.all(12),
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1,
                                      getTitlesWidget: (value, _) => SideTitleWidget(
                                        axisSide: AxisSide.bottom,
                                        child: Text(
                                          data.keys.elementAt(value.toInt()),
                                          style: const TextStyle(color: Colors.white, fontSize: 10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: data.entries
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((e) => FlSpot(e.key.toDouble(), e.value.value.toDouble()))
                                        .toList(),
                                    isCurved: true,
                                    color: Colors.cyanAccent,
                                    barWidth: 3,
                                    dotData: FlDotData(show: true),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 2,
                        ),
                        children: [
                          _buildStatContainer("Total Users", stats['users'].toString(), Icons.people, Colors.cyan),
                          _buildStatContainer("Approved Posts", stats['posts'].toString(), Icons.check_circle, Colors.greenAccent),
                          _buildStatContainer("Rejected Posts", stats['rejected'].toString(), Icons.cancel, Colors.redAccent),
                          _buildStatContainer("Pending Startups", stats['startups'].toString(), Icons.pending, Colors.orangeAccent),
                        ],
                      ),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "MANAGEMENT PANEL",
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildModuleCard(label: "Admin Settings", imagePath: "assets/Images/admin1.png", onTap: () => Get.toNamed('/adminsetting')),
                      const SizedBox(height: 16),
                      _buildModuleCard(label: "User Control", imagePath: "assets/Images/admin2.png", onTap: () => Get.toNamed('/adminUsercontrol')),
                      const SizedBox(height: 16),
                      _buildModuleCard(label: "Post Approval", imagePath: "assets/Images/admin3.png", onTap: () => Get.toNamed('/postaprovement')),
                      const SizedBox(height: 16),
                      _buildModuleCard(label: "Forum Approval", imagePath: "assets/Images/admin4.png", onTap: () => Get.to(() => const AdminForumApproval())),
                      const SizedBox(height: 16),
                      _buildModuleCard(label: "Startup Approval", imagePath: "assets/Images/admin5.png", onTap: () => Get.to(() => const AdminStartupApproval())),
                      const SizedBox(height: 16),
                      _buildModuleCard(label: "Reported Content", imagePath: "assets/Images/admin6.png", onTap: () => Get.toNamed('/reportedContent')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
