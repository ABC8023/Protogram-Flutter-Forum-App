import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert'; // For Base64 decoding

class AdminApproved extends StatelessWidget {
  const AdminApproved({super.key});

  // Fetch approved posts from Firestore
  Stream<QuerySnapshot> _getApprovedPosts() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('status', isEqualTo: 'Approved')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Approved Posts"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getApprovedPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong!'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No Approved Posts'));
          }

          // Get all the approved posts
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
                        // Decode the Base64 image string and display it
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

                        // Approve and Reject buttons (optional for approved posts)
                        // You can display the post's details but not allow re-approval
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
