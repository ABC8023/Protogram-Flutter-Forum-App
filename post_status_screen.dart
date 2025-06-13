import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'dart:convert';

class PostStatusScreen extends StatefulWidget {
  @override
  _PostStatusScreenState createState() => _PostStatusScreenState();
}

class _PostStatusScreenState extends State<PostStatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Get.offAllNamed('/feed'),
        ),
        title: Text("Post Status"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: "Pending Action"),
            Tab(text: "Rejected History"),
            Tab(text: "Approval History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostList("Pending"),
          _buildRejectedPosts(), // Rejected now loads from `rejectedPosts` collection
          _buildPostList("Approved"),
        ],
      ),
    );
  }

  /// Build posts from main "posts" collection by status
  Widget _buildPostList(String status) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text("Not logged in."));
    }

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('status', isEqualTo: status)
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        if (snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No $status posts."));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            return _buildPostCard(doc, status);
          }).toList(),
        );
      },
    );
  }

  /// Build rejected posts from `rejectedPosts` collection
  Widget _buildRejectedPosts() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(child: Text("Not logged in."));
    }

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('rejectedPosts')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        if (snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No rejected posts."));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            return _buildPostCard(doc, "Rejected");
          }).toList(),
        );
      },
    );
  }

  /// Card UI for all posts
  Widget _buildPostCard(DocumentSnapshot doc, String status) {
    Color statusColor = status == "Pending"
        ? Colors.orange
        : status == "Rejected"
        ? Colors.red
        : Colors.green;

    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doc['topic'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 5),
            Text(doc['description'], style: TextStyle(fontSize: 14)),
            SizedBox(height: 10),
            if (doc['images'] != null && (doc['images'] as List).isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: (doc['images'] as List).map<Widget>((imageBase64) {
                    return GestureDetector(
                      onTap: () => _showImageDialog(imageBase64, context),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 5),
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: MemoryImage(base64Decode(imageBase64)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Posted on: ${_formatTimestamp(doc['timestamp'])}",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(status, style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Convert Firestore Timestamp to readable date
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
    }
    return "Unknown Date";
  }

  /// Image pop-up viewer
  void _showImageDialog(String imageBase64, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(10),
            child: Image.memory(base64Decode(imageBase64)),
          ),
        );
      },
    );
  }
}
