import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert'; // For Base64 decoding

class AdminPending extends StatelessWidget {
  const AdminPending({super.key});

  // Fetch posts from Firestore where status is "Pending"
  Stream<QuerySnapshot> _getPendingPosts() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('status', isEqualTo: 'Pending')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Pending Posts"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPendingPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong!'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No Pending Posts'));
          }

          // Get all the pending posts
          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final String postId = post.id;
              final String description = post['description'] ?? 'No Description';
              final String topic = post['topic'] ?? 'No Topic';
              final String timestamp = (post['timestamp'] as Timestamp).toDate().toString();
              final List<dynamic> images = post['images'] ?? [];
              final String? profilePic = post['profilePic']; // Assuming 'profilePic' field exists

              // If there are images, decode the first one
              final image = images.isNotEmpty ? images[0] : null;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.black.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display Post Description and Topic
                        Text(
                          topic,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Date: $timestamp",
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),

                        // Display Post Image Below Description
                        const SizedBox(height: 16),
                        if (image != null)
                          Image.memory(
                            base64Decode(image), // Decode the base64 image string
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              "No Image Available",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Approve and Reject buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // Approve the post by updating its status to 'Approved'
                                FirebaseFirestore.instance
                                    .collection('posts')
                                    .doc(postId)
                                    .update({'status': 'Approved'});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, // Green color for approve button
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20), // Adjusted border radius
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), // Adjusted padding
                                side: BorderSide(color: Colors.black, width: 2), // Border for the button
                              ),
                              child: const Text(
                                'Approve',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            ElevatedButton(
                              onPressed: () async {
                                final doc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
                                if (doc.exists) {
                                  final data = doc.data()!;
                                  await FirebaseFirestore.instance.collection('rejectedPosts').doc(postId).set({
                                    ...data,
                                    'status': 'Rejected',
                                  });
                                  // Now delete from original posts collection
                                  await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                                }
                              },

                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red, // Red color for reject button
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20), // Adjusted border radius
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), // Adjusted padding
                                side: const BorderSide(color: Colors.black, width: 2), // Border for the button
                              ),
                              child: const Text(
                                'Reject',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          ],
                        ),
                      ],
                    ),
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
