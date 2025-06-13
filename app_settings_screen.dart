import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'theme_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'theme_controller.dart';

class AppSettingsScreen extends StatefulWidget {
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final themeController = Get.find<ThemeController>();
  int? _selectedScore;
  TextEditingController _feedbackController = TextEditingController();

  void _showFeedbackPopup() {
    showDialog(
      context: context,
      builder: (context) {
        int localScore = _selectedScore ?? 0; // Temp value for dialog
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "How likely are you to recommend us to a friend or coworker?",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Slider(
                        value: localScore.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: '$localScore',
                        onChanged: (value) {
                          setDialogState(() => localScore = value.round());
                          setState(() => _selectedScore = value.round()); // 🔄 update outer too
                        },
                      ),
                      Text("Your score: $localScore"),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text("Can you share any specific feedback about your score?"),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _feedbackController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Leave your feedback here",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text("SUBMIT"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submitFeedback() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _selectedScore != null) {
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user.uid,
        'score': _selectedScore,
        'feedback': _feedbackController.text,
        'timestamp': Timestamp.now(),
      });
    }

    Navigator.pop(context); // Close the dialog

    // ✅ Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Feedback submitted!"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("App Information"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Version: 1.0.0"),
            SizedBox(height: 10),
            Text("About Protogram: A community engagement platform."),
            SizedBox(height: 10),
            Text("Terms & Privacy Policy: Available on our website."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Close"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Apps Settings"),
      ),
      body: ListView(
        children: [
          _sectionTitle("Common"),
          ListTile(
            leading: Icon(Icons.format_paint),
            title: Text("Theme"),
            subtitle: Text(_getThemeLabel(themeController.themeMode)),
            onTap: () => themeController.toggleTheme(themeController.themeMode != ThemeMode.dark),
          ),
          ListTile(
            leading: Icon(Icons.feedback),
            title: Text("Feedback & Support"),
            onTap: _showFeedbackPopup,
          ),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("App Information"),
            onTap: _showAppInfo,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return "Dark";
      case ThemeMode.light:
        return "Light";
      case ThemeMode.system:
      default:
        return "System";
    }
  }
}