import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart'; // Import the LoginModal and showLoginModal function
import 'request_seller.dart'; // Import your RequestSellerPage here
import 'seller_dashboard.dart'; // Import your SellerDashboard here
import 'edit_profile.dart'; // Import the EditProfilePage here
import 'wishlist_page.dart'; // Import your WishlistPage here
import 'purchase_history_page.dart'; // <-- Add this import
import 'addresses_page.dart';

class ProfilePage extends StatelessWidget {
  final String username;

  const ProfilePage({super.key, required this.username});

  Future<Map<String, dynamic>> _checkSellerStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {'status': 'none'};

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDoc.exists) return {'status': 'none'};

      final userData = userDoc.data();
      if (userData?['role'] == 'seller') {
        return {'status': 'approved'};
      } else if (userData?['sellerRequest'] == true) {
        return {
          'status': 'pending',
          'requestDate': userData?['sellerRequestDate'] ?? 'Unknown date',
        };
      } else {
        return {'status': 'none'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<bool> _checkIfSeller() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      // Check if the user's role is 'seller'
      return userDoc.exists && userDoc.data()?['role'] == 'seller';
    } catch (e) {
      return false;
    }
  }

  void _promptLogin(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Login Required'),
            content: const Text(
              'You need to be logged in to access this feature.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE47F43),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showLoginModal(context);
                },
                child: const Text('LOGIN'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = username == 'Guest';

    return Scaffold(
      backgroundColor: Colors.white,
      // Removed AppBar
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile section with orange background
              Container(
                color: const Color(0xFFE47F43),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile icon
                        isGuest
                            ? Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 50,
                              ),
                            )
                            : FutureBuilder<DocumentSnapshot>(
                              future:
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(
                                        FirebaseAuth.instance.currentUser?.uid,
                                      )
                                      .get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const CircularProgressIndicator();
                                }

                                final userData =
                                    snapshot.data?.data()
                                        as Map<String, dynamic>?;

                                // Get the Supabase storage URL for the profile image
                                final String? profileImagePath =
                                    userData?['profile_image_url'];
                                String profileImageUrl;

                                if (profileImagePath != null &&
                                    profileImagePath.isNotEmpty) {
                                  // Build the full Supabase URL if we have a path
                                  final supabaseStorageUrl =
                                      'https://yvyknbymnqpwpxzkabnc.supabase.co/storage/v1/object/public/profile-pictures/';

                                  // Check if the path already has the full URL
                                  if (profileImagePath.startsWith('http')) {
                                    profileImageUrl = profileImagePath;
                                  } else {
                                    // Otherwise append the path to the base URL
                                    profileImageUrl =
                                        '$supabaseStorageUrl$profileImagePath';
                                  }
                                } else {
                                  // Default image if no profile image exists
                                  profileImageUrl =
                                      'https://yvyknbymnqpwpxzkabnc.supabase.co/storage/v1/object/public/profile-pictures/default-profile.png';
                                }

                                return Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      profileImageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        print(
                                          'Error loading profile image: $error',
                                        );
                                        return const Icon(
                                          Icons.person,
                                          color: Colors.grey,
                                          size: 50,
                                        );
                                      },
                                      loadingBuilder: (
                                        context,
                                        child,
                                        loadingProgress,
                                      ) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFE47F43),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
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
                            const SizedBox(height: 12),
                            // Edit profile button with improved styling
                            if (!isGuest)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit Profile'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF64350F),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  textStyle: const TextStyle(fontSize: 14),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              const EditProfileScreen(),
                                    ),
                                  );
                                },
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
                  ],
                ),
              ),

              // Seller Status Indicator (Only for logged-in users)
              if (!isGuest)
                FutureBuilder<Map<String, dynamic>>(
                  future: _checkSellerStatus(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    final status = snapshot.data?['status'] ?? 'none';

                    if (status == 'pending') {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          border: Border.all(color: Colors.amber),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.hourglass_top,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your seller request is pending approval',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Submitted on: ${snapshot.data?['requestDate'] ?? 'Unknown date'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (status == 'approved') {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.verified, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'You are a verified seller',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap "Start Selling" to manage your store',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),

              // Purchase History Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFECCBB2), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Purchase History',
                      style: TextStyle(
                        color: Color(0xFFE47F43),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (isGuest) {
                          _promptLogin(context);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PurchaseHistoryPage(initialTab: 'TO SHIP'),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: const [
                          Text(
                            'View All',
                            style: TextStyle(
                              color: Color(0xFFE47F43),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFFE47F43),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Purchase History Categories
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCategoryItem(
                      icon: Icons.local_shipping_outlined,
                      label: 'TO SHIP',
                      isActive: !isGuest,
                      onTap: () {
                        if (isGuest) {
                          _promptLogin(context);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PurchaseHistoryPage(initialTab: 'TO SHIP'),
                            ),
                          );
                        }
                      },
                    ),
                    _buildCategoryItem(
                      icon: Icons.shopping_bag_outlined,
                      label: 'TO RECEIVE',
                      isActive: !isGuest,
                      onTap: () {
                        if (isGuest) {
                          _promptLogin(context);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PurchaseHistoryPage(initialTab: 'TO RECEIVE'),
                            ),
                          );
                        }
                      },
                    ),
                    _buildCategoryItem(
                      icon: Icons.check_circle_outline,
                      label: 'COMPLETED',
                      isActive: !isGuest,
                      onTap: () {
                        if (isGuest) {
                          _promptLogin(context);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PurchaseHistoryPage(initialTab: 'COMPLETED'),
                            ),
                          );
                        }
                      },
                    ),
                    _buildCategoryItem(
                      icon: Icons.star_border,
                      label: 'TO RATE',
                      isActive: !isGuest,
                      onTap: () {
                        if (isGuest) {
                          _promptLogin(context);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PurchaseHistoryPage(initialTab: 'TO RATE'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.favorite_border,
                            label: 'Wishlist',
                            onPressed: () {
                              if (isGuest) {
                                _promptLogin(context);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const WishlistPage(),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.bookmark_border,
                            label: 'Addresses',
                            onPressed: () {
                              if (isGuest) {
                                _promptLogin(context);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AddressesPage(),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.info_outline,
                            label: 'Help Center',
                            // Everyone can access help center
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.store_outlined,
                            label: 'Start Selling',
                            onPressed: () async {
                              if (isGuest) {
                                _promptLogin(context);
                              } else {
                                final isSeller = await _checkIfSeller();
                                if (isSeller) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const SellerDashboard(),
                                    ),
                                  );
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) =>
                                              const RequestSellerPage(),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem({
    required IconData icon,
    required String label,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive ? const Color(0xFFE47F43) : Colors.grey[300],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed ?? () {},
      icon: Icon(icon, color: const Color(0xFFE47F43), size: 20),
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE47F43),
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: Color(0xFFE47F43)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}
