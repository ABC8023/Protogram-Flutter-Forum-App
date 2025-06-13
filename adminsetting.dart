import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminSetting extends StatefulWidget {
  const AdminSetting({super.key});

  @override
  State<AdminSetting> createState() => _AdminSettingState();
}

class _AdminSettingState extends State<AdminSetting> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newEmailController = TextEditingController();

  bool _loading = false;
  bool showChangePassword = false;
  bool showChangeEmail = false;

  Future<void> _reauthenticate(String password) async {
    final user = _auth.currentUser;
    final cred = EmailAuthProvider.credential(
      email: user!.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);
  }

  Future<void> _changePassword() async {
    setState(() => _loading = true);
    try {
      await _reauthenticate(oldPasswordController.text);
      await _auth.currentUser!.updatePassword(newPasswordController.text);
      Get.snackbar("Success", "Password updated successfully",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.black,
          colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", e.toString(),
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _changeEmail() async {
    setState(() => _loading = true);
    try {
      await _reauthenticate(currentPasswordController.text);
      await _auth.currentUser!.updateEmail(newEmailController.text);
      await _firestore.collection('admin').doc(_auth.currentUser!.uid).update({
        'email': newEmailController.text,
      });
      Get.snackbar("Success", "Email updated successfully",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.black,
          colorText: Colors.white);
    } catch (e) {
      Get.snackbar("Error", e.toString(),
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red);
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildExpandableSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget content,
    Color? titleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: onToggle,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor ?? Colors.black,
                  ),
                ),
              ),
              Icon(expanded ? Icons.expand_less : Icons.expand_more)
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: content,
          secondChild: const SizedBox.shrink(),
        ),
        const Divider(height: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Settings"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildExpandableSection(
              title: "CHANGE PASSWORD",
              titleColor: Colors.white,
              expanded: showChangePassword,
              onToggle: () => setState(() => showChangePassword = !showChangePassword),
              content: Column(
                children: [
                  TextField(
                    controller: oldPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Old Password"),
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "New Password"),
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Update Password",
                      style: TextStyle(fontSize: 22), // <-- Increase font size here
                    ),
                  ),
                ],
              ),
            ),
            _buildExpandableSection(
              title: "CHANGE EMAIL",
              titleColor: Colors.white,
              expanded: showChangeEmail,
              onToggle: () => setState(() => showChangeEmail = !showChangeEmail),
              content: Column(
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Current Password"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newEmailController,
                    decoration: const InputDecoration(labelText: "New Email"),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _changeEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Update Email",
                      style: TextStyle(fontSize: 22), // <-- Increase font size here
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
