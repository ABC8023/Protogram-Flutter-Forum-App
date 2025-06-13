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

import 'forum_screen.dart'; // Renamed to avoid conflict

class CreateForumPostScreen extends StatefulWidget {
  @override
  _CreateForumPostScreenState createState() => _CreateForumPostScreenState();
}

class _CreateForumPostScreenState extends State<CreateForumPostScreen> {
  // --- Configuration ---
  static const int _maxImages = 10; // Increased image limit
  static const int _maxTextLength = 3000; // Increased text limit
  // --- End Configuration ---

  final TextEditingController _contentController = TextEditingController();
  List<File> _selectedImages = [];
  String? _username;
  String? _profilePicBase64;
  // isLoading state is implicitly handled by the dialog in this version

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            // Check your Firestore field name: 'name' or 'username'?
            _username = userDoc['name'] ?? user.displayName ?? "Username"; // Adjusted to use 'username' (more common)
            _profilePicBase64 = userDoc['profilePic'];
          });
        } else if (mounted) {
          setState(() {
            _username = user.displayName ?? "Username";
            _profilePicBase64 = null;
          });
        }
      } catch (e) {
        print("Error loading user profile: $e");
        if (mounted) {
          setState(() {
            _username = user.displayName ?? "Username";
            _profilePicBase64 = null;
          });
        }
      }
    }
  }

  Future<void> _pickImage() async {
    // Check against the new limit
    if (_selectedImages.length >= _maxImages) {
      Get.snackbar("Limit Reached", "You can only upload up to $_maxImages images.",
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final pickedFiles = await ImagePicker().pickMultiImage();

    if (pickedFiles != null && mounted) {
      // Use the new limit for calculation
      int availableSlots = _maxImages - _selectedImages.length;
      int filesToAdd = pickedFiles.length > availableSlots ? availableSlots : pickedFiles.length;

      if (pickedFiles.length > availableSlots) {
        Get.snackbar("Limit Reached", "Added $availableSlots images. Maximum $_maxImages reached.",
            snackPosition: SnackPosition.BOTTOM);
      }

      // Show processing indicator if adding many images
      if (filesToAdd > 0) {
        Get.dialog(
            Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            )),
            barrierDismissible: false,
            barrierColor: Colors.black.withOpacity(0.5) // Make barrier slightly transparent
        );
      }

      List<File> processedImages = []; // Collect processed images before setState

      try {
        for (int i = 0; i < filesToAdd; i++) {
          XFile pickedFile = pickedFiles[i];
          CroppedFile? croppedFile = await ImageCropper().cropImage(
            sourcePath: pickedFile.path,
            // Keep aspect ratio for consistency or remove aspect ratio lock if desired
            aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1),
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
            try {
              Uint8List imageBytes = await cropped.readAsBytes();
              img.Image? decodedImg = img.decodeImage(imageBytes);
              if (decodedImg != null) {
                img.Image resizedImg = img.copyResize(decodedImg, width: 720, height: 720, interpolation: img.Interpolation.average);
                // Overwrite the cropped file with resized data
                File resizedFile = cropped..writeAsBytesSync(img.encodeJpg(resizedImg, quality: 75));
                processedImages.add(resizedFile);
              }
            } catch (e) {
              print("Error processing image: $e");
              // Show error for specific image but continue loop
              if(mounted) {
                Get.snackbar("Image Error", "Error processing one image: ${e.toString()}",
                    backgroundColor: Colors.red, colorText: Colors.white);
              }
            }
          }
        }
      } finally {
        // Always close the processing dialog
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        // Update state with all processed images at once
        if (mounted && processedImages.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(processedImages);
          });
        }
      }
    }
  }


  void _removeImage(int index) {
    if (mounted) {
      setState(() {
        _selectedImages.removeAt(index);
      });
    }
  }

  void _validateAndSubmitPost() {
    if (_contentController.text.trim().isEmpty) {
      Get.snackbar(
        "Error", "Forum content is required!",
        backgroundColor: Colors.red, colorText: Colors.white,
      );
      return;
    }

    _showConfirmationDialog();
  }

  void _showConfirmationDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timelapse, size: 50, color: Colors.orange),
              SizedBox(height: 10),
              Text("Pending approval by Admin", // Or "Post Submitted"
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Close dialog
                  await _saveForumPostToFirestore(); // Save post
                  if (mounted) {
                    // Navigate back to ForumScreen after successful save
                    Get.off(() => ForumScreen());
                  }
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

  Future<void> _saveForumPostToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar("Error", "User not authenticated!", backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // Show loading indicator
    Get.dialog(Center(child: CircularProgressIndicator()), barrierDismissible: false);

    // ***************************** WARNING *****************************
    // Storing many images (e.g., 20) as Base64 strings directly in a
    // Firestore document can easily exceed the 1 MiB document size limit.
    // This can lead to errors when saving.
    //
    // The RECOMMENDED approach for multiple/large images is to:
    // 1. Upload each image file to Firebase Storage.
    // 2. Get the download URL for each uploaded image.
    // 3. Store the LIST of download URLs (Strings) in the Firestore document,
    //    instead of the Base64 data.
    //
    // This example proceeds with Base64 as per the current structure,
    // but be aware of this limitation.
    // *******************************************************************

    try {
      List<String> base64Images = [];
      if (_selectedImages.isNotEmpty) {
        // This loop can be time-consuming for many images
        for (File image in _selectedImages) {
          List<int> imageBytes = await image.readAsBytes();
          base64Images.add(base64Encode(imageBytes));
          // Yield to prevent UI freeze (optional, might slightly slow down)
          // await Future.delayed(Duration.zero);
        }
      }

      DocumentReference postRef = FirebaseFirestore.instance.collection("forumPosts").doc();

      await postRef.set({
        "postId": postRef.id,
        "userId": user.uid,
        "username": _username ?? "User",
        "profilePic": _profilePicBase64,
        "content": _contentController.text.trim(),
        "images": base64Images, // List of Base64 strings
        "timestamp": FieldValue.serverTimestamp(),
        "status": "Pending", // Or "Approved"
        'likeCount': 0,
        'commentCount': 0,
        'likedBy': [],
      });

      print("✅ Forum Post saved successfully to Firestore!");

      if (Get.isDialogOpen ?? false) Get.back(); // Close loading indicator

      Get.snackbar("Success", "Post submitted!", snackPosition: SnackPosition.BOTTOM);

    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back(); // Close loading indicator

      print("❌ Error saving forum post: $e");
      // Check for common errors like document size limit
      String errorMessage = e.toString();
      if (errorMessage.toLowerCase().contains('maximum size')) {
        errorMessage = "Failed to save post: Too much image data. Please reduce the number of images or their size.";
      } else {
        errorMessage = "Failed to save post: $errorMessage";
      }
      Get.snackbar("Error", errorMessage, backgroundColor: Colors.red, colorText: Colors.white, duration: Duration(seconds: 5));
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        title: Text("Create Forum Post"),
        actions: [
          TextButton(
            onPressed: _validateAndSubmitPost,
            child: Text(
              "Post",
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16 // Slightly larger text
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
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profilePicBase64 != null && _profilePicBase64!.isNotEmpty
                        ? MemoryImage(base64Decode(_profilePicBase64!)) as ImageProvider
                        : AssetImage("assets/placeholder_user.png"), // Ensure this exists
                  ),
                  SizedBox(width: 10),
                  Text(
                    _username ?? "Loading...",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Divider(height: 20, thickness: 1),

              // --- Updated TextField ---
              TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  hintText: "Share your thoughts, questions, or updates...", // More descriptive hint
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  counterText: "", // Hide the default counter if maxLength is set
                ),
                maxLines: null, // Still expands automatically
                minLines: 10, // Increased minimum lines for more initial height
                keyboardType: TextInputType.multiline,
                style: TextStyle(fontSize: 16),
                maxLength: _maxTextLength, // Use the defined max length
              ),
              // --- End Updated TextField ---
              SizedBox(height: 10),

              // Display Selected Images (Horizontal ListView)
              // Consider a GridView or Wrap for better display of many images if needed
              if (_selectedImages.isNotEmpty)
                Container(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.file(
                                _selectedImages[index],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                margin: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, color: Colors.white, size: 18),
                                padding: EdgeInsets.all(2),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              SizedBox(height: 15),

              // Add Images Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.teal),
                ),
                onPressed: _pickImage,
                icon: Icon(Icons.add_photo_alternate_outlined, color: Colors.teal),
                // Update button label with the new max limit
                label: Text("Add Images (Max $_maxImages)", style: TextStyle(color: Colors.teal)),
              ),
              SizedBox(height: 20), // More space at the bottom
            ],
          ),
        ),
      ),
    );
  }
}