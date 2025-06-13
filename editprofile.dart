import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:typed_data';

class EditProfile  extends StatefulWidget {
  const EditProfile ({super.key});

  @override
  State<EditProfile > createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile > {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String _selectedCountry = "Select Country";
  File? _imageFile;
  String? _imageUrl;
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load existing user profile from Firestore
  void _loadUserData() async {
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (userDoc.exists) {
        setState(() {
          _nameController.text = userDoc['name'] ?? "";
          _dobController.text = userDoc['dob'] ?? "";
          _selectedCountry = userDoc['country'] ?? "Select Country";
          _imageUrl = userDoc['profilePic'] ?? null;
        });
      }
    }
  }

  // Pick an image from the gallery or camera and convert it to Base64
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64String = base64Encode(imageBytes);

      setState(() {
        _imageFile = imageFile;
        _imageUrl = base64String; // ✅ Store Base64 string instead of file path
      });
    }
  }

  // Show image selection dialog
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        );
      },
    );
  }

  // Upload profile picture to Firebase Storage
  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl; // Keep existing URL if no new image is picked
    try {
      debugPrint("🚀 Uploading image to Firebase Storage...");
      final storageRef = FirebaseStorage.instance.ref().child('profile_pics/${user!.uid}.jpg');

      // Upload file
      await storageRef.putFile(_imageFile!);

      // Get image URL
      String downloadUrl = await storageRef.getDownloadURL();
      debugPrint("✅ Image uploaded successfully: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("❌ Error uploading image: $e");
      return _imageUrl; // Return old URL if upload fails
    }
  }

  // Save profile to Firebase Firestore using Base64
  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      if (user == null) {
        debugPrint("❌ Error: User is null!");
        Get.snackbar("Error", "User not authenticated!");
        return;
      }

      debugPrint("🚀 Starting profile save process...");

      // If user entered a new password
      if (_newPasswordController.text.isNotEmpty) {
        try {
          await user!.updatePassword(_newPasswordController.text);
          debugPrint("✅ Password updated successfully");
        } catch (e) {
          debugPrint("❌ Failed to update password: $e");
          Get.snackbar("Error", "Failed to update password: $e");
          return; // Stop saving if password update failed
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': _nameController.text,
        'dob': _dobController.text,
        'country': _selectedCountry,
        'profilePic': _imageUrl ?? "",
        'email': user!.email,
      }, SetOptions(merge: true));

      debugPrint("✅ Profile successfully saved!");

      Get.snackbar("Success", "Profile updated successfully!");
      Get.offAllNamed('/feed'); // ✅ Navigate back to FeedScreen
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _newPasswordController.dispose(); // ✅ Dispose new password controller
    super.dispose();
  }

  // Show Date Picker for DOB
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.offAllNamed('/feed'),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture with Edit Icon
              Stack(
                children: [
                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.black,
                      child: CircleAvatar(
                        radius: 52,
                        backgroundImage: _imageUrl != null && _imageUrl!.isNotEmpty
                            ? MemoryImage(base64Decode(_imageUrl!)) // ✅ Decode Base64 to Image
                            : const AssetImage("assets/user_profile.png") as ImageProvider?,
                        child: _imageUrl == null || _imageUrl!.isEmpty
                            ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? "Enter your name" : null,
              ),
              const SizedBox(height: 10),

              // Email Field (Read-Only)
              TextFormField(
                initialValue: user?.email ?? "",
                decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                readOnly: true,
              ),
              const SizedBox(height: 10),

              // New Password Field
              TextFormField(
                controller: _newPasswordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "New Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Date of Birth Picker
              TextFormField(
                controller: _dobController,
                decoration: InputDecoration(
                  labelText: "Date of Birth",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _selectDate,
                  ),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 10),

              // Country Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Country/Region"),
                items: ["Select Country", "USA", "UK", "Malaysia", "Nigeria", "India", "Other"]
                    .map((country) => DropdownMenuItem(value: country, child: Text(country)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedCountry = value!),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
    );
  }
}