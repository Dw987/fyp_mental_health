import 'package:flutter/material.dart';
import 'package:flutter_fyp/userAuth_pages/login.dart';
import 'package:flutter_fyp/userAuth_pages/auth.dart';
import 'package:flutter_fyp/layout_pages/nav_menu.dart';
import 'package:flutter_fyp/userAuth_pages/userSetup.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  String firstName = '';
  String lastName = '';
  String email = '';
  String imageUrl = '';
  String gender = '';
  String dob = '';
  bool isLoading = true; // To track loading state

  Future<void> _loadUserData() async {
    // Fetch the user data from Auth
    Map<String, String>? data = await Auth().getUserData();
    if (data != null) {
      setState(() {
        firstName = data['firstName'] ?? '';
        lastName = data['lastName'] ?? '';
        email = data['email'] ?? '';
        imageUrl = data['imageUrl'] ?? '';
        gender = data['gender'] ?? '';
        dob = data['dob'] ?? '';
        isLoading = false; // Set loading to false after data is fetched
      });
    } else {
      setState(() {
        isLoading = false; // Handle case where data is not available
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Auth().authStateChanges,
      builder: (context, snapshot) {
        // Show loading indicator while checking authentication status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white, // Set the background color to white
            body: Center(
              child: SizedBox(
                width: 50,
                height: 50,
                child:
                    CircularProgressIndicator(), // Smaller loading indicator at the center
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          // If user is logged in and data is not loaded yet, fetch user data
          if (isLoading) {
            _loadUserData(); // Fetch user data only if not already loaded
            return const Scaffold(
              backgroundColor:
                  Colors.white, // Set the background color to white
              body: Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child:
                      CircularProgressIndicator(), // Smaller loading indicator at the center
                ),
              ),
            );
          }

          // Check if gender or dob is missing
          if (gender.isEmpty || dob.isEmpty) {
            return UserSetupPage(); // Navigate to user setup if either gender or dob is missing
          }

          // Proceed to the main navigation if data is valid
          return NavMenu();
        } else {
          // If no user is logged in, show LoginPage
          return const LoginPage();
        }
      },
    );
  }
}
