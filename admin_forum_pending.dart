import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminForumPending extends StatelessWidget {
  const AdminForumPending({super.key});

  /* ───────────────────────────────────────────────────────── stream */
  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() =>
      FirebaseFirestore.instance
          .collection('forumPosts')
          .where('status', isEqualTo: 'Pending')
          .orderBy('timestamp', descending: true)
          .snapshots();

  /* ───────────────────────────────────────────────────────── helpers */
  Future<void> _approve(String id) async => FirebaseFirestore.instance
      .collection('forumPosts')
      .doc(id)
      .update({'status': 'Approved'});

  Future<void> _reject(String id) async => FirebaseFirestore.instance
      .collection('forumPosts')
      .doc(id)
      .update({'status': 'Rejected'});

  /* ───────────────────────────────────────────────────────── UI */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Forum Posts'),
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
            return const Center(child: Text('No pending posts'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final data = docs[i].data();
              final ref  = docs[i].reference;
              final List images = data['images'] ?? [];
              return _card(
                data       : data,
                imageBase64: images.isNotEmpty ? images.first : null,
                onApprove  : () => _approve(ref.id),
                onReject   : () => _reject (ref.id),
              );
            },
          );
        },
      ),
    );
  }

  /* ───────────────────────────────────────────────────────── card widget */
  Widget _card({
    required Map<String, dynamic> data,
    String?   imageBase64,
    required VoidCallback onApprove,
    required VoidCallback onReject,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.orange.withOpacity(.85),
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
                    backgroundImage: (data['profilePic'] != null &&
                        (data['profilePic'] as String).isNotEmpty)
                        ? MemoryImage(base64Decode(data['profilePic']))
                        : null,
                    child: (data['profilePic'] == null ||
                        (data['profilePic'] as String).isEmpty)
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data['username'] ?? 'User',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ───── content text ─────
              Text(
                data['content'] ?? '',
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),

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
                ),

              const SizedBox(height: 12),

              // ───── approve / reject buttons ─────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    onPressed: onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    onPressed: onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
