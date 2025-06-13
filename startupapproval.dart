import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'admin_startup_approved.dart';
import 'admin_startup_pending.dart';
import 'admin_startup_rejected.dart';

/// Landing page that shows two big buttons (“Approved / Pending”)
class AdminStartupApproval extends StatefulWidget {
  const AdminStartupApproval({super.key});
  @override
  State<AdminStartupApproval> createState() => _AdminStartupApprovalState();
}

class _AdminStartupApprovalState extends State<AdminStartupApproval> {
  bool _hasPending = false;
  static const double _half = 190;          // <-  use const so the analyzer won’t warn

  @override
  void initState() {
    super.initState();
    _checkPending(); // run once at start‑up
  }

  Future<void> _checkPending() async {
    final qs = await FirebaseFirestore.instance
        .collection('startups')
        .where('status', isEqualTo: 'Pending')
        .limit(1)
        .get();
    setState(() => _hasPending = qs.docs.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startup Approval'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Manage startups',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            /// 2️⃣  keep the whole row centred and tidy
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ─────────────── LEFT column (two half‑buttons) ────────────
                Column(
                  children: [
                    _bigButton(
                      label: 'View Approved\nStartups',
                      color: Colors.green,
                      icon: Icons.check_circle,
                      height: _half,
                      onTap: () => Get.to(() => const AdminStartupApproved()),
                    ),

                    const SizedBox(height: 20),

                    _bigButton(
                      label: 'View Rejected\nStartups',
                      color: Colors.red,
                      icon: Icons.cancel,
                      height: _half,
                      onTap: () => Get.to(() => const AdminStartupRejected()),
                    ),
                  ],
                ),

                const SizedBox(width: 20),               // space between columns

                // ─────────────── RIGHT column (one full‑height) ────────────
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    _bigButton(
                      label: 'View Pending\nStartups',
                      color: Colors.orange,
                      icon: Icons.hourglass_empty,
                      onTap: () => Get.to(() => const AdminStartupPending()),
                    ),
                    if (_hasPending)
                      const Positioned(
                        top: 8, right: 8,                 // nudge badge a little
                        child: Icon(Icons.notifications_active,
                            color: Colors.red, size: 28),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // 1️⃣  add an optional `height` parameter (default 400)  ──────────────
  Widget _bigButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    double height = 400,            //  ← NEW (defaults to “full‑height”)
  }) =>
      SizedBox(
        width: 150,
        height: height,             //  ← use that height here
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );

}
