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
import 'package:mobile_app_asm/startup_screen.dart';
import 'package:flutter/services.dart';

class CreateStartupScreen extends StatefulWidget {
  @override
  _CreateStartupScreenState createState() => _CreateStartupScreenState();
}

class _CreateStartupScreenState extends State<CreateStartupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();

  List<File> _selectedImages = [];
  String? _username;
  String? _profilePicBase64;


  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

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

  Future<void> _pickImage() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles != null) {
      for (XFile pickedFile in pickedFiles) {
        if (_selectedImages.length >= 5) break;

        CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
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
          Uint8List imageBytes = await cropped.readAsBytes();
          img.Image? decodedImg = img.decodeImage(imageBytes);
          if (decodedImg != null) {
            img.Image resizedImg = img.copyResize(decodedImg, width: 720, height: 720);
            File resizedFile = File(cropped.path)..writeAsBytesSync(img.encodeJpg(resizedImg, quality: 75));
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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _validateAndSubmitStartup() {
    if (_nameController.text.isEmpty || _descriptionController.text.isEmpty || _reasonController.text.isEmpty || _goalController.text.isEmpty) {
      Get.snackbar("Error", "All fields are required!", backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (_selectedImages.isEmpty) {
      Get.snackbar("Error", "At least one image is required!", backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    _showConfirmationDialog();
  }

  void _showConfirmationDialog() {
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
              Text("Pending approval by Admin", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  _saveStartupToFirestore();
                  Get.off(() => StartupsScreen());
                },
                child: Text("OK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _saveStartupToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.snackbar("Error", "User not authenticated!", backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    try {
      List<String> base64Images = [];

      for (File image in _selectedImages) {
        List<int> imageBytes = await image.readAsBytes();
        base64Images.add(base64Encode(imageBytes));
      }

      DocumentReference startupRef = FirebaseFirestore.instance.collection("startups").doc();

      await startupRef.set({
        "startupId": startupRef.id,
        "userId": user.uid,
        "username": _username,
        "profilePic": _profilePicBase64,
        "name": _nameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "reason": _reasonController.text.trim(),
        "donationGoal": double.tryParse(_goalController.text.trim()) ?? 0.0,
        "donationProgress": 0.0,
        "likes": 0,
        "dislikes": 0,
        "images": base64Images,
        "timestamp": FieldValue.serverTimestamp(),
        "status": "Pending"
      });

    } catch (e) {
      print("Error: $e");
      Get.snackbar("Error", "Failed to save startup", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text("Create Startup"),
        actions: [
          TextButton(
            onPressed: _validateAndSubmitStartup,
            child: Text("Submit", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
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
                    backgroundImage: _profilePicBase64 != null
                        ? MemoryImage(base64Decode(_profilePicBase64!))
                        : AssetImage("assets/user_profile.png") as ImageProvider,
                  ),
                  SizedBox(width: 10),
                  Text(_username ?? "Username", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Divider(),
              Padding(
                padding: const EdgeInsets.all(4.0), // Add padding around the whole form
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // Align items to the start
                  children: <Widget>[
                    // Consider if this Divider is truly needed, or if spacing is enough
                    // Divider(),
                    // SizedBox(height: 8.0), // Optional space after divider

                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Startup Name", // Use labelText instead of hintText
                        // Use a subtle border, OutlineInputBorder is common
                        border: OutlineInputBorder(),
                        // Or use UnderlineInputBorder for a less boxy look:
                        // border: UnderlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0), // Adjust padding inside the field
                      ),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    SizedBox(height: 16.0), // Add space between fields

                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: "Describe your startup",
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true, // Good for multi-line fields
                        contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: 16.0), // Add space between fields

                    TextField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        labelText: "Why is your startup important?",
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true, // Good for multi-line fields
                        contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: 16.0), // Add space between fields

                    TextField(
                      controller: _goalController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: "Donation Goal",
                        hintText: "e.g. 10000.00",
                        border: OutlineInputBorder(),
                        prefixText: "\RM ",
                        prefixStyle: TextStyle(fontSize: 16),
                        contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                      ),
                    ),
                    SizedBox(height: 16.0), // Add space at the bottom
                  ],
                ),
              ),
              SizedBox(height: 10),
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
              TextButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.add_a_photo, color: Colors.teal),
                label: Text("Add Images (Max 5)"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}