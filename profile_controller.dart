import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class ProfileController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  RxString profilePicBase64 = "".obs;

  /// Pick an image, convert to Base64, and store in Firestore
  Future<void> pickAndSaveProfilePicture() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      File imageFile = File(pickedFile.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);

      await _firestore.collection('users').doc(user.uid).update({
        'profilePic': base64String,  // ✅ Store Base64 string in Firestore
      });

      profilePicBase64.value = base64String; // ✅ Update state
      print("✅ Profile picture saved as Base64 string in Firestore.");
    } catch (e) {
      print("❌ Error saving profile picture: $e");
    }
  }

  /// Load the Base64 image string from Firestore
  Future<void> loadUserProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc['profilePic'] != null && userDoc['profilePic'] != "") {
        profilePicBase64.value = userDoc['profilePic'];
        print("✅ Loaded Profile Picture from Firestore.");
      } else {
        print("⚠️ No profile picture found.");
      }
    }
  }

  /// Decode Base64 string into Image widget
  ImageProvider? getProfileImage() {
    if (profilePicBase64.value.isNotEmpty) {
      Uint8List imageBytes = base64Decode(profilePicBase64.value);
      return MemoryImage(imageBytes);  // ✅ Convert Base64 to Image
    }
    return const AssetImage("assets/default_profile.png"); // ✅ Default image
  }
}