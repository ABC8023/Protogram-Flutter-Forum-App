import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminPostApproval extends StatefulWidget {
  const AdminPostApproval({super.key});

  @override
  State<AdminPostApproval> createState() => _AdminPostApprovalState();
}

class _AdminPostApprovalState extends State<AdminPostApproval> {
  bool hasPendingPosts = false;
  List<DocumentSnapshot> pendingPosts = [];

  @override
  void initState() {
    super.initState();
    _checkPendingPosts();
  }

  // Check Firestore for pending posts
  Future<void> _checkPendingPosts() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('status', isEqualTo: 'Pending')
        .get();

    setState(() {
      hasPendingPosts = snapshot.docs.isNotEmpty;
      pendingPosts = snapshot.docs;
    });
  }

  // Approve post by updating Firestore
  Future<void> _approvePost(String postId) async {
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'status': 'Approved',
    });
    _checkPendingPosts();
  }

  // Disapprove post by updating Firestore
  Future<void> _disapprovePost(String postId) async {
    await FirebaseFirestore.instance.collection('posts').doc(postId).update({
      'status': 'Rejected',
    });
    _checkPendingPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Post Approval"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Manage posts',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Buttons for Approved / Pending
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 400,
                  child: Column(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Get.toNamed('/adminApproved'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                          ),
                          child: SizedBox.expand( // 🔧 Force fill vertically
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.check_circle, color: Colors.white, size: 30),
                                SizedBox(height: 6),
                                Text(
                                  'View Approved\nPosts',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Get.toNamed('/adminRejected'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                            ),
                          ),
                          child: SizedBox.expand( // 🔧 Force fill vertically
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.cancel, color: Colors.white, size: 30),
                                SizedBox(height: 6),
                                Text(
                                  'View Rejected\nPosts',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),


                const SizedBox(width: 20),
                SizedBox(
                  width: 150,
                  height: 400,
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ElevatedButton(
                        onPressed: () => Get.toNamed('/adminPending'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.hourglass_empty,
                                color: Colors.white, size: 40),
                            SizedBox(height: 8),
                            Text(
                              'View Pending Posts',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      if (hasPendingPosts)
                        const Positioned(
                          top: 5,
                          right: 5,
                          child: Icon(Icons.notifications_active,
                              color: Colors.red, size: 30),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🔽 Display Pending Posts (example)
            Expanded(
              child: ListView.builder(
                itemCount: pendingPosts.length,
                itemBuilder: (context, index) {
                  var post = pendingPosts[index];
                  var postId = post.id;
                  var title = post['topic'] ?? 'No Topic';


                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
