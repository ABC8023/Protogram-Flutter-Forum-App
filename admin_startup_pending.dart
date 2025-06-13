import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminStartupPending extends StatelessWidget {
  const AdminStartupPending({super.key});

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() =>
      FirebaseFirestore.instance
          .collection('startups')
          .where('status', isEqualTo: 'Pending')
          .snapshots();

  Future<void> _approve(String id) async => FirebaseFirestore.instance
      .collection('startups')
      .doc(id)
      .update({'status': 'Approved'});

  Future<void> _reject(String id) async => FirebaseFirestore.instance
      .collection('startups')
      .doc(id)
      .update({'status': 'Rejected'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Pending Startups'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          centerTitle: true),
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
            return const Center(child: Text('No pending startups'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (c, i) {
              final ref = docs[i].reference;
              final d = docs[i].data();
              final img = (d['images'] as List?)?.first;
              return _card(
                data: d,
                imageBase64: img,
                onApprove: () => _approve(ref.id),
                onReject: () => _reject(ref.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _card({
    required Map<String, dynamic> data,
    required String? imageBase64,
    required VoidCallback onApprove,
    required VoidCallback onReject,
  }) =>
      Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Colors.orange.withOpacity(.8),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['name'] ?? 'Untitled',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Text(data['description'] ?? '',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 6),
              Text('Reason: ${data['reason'] ?? ''}',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 6),
              Text(
                'Donation Goal: RM ${(data['donationGoal'] ?? 0).toDouble().toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              if (imageBase64 != null)
                Image.memory(base64Decode(imageBase64),
                    width: double.infinity, height: 180, fit: BoxFit.cover)
              else
                const Text('No image',
                    style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  onPressed: onReject,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                ),
              ])
            ]),
          ),
        ),
      );
}
