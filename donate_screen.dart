import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key, required this.startupId});

  final String startupId;

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final _formKey   = GlobalKey<FormState>();

  final _amountCtrl = TextEditingController();
  final _cardCtrl   = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl    = TextEditingController();

  // ── input masks ─────────────────────────────────────────────────────────────
  final _cardMask   = MaskTextInputFormatter(mask: '#### #### #### ####');
  final _expiryMask = MaskTextInputFormatter(mask: '##/##');

  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  // ── helper: add amount to donationProgress ─────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final amount = double.parse(_amountCtrl.text.trim());

    try {
      await FirebaseFirestore.instance
          .collection('startups')
          .doc(widget.startupId)
          .update({'donationProgress': FieldValue.increment(amount)});

      if (mounted) {
        Get.back(); // close DonateScreen
        Get.snackbar(
          'Thank you',
          'Your RM ${amount.toStringAsFixed(2)} donation was recorded',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', 'Payment failed: $e',
            snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /* ────────────────────────────────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donate'),
      ),

      // ── we listen to the single‑doc stream so UI updates if name changes ──
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('startups')
            .doc(widget.startupId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('Startup not found'));
          }

          final data        = snap.data!.data()!;
          final startupName = data['name'] ?? 'Unnamed Startup';

          return Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                // ── startup name header ────────────────────────────────────
                Text(
                  'Donate to $startupName',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 25),

                // ── payment form ───────────────────────────────────────────
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Amount
                      TextFormField(
                        controller: _amountCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Amount (RM)',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter an amount';
                          }
                          final n = double.tryParse(v.trim());
                          if (n == null || n <= 0) {
                            return 'Amount must be > 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Card number
                      TextFormField(
                        controller: _cardCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Card Number',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [_cardMask],
                        validator: (v) {
                          final digits = v?.replaceAll(' ', '');
                          if (digits == null || digits.length != 16) {
                            return 'Enter 16‑digit card';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Expiry + CVV
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiryCtrl,
                              decoration:
                              const InputDecoration(labelText: 'MM/YY'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [_expiryMask],
                              validator: (v) {
                                if (v == null || v.length != 5) {
                                  return 'Invalid';
                                }
                                final parts = v.split('/');
                                final mm = int.tryParse(parts[0]);
                                final yy = int.tryParse(parts[1]);
                                if (mm == null ||
                                    yy == null ||
                                    mm < 1 ||
                                    mm > 12) return 'Invalid';
                                final now = DateTime.now();
                                final fourDigitYear = 2000 + yy;
                                final exp =
                                DateTime(fourDigitYear, mm + 1); // 1st next month
                                if (exp.isBefore(now)) return 'Card expired';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _cvvCtrl,
                              decoration:
                              const InputDecoration(labelText: 'CVV'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              validator: (v) =>
                              (v != null &&
                                  (v.length == 3 || v.length == 4))
                                  ? null
                                  : 'CVV',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Pay button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14)),
                          child: _isSubmitting
                              ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                              : const Text('Confirm Payment',
                              style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ],
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
