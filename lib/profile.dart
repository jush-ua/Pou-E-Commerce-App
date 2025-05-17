import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart'; // Import the LoginModal and showLoginModal function
import 'request_seller.dart'; // Import your RequestSellerPage here
import 'seller_dashboard.dart'; // Import your SellerDashboard here
import 'edit_profile.dart'; // Import the EditProfilePage here

class ProfilePage extends StatelessWidget {
  final String username;

  const ProfilePage({super.key, required this.username});

  Future<bool> _checkIfSeller() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users') // Assuming you have a 'users' collection
              .doc(user.uid)
              .get();

      // Check if the user's role is 'seller'
      return userDoc.exists && userDoc.data()?['role'] == 'seller';
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = username == 'Guest';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: const Color(0xFFE47F43), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile section with orange background
            Container(
              color: const Color(0xFFE47F43),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Profile icon
                      FutureBuilder<DocumentSnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }

                          final userData =
                              snapshot.data?.data() as Map<String, dynamic>?;
                          final profileImageUrl =
                              userData?['profile_image_url'] ??
                              'https://yvyknbymnqpwpxzkabnc.supabase.co/storage/v1/object/public/profile-pictures//image_2025-05-16_221317901.png';

                          return CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(profileImageUrl),
                            backgroundColor: Colors.white.withOpacity(0.3),
                          );
                        },
                      ),
                      const SizedBox(width: 15),
                      // Username or Guest Text
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGuest ? "Guest User" : username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isGuest ? "Please login to continue" : "Welcome!",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Login/Register or Logout button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFE47F43),
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      if (isGuest) {
                        // Show the login modal instead of navigating to a new page
                        showLoginModal(context);
                      } else {
                        // Show confirmation dialog before logging out
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 5,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header with icon
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFE47F43),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.logout_rounded,
                                        size: 30,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    // Title
                                    const Text(
                                      "Log Out",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Content
                                    const Text(
                                      "Are you sure you want to log out of your account?",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 24),
                                    // Action buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              side: BorderSide(
                                                color: Colors.grey.shade300,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text("Cancel"),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFE47F43,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text("Log Out"),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );

                        if (shouldLogout == true) {
                          // Sign out the user and navigate to the main screen
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushReplacementNamed(context, '/');
                        }
                      }
                    },
                    // Show login/register or logout dialog
                    child: Text(
                      isGuest ? "Login / Register" : "Logout",
                      style: const TextStyle(
                        color: Color(0xFFE47F43),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Edit Profile Button
                  if (!isGuest)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFE47F43),
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Edit Profile",
                        style: TextStyle(
                          color: Color(0xFFE47F43),
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Actions section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isGuest) // Show the button only for logged-in users
                    FutureBuilder<bool>(
                      future: _checkIfSeller(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }

                        final isSeller = snapshot.data ?? false;

                        return ElevatedButton(
                          onPressed: () {
                            if (isSeller) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SellerDashboard(),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const RequestSellerPage(),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE47F43),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            isSeller
                                ? 'Go to Seller Dashboard'
                                : 'Request to Become a Seller',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
