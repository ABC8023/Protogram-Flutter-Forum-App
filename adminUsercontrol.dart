import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:typed_data';

class AdminUserControl extends StatefulWidget {
  const AdminUserControl({super.key});

  @override
  State<AdminUserControl> createState() => _AdminUserControlState();
}

class _AdminUserControlState extends State<AdminUserControl> {
  String searchQuery = "";

  Stream<QuerySnapshot> _usersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  void _toggleBlock(String uid, bool currentState) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isBlocked': !currentState,
    });
  }

  void _terminateUserWithReason(String uid, String email, String? profilePic) async {
    final reasons = [
      "Harassment or bullying",
      "Hate speech or symbols",
      "Nudity or sexual activity",
      "Spam",
      "Fake profile",
    ];
    String? selectedReason;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Termination Reason"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (profilePic != null)
                  CircleAvatar(
                    backgroundImage: MemoryImage(base64Decode(profilePic)),
                    radius: 25,
                  )
                else
                  const CircleAvatar(
                    child: Icon(Icons.person),
                    radius: 25,
                  ),
                const SizedBox(height: 10),
                Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...reasons.map((reason) {
                  return ListTile(
                    title: Text(reason),
                    leading: Radio<String>(
                      value: reason,
                      groupValue: selectedReason,
                      onChanged: (value) {
                        setState(() => selectedReason = value);
                      },
                    ),
                  );
                }).toList(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: selectedReason == null
                    ? null
                    : () {
                  Navigator.pop(context);
                  _confirmTermination(uid, selectedReason!);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                ),
                child: const Text("Confirm"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmTermination(String uid, String reason) async {
    await FirebaseFirestore.instance.collection('activityLogs').add({
      'uid': uid,
      'action': 'terminated',
      'reason': reason,
      'timestamp': Timestamp.now(),
    });
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    Get.snackbar("User Terminated", "Reason: $reason",
        backgroundColor: Colors.red, colorText: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("User Control"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by email...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _usersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!.docs.where((doc) {
                  final email = doc['email']?.toString().toLowerCase() ?? "";
                  return email.contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final uid = user.id;
                    final email = user['email'] ?? 'No Email';
                    final isBlocked = user['isBlocked'] ?? false;
                    final name = user['name'] ?? 'N/A';
                    final dob = user['dob'] ?? 'N/A';
                    final country = user['country'] ?? 'N/A';

                    String? profilePic;
                    if (user.data().toString().contains('profilePic')) {
                      profilePic = user['profilePic'];
                    }

                    return ExpansionTile(
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: (profilePic != null)
                            ? MemoryImage(base64Decode(profilePic))
                            : null,
                        child: (profilePic == null)
                            ? const Icon(Icons.person, color: Colors.black)
                            : null,
                      ),
                      title: Text(email),
                      subtitle: Text(uid),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Name: $name"),
                              Text("Birthday: $dob"),
                              Text("Country: $country"),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Blocked Status: ${isBlocked ? 'Blocked' : 'Active'}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Switch(
                                    value: isBlocked,
                                    onChanged: (value) => _toggleBlock(uid, isBlocked),
                                    activeColor: Colors.orange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _terminateUserWithReason(uid, email, profilePic),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[800],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: const Text(
                                    'Terminate',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
