import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminStartupRejected extends StatefulWidget {
  const AdminStartupRejected({super.key});

  @override
  State<AdminStartupRejected> createState() => _AdminStartupRejectedState();
}

class _AdminStartupRejectedState extends State<AdminStartupRejected> {
  /* ───────────────────────────────────────────────────────── streams & state */

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() => FirebaseFirestore
      .instance
      .collection('startups')
      .where('status', isEqualTo: 'Rejected')
      .snapshots();


  /* ───────────────────────────────────────────────────────── UI */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejected Startups'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
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
        color: Colors.red.withOpacity(.6),
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
                ],
              ),
              const SizedBox(height: 6),
              Text(description, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 6),
              Text('Reason: $reason',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text(
                'Donation Goal: RM ${goal.round()}',
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
