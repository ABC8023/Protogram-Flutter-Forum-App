import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class PostDetailScreen extends StatelessWidget {
  final String postId;

  PostDetailScreen({required this.postId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Post Details")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return Center(child: Text("Post not found"));

          var postData = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: postData['profilePic'] != null
                          ? MemoryImage(base64Decode(postData['profilePic']))
                          : AssetImage("assets/user_profile.png") as ImageProvider,
                    ),
                    SizedBox(width: 10),
                    Text(postData['username'] ?? "Unknown",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Spacer(),
                    Text(_formatTimestamp(postData['timestamp'])),
                  ],
                ),
                SizedBox(height: 10),
                Text(postData['topic'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text(postData['description']),
                SizedBox(height: 10),

                // Display Images if Available
                if (postData['images'] != null && (postData['images'] as List).isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: (postData['images'] as List).length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 5),
                          width: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: MemoryImage(base64Decode(postData['images'][index])),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(icon: Icon(Icons.thumb_up), onPressed: () {}),
                        Text("0"),
                        IconButton(icon: Icon(Icons.thumb_down), onPressed: () {}),
                        Text("0"),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(icon: Icon(Icons.comment), onPressed: () {}),
                        Text("0"),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// **Format Timestamp**
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}";
    }
    return "Unknown Date";
  }
}