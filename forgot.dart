import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();
  String _emailValidationMessage = "";
  Color _emailValidationColor = Colors.black54; // Changed from white54 to black54

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  /// **Validates Email Format**
  void _validateEmail() {
    String email = emailController.text.trim();
    if (email.isEmpty || !GetUtils.isEmail(email)) {
      setState(() {
        _emailValidationMessage = "Invalid Email Format ❌";
        _emailValidationColor = Colors.red;
      });
    } else {
      setState(() {
        _emailValidationMessage = "Valid Email ✅";
        _emailValidationColor = Colors.green;
      });
    }
  }

  /// **Sends Password Reset Email**
  Future<void> resetPassword() async {
    if (_emailValidationMessage != "Valid Email ✅") return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      // **Show Success Message**
      Get.snackbar(
        "Reset Link Sent",
        "Check your email to reset your password",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.white.withAlpha(200), // Semi-transparent white
        colorText: Colors.black, // Changed text color
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      );

      // **Navigate Back to Login**
      Future.delayed(const Duration(seconds: 2), () {
        Get.offNamed('/login', arguments: {'transition': Transition.rightToLeft});
      });
    } catch (e) {
      Get.snackbar(
        "Reset Failed",
        e.toString(),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.white.withAlpha(200),
        colorText: Colors.black, // Changed text color
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Changed background to white
      appBar: AppBar(
        backgroundColor: Colors.white, // Changed app bar to white
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black), // Changed icon color to black
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
              'Forgot Password',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black, // Changed text color to black
              ),
            ),
            const SizedBox(height: 40),

            /// **Email Input Field**
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'yourname@example.com',
                hintStyle: const TextStyle(color: Colors.black54), // Changed hint color to black54
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.black, width: 1.5), // Changed border color to black
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              style: const TextStyle(color: Colors.black), // Changed text color to black
              onChanged: (_) => _validateEmail(),
            ),
            const SizedBox(height: 10),
            Text(_emailValidationMessage, style: TextStyle(color: _emailValidationColor, fontSize: 14)),
            const SizedBox(height: 20),
          ],
        ),
      ),

      /// **Reset Password Button**
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _emailValidationMessage == "Valid Email ✅" ? resetPassword : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black, // Changed button background to black
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            child: const Text(
              "SEND LINK",
              style: TextStyle(
                color: Colors.white, // Changed text color to white
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
