import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Import the actual screen widgets you want to show
import 'feed_screen.dart'; // Make sure this is your main screen for logged-in users
import 'login.dart';    // Your login screen

// Wrapper can usually be StatelessWidget when using StreamBuilder like this
class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // Listen to auth changes
      builder: (context, snapshot) {
        // 1. While checking the auth state, show a loading indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Return a Scaffold during loading to avoid layout jumps
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If there's an error with the stream (optional but good practice)
        if (snapshot.hasError) {
          print("Error in auth stream: ${snapshot.error}");
          // Decide what to show on error, often the Login screen is safest
          return const Login();
          // Or return a dedicated error screen:
          // return Scaffold(body: Center(child: Text("Authentication error")));
        }

        // 3. Check if the snapshot has data (i.e., user is logged in)
        if (snapshot.hasData) {
          // User is logged in: RETURN the main authenticated screen widget
          // Ensure FeedScreen is the correct entry point for logged-in users
          // and contains your BottomAppBar or navigates to it.
          return FeedScreen();
        } else {
          // User is logged out: RETURN the Login screen widget
          return const Login();
        }
      },
    );
  }
}