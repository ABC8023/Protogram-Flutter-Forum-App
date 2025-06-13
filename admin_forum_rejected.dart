import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminForumRejected extends StatefulWidget {
  const AdminForumRejected({super.key});

  @override
  State<AdminForumRejected> createState() => _AdminForumRejectedState();
}

class _AdminForumRejectedState extends State<AdminForumRejected> {
  /* ───────────────────────────────────────────────────────── stream */

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() => FirebaseFirestore
      .instance
      .collection('forumPosts')
      .where('status', isEqualTo: 'Rejected')
      .orderBy('timestamp', descending: true)
      .snapshots();

  /* ───────────────────────────────────────────────────────── UI */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejected Forum Posts'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No rejected posts'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d   = docs[i].data();
              final List images = d['images'] ?? [];
              return _card(
                username        : d['username']     ?? 'User',
                profilePicBase64: d['profilePic'],
                content         : d['content']      ?? '',
                adminReason     : d['adminReason']  ?? '',   // optional
                imageBase64     : images.isNotEmpty ? images.first : null,
              );
            },
          );
        },
      ),
    );
  }

  /* ───────────────────────────────────────────────────────── card widget */

  Widget _card({
    required String  username,
    String? profilePicBase64,
    required String  content,
    required String  adminReason,
    String? imageBase64,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.red.withOpacity(.65),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── avatar + username ─────
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: (profilePicBase64 != null &&
                        profilePicBase64.isNotEmpty)
                        ? MemoryImage(base64Decode(profilePicBase64))
                        : null,
                    child: (profilePicBase64 == null ||
                        profilePicBase64.isEmpty)
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      username,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ───── post content ─────
              Text(content),

              const SizedBox(height: 8),

              // ───── rejection reason, if any ─────
              if (adminReason.isNotEmpty)
                Text('Reason: $adminReason',
                    style:
                    const TextStyle(fontSize: 13, color: Colors.white70)),

              const SizedBox(height: 10),

              // ───── first image (if any) ─────
              if (imageBase64 != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(imageBase64),
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                )
              else
                const Text('No image',
                    style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ),
    );
  }
}
