import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_app_asm/editprofile.dart';
import 'package:mobile_app_asm/post_status_screen.dart';
import 'package:mobile_app_asm/saved_posts_screen.dart';
import 'package:mobile_app_asm/reported_posts_screen.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Settings"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text("Edit Profile"),
            onTap: () => Get.to(() => const EditProfile()),
          ),
          ListTile(
            leading: const Icon(Icons.timeline),
            title: const Text("Post Status"),
            onTap: () => Get.to(() => PostStatusScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark),
            title: const Text("Saved Post"),
            onTap: () => Get.to(() => SavedPostsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text("Reported Post"),
            onTap: () => Get.to(() => ReportedPostsScreen()),
          ),

        ],
      ),
    );
  }
}