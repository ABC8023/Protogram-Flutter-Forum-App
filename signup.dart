import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<Signup> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController retypePasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureRetypePassword = true;
  bool _passwordsMatch = false;
  String _emailValidationMessage = "";
  String _passwordValidationMessage = "";
  Color _emailValidationColor = Colors.white54;
  Color _passwordValidationColor = Colors.white54;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    retypePasswordController.dispose();
    super.dispose();
  }

  /// **Auto Validates Email Format & Checks Firebase**
  Future<void> _validateEmail() async {
    String email = emailController.text.trim();

    if (!GetUtils.isEmail(email)) {
      setState(() {
        _emailValidationMessage = "Invalid Email Format ❌";
        _emailValidationColor = Colors.red;
      });
      return;
    }

    try {
      List<String> signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (signInMethods.isNotEmpty) {
        setState(() {
          _emailValidationMessage = "Email Already Registered ❌";
          _emailValidationColor = Colors.red;
        });
      } else {
        setState(() {
          _emailValidationMessage = "Email Valid ✅";
          _emailValidationColor = Colors.green;
        });
      }
    } catch (e) {
      setState(() {
        _emailValidationMessage = "Error checking email ❌";
        _emailValidationColor = Colors.red;
      });
    }
  }

  /// **Auto Validates Password Match**
  void _validatePasswordMatch() {
    if (passwordController.text.isNotEmpty && retypePasswordController.text.isNotEmpty) {
      if (passwordController.text == retypePasswordController.text) {
        setState(() {
          _passwordValidationMessage = "Passwords Match ✅";
          _passwordValidationColor = Colors.green;
          _passwordsMatch = true;
        });
      } else {
        setState(() {
          _passwordValidationMessage = "Passwords Do Not Match ❌";
          _passwordValidationColor = Colors.red;
          _passwordsMatch = false;
        });
      }
    } else {
      setState(() {
        _passwordValidationMessage = "";
        _passwordsMatch = false;
      });
    }
  }

  Future<void> signup() async {
    if (!_passwordsMatch) return;

    try {
      // Create user with email & password
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Get the UID of the registered user
      String uid = userCredential.user!.uid;

      // Save additional user data in Firestore under 'users' collection
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'user', // You can use this later for role checking
        'isOnline': false,
      });

      // Show success message
      Get.snackbar(
        "Registration Successful!",
        "Log in your account",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.black.withAlpha(153),
        colorText: Colors.white,
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      );

      // Navigate to login page
      Future.delayed(const Duration(seconds: 2), () {
        Get.offNamed('/login', arguments: {'transition': Transition.rightToLeft});
      });

    } catch (e) {
      Get.snackbar(
        "Signup Failed",
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.black.withAlpha(153),
        colorText: Colors.white,
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Register',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),

            /// **Email Input Field**
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'yourname@example.com',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => _validateEmail(),
            ),
            const SizedBox(height: 15), // Increased spacing

            Text(_emailValidationMessage, style: TextStyle(color: _emailValidationColor, fontSize: 14)),
            const SizedBox(height: 15), // Increased spacing

            /// **Password Input Field**
            TextField(
              controller: passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Enter your password',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 15), // Increased spacing

            /// **Retype Password Input Field**
            TextField(
              controller: retypePasswordController,
              obscureText: _obscureRetypePassword,
              decoration: InputDecoration(
                hintText: 'Retype your password',
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => _validatePasswordMatch(),
            ),
            const SizedBox(height: 15), // Increased spacing

            Text(_passwordValidationMessage, style: TextStyle(color: _passwordValidationColor)),
          ],
        ),
      ),


      /// **Sign Up Button (Styled Like Login Button)**
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _passwordsMatch ? signup : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, // White background like Login button
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: const Text(
              "SIGN UP",
              style: TextStyle(
                color: Colors.black, // Black text to match login button style
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}