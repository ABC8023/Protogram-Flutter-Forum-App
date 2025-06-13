import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'theme_controller.dart';

class ThemeSelectionScreen extends StatelessWidget {
  final themeController = Get.find<ThemeController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Theme")),
      body: Column(
        children: [
          ListTile(
            title: const Text("Light"),
            onTap: () => themeController.toggleTheme(false),
          ),
          ListTile(
            title: const Text("Dark"),
            onTap: () => themeController.toggleTheme(true),
          ),
        ],
      ),
    );
  }
}