import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'post_detail_screen.dart';

class ReportedPostsScreen extends StatefulWidget {
  @override
  _ReportedPostsScreenState createState() => _ReportedPostsScreenState();
}

class _ReportedPostsScreenState extends State<ReportedPostsScreen> {
  bool _selectionMode = false;
  List<String> _selectedPosts = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("All posts"),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "select") {
                setState(() {
                  _selectionMode = true;
                });
              }
            },
            itemBuilder: (context) =>
            [
              PopupMenuItem(
                value: "select",
                child: Text("Select post to be unreport"),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('reportedPosts')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty)
            return Center(child: Text("No reported posts available."));

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 images per row
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio: 1, // Ensures square aspect ratio
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var post = snapshot.data!.docs[index];
              String postId = post['postId'];

              List<dynamic> images = post['images'];
              String imageBase64 = images.isNotEmpty
                  ? images.first
                  : ""; // Get the first image

              return GestureDetector(
                onTap: _selectionMode
                    ? () {
                  setState(() {
                    if (_selectedPosts.contains(postId)) {
                      _selectedPosts.remove(postId);
                    } else {
                      _selectedPosts.add(postId);
                    }
                  });
                }
                    : () {
                  Get.to(() =>
                      PostDetailScreen(
                          postId: postId)); // ✅ Navigate to post details
                },
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.memory(
                        base64Decode(imageBase64),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    if (_selectionMode && _selectedPosts.contains(postId))
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Icon(Icons.check_circle, color: Colors.blue,
                            size: 24),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _selectionMode
          ? Padding(
        padding: EdgeInsets.all(10),
        child: OutlinedButton(
          onPressed: () async {
            for (String postId in _selectedPosts) {
              QuerySnapshot query = await FirebaseFirestore.instance
                  .collection('reportedPosts')
                  .where('postId', isEqualTo: postId)
                  .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .get();
              for (var doc in query.docs) {
                await doc.reference.delete();
              }
            }
            setState(() {
              _selectionMode = false;
              _selectedPosts.clear();
            });
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            side: const BorderSide(color: Colors.black, width: 2),
            backgroundColor: Colors.black,
          ),
          child: const Text(
            'UNREPORT',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      )
          : null,
    );
  }
}
