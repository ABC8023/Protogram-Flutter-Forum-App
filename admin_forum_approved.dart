import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminForumApproved extends StatefulWidget {
  const AdminForumApproved({super.key});

  @override
  State<AdminForumApproved> createState() => _AdminForumApprovedState();
}

class _AdminForumApprovedState extends State<AdminForumApproved> {
  /* ───────────────────────────────────────────────────────── streams & state */
  final _searchCtrl = TextEditingController();
  String _query = ''; // current search text

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() => FirebaseFirestore
      .instance
      .collection('forumPosts')
      .where('status', isEqualTo: 'Approved')
      .orderBy('timestamp', descending: true)
      .snapshots();

  /* ───────────────────────────────────────────────────────── helpers */
  Future<void> _deleteForum(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete forum post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('forumPosts')
          .doc(id)
          .delete();
      if (mounted) {
        Get.snackbar('Deleted', 'Forum post removed',
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  /* ───────────────────────────────────────────────────────── UI */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approved Forums'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ───────────── SEARCH BAR ─────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search forums…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSearch,
                ),
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),

          // ───────────── LIST ─────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }

                var docs = snap.data?.docs ?? [];

                // filter locally by query
                if (_query.isNotEmpty) {
                  docs = docs.where((d) {
                    final content =
                    (d.data()['content'] ?? '').toString().toLowerCase();
                    return content.contains(_query);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('No forums found'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (c, i) {
                    final data = docs[i].data();
                    final List images = data['images'] ?? [];
                    return _card(
                      docId: docs[i].id,
                      username: data['username'] ?? 'User',
                      profilePicBase64: data['profilePic'],
                      content: data['content'] ?? '',
                      imageBase64: images.isNotEmpty ? images.first : null,
                      likeCount: (data['likeCount'] ?? 0) as int,
                      commentCount: (data['commentCount'] ?? 0) as int,
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

  /* ───────────────────────────────────────────────────────── card widget */
  Widget _card({
    required String docId,
    required String username,
    String? profilePicBase64,
    required String content,
    String? imageBase64,
    required int likeCount,
    required int commentCount,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.teal.withOpacity(.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── avatar + username + delete ─────
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: profilePicBase64 != null &&
                        profilePicBase64.isNotEmpty
                        ? MemoryImage(base64Decode(profilePicBase64))
                        : null,
                    child: profilePicBase64 == null ||
                        profilePicBase64.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      username,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteForum(docId),
                  )
                ],
              ),
              const SizedBox(height: 10),

              // ───── content ─────
              Text(content),

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

              // ───── like & comment counts ─────
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.thumb_up_alt_outlined, size: 18),
                    const SizedBox(width: 4),
                    Text(likeCount.toString()),
                    const SizedBox(width: 16),
                    Icon(Icons.mode_comment_outlined, size: 18),
                    const SizedBox(width: 4),
                    Text(commentCount.toString()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
