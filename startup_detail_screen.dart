import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:share_plus/share_plus.dart';        // ⬅️ NEW
import 'donate_screen.dart';

class StartupDetailScreen extends StatefulWidget {
  const StartupDetailScreen({super.key, required this.startupId});

  final String startupId;

  @override
  State<StartupDetailScreen> createState() => _StartupDetailScreenState();
}

class _StartupDetailScreenState extends State<StartupDetailScreen> {
  final PageController _pageCtrl = PageController();

  void _shareStartup({
    required String name,
    required String description,
    required String reason,
    required double goal,
    required double progress,
  }) {
    final shareText = '''
🚀 $name
  
  $description
  
  Reason: $reason
  Goal: RM${goal.toStringAsFixed(0)}
  Collected so far: RM${progress.toStringAsFixed(0)}
  
  — sent from MyStartupApp
  ''';

      Share.share(shareText, subject: name);
  }

  Future<void> _deleteStartup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete startup?'),
        content: const Text('This action can’t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('startups')
        .doc(widget.startupId)
        .delete();

    if (mounted) {
      Get.back();                                       // leave detail page
      Get.snackbar('Deleted', 'Your startup was removed',
          snackPosition: SnackPosition.BOTTOM);
    }
  }


  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _stream() =>
      FirebaseFirestore.instance
          .collection('startups')
          .doc(widget.startupId)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Details'),
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _stream(),        // same stream you already use
            builder: (context, snap) {
              if (!snap.hasData || !snap.data!.exists) {
                return const SizedBox.shrink();   // no buttons until data arrives
              }

              final d         = snap.data!.data()!;
              final name      = d['name']            ?? 'Unnamed';
              final descr     = d['description']     ?? '';
              final reason    = d['reason']          ?? '';
              final goal      = (d['donationGoal']   ?? 0).toDouble();
              final progress  = (d['donationProgress'] ?? 0).toDouble();

              final user      = FirebaseAuth.instance.currentUser;
              final isOwner   = user != null && d['userId'] == user.uid;

              return Row(
                children: [
                  // ── SHARE ────────────────────────────────────────────────
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'Share',
                    onPressed: () => _shareStartup(
                      name: name,
                      description: descr,
                      reason: reason,
                      goal: goal,
                      progress: progress,
                    ),
                  ),

                  // ── DELETE (only for owner) ──────────────────────────────
                  if (isOwner)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete Startup',
                      onPressed: _deleteStartup,
                    ),
                ],
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Startup not found'));
          }

          final d = snap.data!.data()!;
          final name = d['name'] ?? 'Unnamed';
          final description = d['description'] ?? '';
          final reason = d['reason'] ?? '';
          final goal = (d['donationGoal'] ?? 0).toDouble();
          final progress = (d['donationProgress'] ?? 0).toDouble();
          final imgUrl = d['imageUrl'] ?? '';
          final images = (d['images'] as List?) ?? [];

          /* ───────────── build the list of widgets to show ───────────── */
          final List<Widget> _allImages = [
            if (imgUrl.toString().isNotEmpty)
              Image.network(
                imgUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image, size: 80)),
              ),
            ...images
                .where((e) => e != null && e.toString().isNotEmpty)
                .map((b64) => Image.memory(
              base64Decode(b64),
              width: double.infinity,
              fit: BoxFit.cover,
            )),
          ];

          Widget topImage;
          if (_allImages.isEmpty) {
            topImage = const SizedBox(
              width: double.infinity,
              height: 220,
              child: Center(
                  child: Icon(Icons.image_not_supported, size: 80)),
            );
          } else if (_allImages.length == 1) {
            topImage = SizedBox(height: 220, child: _allImages.first);
          } else {
            topImage = SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _allImages.length,
                    itemBuilder: (_, i) => _allImages[i],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SmoothPageIndicator(
                      controller: _pageCtrl,
                      count: _allImages.length,
                      effect: const ExpandingDotsEffect(
                        dotHeight: 6,
                        dotWidth: 6,
                        activeDotColor: Colors.white,
                        dotColor: Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          /* ───────────────────────────────────────────────────────────── */

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: topImage),
                const SizedBox(height: 16),
                Text(name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(description, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Text('Reason: $reason',
                    style:
                    const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: goal == 0 ? 0 : progress / goal,
                  backgroundColor: Colors.grey.shade300,
                ),
                const SizedBox(height: 6),
                Text('RM ${progress.round()} / RM ${goal.round()}',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () =>
                        Get.to(() => DonateScreen(startupId: widget.startupId)),
                    child: const Text('Donate',
                        style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
