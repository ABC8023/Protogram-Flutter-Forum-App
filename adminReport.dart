import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert'; // For Base64 decoding

class AdminReported extends StatelessWidget {
  const AdminReported({super.key});

  Stream<QuerySnapshot> _getReportedPosts() {
    return FirebaseFirestore.instance
        .collection('reportedPosts')

        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Reported Posts"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getReportedPosts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong!'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No Reported Posts'));
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final String reportId = post.id;
              final String description = post['description'] ?? 'No Description';
              final String topic = post['topic'] ?? 'No Topic';
              final String timestamp = (post['timestamp'] as Timestamp).toDate().toString();
              final List<dynamic> images = post['images'] ?? [];
              final String originalPostId = post['postId'] ?? reportId;

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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (image != null && image is String && image.length > 50)
                          Builder(
                            builder: (_) {
                              try {
                                return Image.memory(
                                  base64Decode(image),
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                );
                              } catch (_) {
                                return const Text(
                                  "Invalid image format",
                                  style: TextStyle(color: Colors.red),
                                );
                              }
                            },
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // ✅ APPROVE REPORT (delete post + delete report)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final reportRef = FirebaseFirestore.instance
                                        .collection('reportedPosts')
                                        .doc(reportId);

                                    try {
                                      // Delete the original post
                                      await FirebaseFirestore.instance
                                          .collection('posts')
                                          .doc(originalPostId)
                                          .delete();

                                      // Delete the report
                                      await reportRef.delete();
                                    } catch (e) {
                                      print("Error while approving report: $e");
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text(
                                    'Approve Report',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // ❌ REJECT REPORT (keep post, delete only report)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final reportRef = FirebaseFirestore.instance
                                        .collection('reportedPosts')
                                        .doc(reportId);

                                    try {
                                      await reportRef.delete();
                                    } catch (e) {
                                      print("Error while rejecting report: $e");
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: const Text(
                                    'Reject Report',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
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
