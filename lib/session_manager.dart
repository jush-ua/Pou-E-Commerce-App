import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // Import MainScreen
import 'profile.dart'; // Import ProfilePage

class SessionManager extends StatelessWidget {
  final Widget Function(String username) onSessionValid; // Add onSessionValid
  final Widget Function() onSessionInvalid;

  const SessionManager({
    super.key,
    required this.onSessionValid, // Add onSessionValid to constructor
    required this.onSessionInvalid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading indicator while waiting for the auth state
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          // User is logged in, navigate to ProfilePage
          final user = snapshot.data!;
          return FutureBuilder(
            future:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (userSnapshot.hasData) {
                final userData = userSnapshot.data?.data();
                final username = userData?['username'] ?? 'Guest';
                return MainScreen(
                  isLimited: false,
                  initialPageIndex:
                      0, // Index of the ProfilePage in the bottom navigation
                  username: username,
                );
              } else {
                return const Center(child: Text('Error loading user data.'));
              }
            },
          );
        } else {
          // User is logged out, navigate to MainScreen with limited features
          return const MainScreen(isLimited: true);
        }
      },
    );
  }
}
