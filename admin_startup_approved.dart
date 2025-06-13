import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminStartupApproved extends StatefulWidget {
  const AdminStartupApproved({super.key});

  @override
  State<AdminStartupApproved> createState() => _AdminStartupApprovedState();
}

class _AdminStartupApprovedState extends State<AdminStartupApproved> {
  /* ───────────────────────────────────────────────────────── streams & state */
  final _searchCtrl = TextEditingController();
  String _query = '';               // current search text

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() => FirebaseFirestore
      .instance
      .collection('startups')
      .where('status', isEqualTo: 'Approved')
      .snapshots();

  /* ───────────────────────────────────────────────────────── helpers */
  Future<void> _deleteStartup(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete startup?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('startups').doc(id).delete();
      if (mounted) {
        Get.snackbar('Deleted', 'Startup removed',
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
        title: const Text('Approved Startups'),
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
                hintText: 'Search startups…',
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
                    final data = d.data();
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final desc = (data['description'] ?? '').toString().toLowerCase();
                    return name.contains(_query) || desc.contains(_query);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text('No startups found'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (c, i) {
                    final d   = docs[i].data();
                    final img = (d['images'] as List?)?.first;
                    return _card(
                      docId     : docs[i].id,
                      name      : d['name'] ?? 'Untitled',
                      description: d['description'] ?? '',
                      reason     : d['reason'] ?? '',
                      goal       : (d['donationGoal'] ?? 0).toDouble(),
                      progress   : (d['donationProgress'] ?? 0).toDouble(),
                      imageBase64: img,
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
    required String name,
    required String description,
    required String reason,
    required double goal,
    required double progress,
    String? imageBase64,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: Colors.green.withOpacity(.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ───── name + delete ─────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteStartup(docId),
                  )
                ],
              ),
              const SizedBox(height: 6),
              Text(description, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 6),
              Text('Reason: $reason',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: goal == 0 ? 0 : progress / goal,
                color: Colors.green,
                backgroundColor: Colors.white24,
              ),
              Text(
                'RM ${progress.round()} / RM ${goal.round()}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if (imageBase64 != null)
                Image.memory(
                  base64Decode(imageBase64),
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
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
