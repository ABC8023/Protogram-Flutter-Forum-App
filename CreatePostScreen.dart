import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;

class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<File> _selectedImages = [];
  String? _username;
  String? _profilePicBase64;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  /// **Load user profile from Firestore**
  void _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _username = userDoc['name'] ?? "Username";
          _profilePicBase64 = userDoc['profilePic'];
        });
      }
    }
  }

  /// **Pick images from gallery**
  Future<void> _pickImage() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles != null) {
      for (XFile pickedFile in pickedFiles) {
        if (_selectedImages.length >= 5) break;

        // Let user crop image
        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1), // 1:1 square
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: Colors.black,
              toolbarWidgetColor: Colors.white,
              lockAspectRatio: true,
            ),
            IOSUiSettings(title: 'Crop Image'),
          ],
        );

        if (croppedFile != null) {
          File cropped = File(croppedFile.path);

          // Resize to 1080x1080
          // ✅ Fix: Use Uint8List
          Uint8List imageBytes = await cropped.readAsBytes();
          img.Image? decodedImg = img.decodeImage(imageBytes);
          if (decodedImg != null) {
            img.Image resizedImg = img.copyResize(decodedImg, width: 720, height: 720);
            File resizedFile = File(cropped.path)
              ..writeAsBytesSync(img.encodeJpg(resizedImg, quality: 20));
            setState(() {
              _selectedImages.add(resizedFile);
            });
          }

        }
      }

      if (_selectedImages.length > 5) {
        _selectedImages = _selectedImages.sublist(0, 5);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You can only upload up to 5 images.")),
        );
      }
    }
  }

  /// **Remove Image from Selection**
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// **Validate Input and Show Confirmation Dialog**
  void _validateAndSubmitPost() {
    if (_topicController.text.isEmpty || _descriptionController.text.isEmpty) {
      Get.snackbar(
        "Error",
        "Idea Title and Description are required!",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      Get.snackbar(
        "Error",
        "At least one image is required!",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    _showConfirmationDialog();
  }

  /// **Show Custom Confirmation Dialog**
  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timelapse, size: 50, color: Colors.orange), // ✅ Time-lapse Icon
              SizedBox(height: 10),
              Text("Pending approval by Admin",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  _savePostToFirestore(); // ✅ Save post to Firestore
                  Get.offAllNamed('/feed');
                },
                child: Text(
                  "OK",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// **Save post data to Firestore**
  void _savePostToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar("Error", "User not authenticated!", backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    try {
      List<String> base64Images = [];

      // Convert selected images to Base64 strings
      if (_selectedImages.isNotEmpty) {
        for (File image in _selectedImages) {
          List<int> imageBytes = await image.readAsBytes();
          base64Images.add(base64Encode(imageBytes));
        }
      }

      // Generate a new document ID
      DocumentReference postRef = FirebaseFirestore.instance.collection("posts").doc();

      // Save post data with the generated ID
      await postRef.set({
        "postId": postRef.id,  // ✅ Store postId explicitly
        "userId": user.uid,
        "username": _username,
        "profilePic": _profilePicBase64,
        "topic": _topicController.text.trim(),
        "description": _descriptionController.text.trim(),
        "images": base64Images,  // Store images as Base64 strings
        "timestamp": FieldValue.serverTimestamp(),
        "status": "Pending"  // Admin approval status
      });

      print("✅ Post saved successfully to Firestore!");

    } catch (e) {
      print("❌ Error saving post: $e");
      Get.snackbar("Error", "Failed to save post", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Writing Post"),
        actions: [
          TextButton(
            onPressed: _validateAndSubmitPost,
            child: Text(
              "Post",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary, // ✅ Dynamic theme color
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display User Profile and Username
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: _profilePicBase64 != null
                        ? MemoryImage(base64Decode(_profilePicBase64!)) // ✅ Convert Base64 to Image
                        : AssetImage("assets/user_profile.png") as ImageProvider, // Default Image
                  ),
                  SizedBox(width: 10),
                  Text(
                    _username ?? "Username",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Divider(),

              // Topic Input Field
              TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  hintText: "Enter your idea title",
                  border: InputBorder.none,
                ),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),

              // Description Input Field
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  hintText: "Tell us more about your idea",
                  border: InputBorder.none,
                ),
                maxLines: 5,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),

              // Display Selected Images
              _selectedImages.isNotEmpty
                  ? Container(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 5),
                          width: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: FileImage(_selectedImages[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 5,
                          right: 5,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              )
                  : SizedBox.shrink(),

              SizedBox(height: 10),

              // Add Images Button
              TextButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.add_a_photo, color: Colors.teal),
                label: Text("Add Images (Maximum 5 images)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}