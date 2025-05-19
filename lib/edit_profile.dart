import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Add this import

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  File? _profileImage;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProfileChanged = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // Define color constants
  static const Color primaryColor = Color(0xFFD18050);
  static const Color darkBrownColor = Color(0xFF64350F);

  String? _googleProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _genderController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    if (_userId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No user is currently logged in.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch user data from Firebase Firestore
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _nameController.text = userData['username'] ?? '';
        _bioController.text = userData['bio'] ?? '';
        _genderController.text = userData['gender'] ?? '';
        _birthdayController.text = userData['birthday'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        _emailController.text = userData['email'] ?? '';

        // Fetch profile image from Supabase if URL/path exists
        if (userData['profile_image_url'] != null &&
            userData['profile_image_url'].toString().isNotEmpty) {
          final imagePath = userData['profile_image_url'];
          if (imagePath.startsWith('http')) {
            // It's a public URL (Google, Facebook, etc.)
            setState(() {
              _profileImage =
                  null; // Not a File, use the URL directly in the widget
              _selectedImage = null;
            });
            // Store the URL in a separate variable if needed
            _googleProfileImageUrl = imagePath;
          } else {
            // It's a Supabase Storage path
            try {
              final response = await _supabase.storage
                  .from('profile-pictures')
                  .download(imagePath);
              if (response != null) {
                final tempDir = Directory.systemTemp;
                final tempFile = File('${tempDir.path}/$_userId-profile.jpg');
                await tempFile.writeAsBytes(response);
                setState(() {
                  _profileImage = tempFile;
                });
              }
            } catch (e) {
              print('Profile image not found in storage, skipping: $e');
            }
          }
        }
      } else {
        // If the document doesn't exist, initialize default values
        _nameController.text = '';
        _bioController.text = '';
        _genderController.text = '';
        _birthdayController.text = '';
        _phoneController.text = '';
        _emailController.text = '';
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? profileImagePath;

      // Upload profile image to Supabase if changed
      if (_profileImage != null) {
        final fileName = '$_userId.jpg';
        final storageRef = _supabase.storage.from('profile-pictures');
        // Upload the file (upsert: true to overwrite)
        final response = await storageRef.upload(
          fileName,
          _profileImage!,
          fileOptions: const FileOptions(upsert: true),
        );
        if (response.isNotEmpty) {
          profileImagePath = fileName; // Store only the file name/path
        } else {
          throw Exception('Failed to upload profile image');
        }
      }

      // Prepare user data
      final userProfile = {
        'username': _nameController.text,
        'bio': _bioController.text,
        'gender': _genderController.text,
        'birthday': _birthdayController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        if (profileImagePath != null) 'profile_image_url': profileImagePath,
      };

      // Clean the data map of forbidden fields before update
      final forbiddenFields = ['role'];
      final safeData = Map<String, dynamic>.from(userProfile);
      forbiddenFields.forEach(safeData.remove);

      print('Current UID: $_userId');
      print('User profile map: $safeData');

      // Update user data in Firebase Firestore (use update instead of set)
      await _firestore.collection('users').doc(_userId).update(safeData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: primaryColor,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      // Handle permissions for Android
      if (Platform.isAndroid) {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = deviceInfo.version.sdkInt;

        if (source == ImageSource.gallery) {
          PermissionStatus galleryStatus;
          if (sdkInt >= 33) {
            // Android 13+ (API 33+): Use photos permission
            galleryStatus = await Permission.photos.status;
            if (galleryStatus.isDenied) {
              galleryStatus = await Permission.photos.request();
            }
            galleryStatus = await Permission.photos.status;
          } else {
            // Below Android 13: Use storage permission
            galleryStatus = await Permission.storage.status;
            if (galleryStatus.isDenied) {
              galleryStatus = await Permission.storage.request();
            }
            galleryStatus = await Permission.storage.status;
          }

          // Handle permanent denial
          if (galleryStatus.isPermanentlyDenied) {
            if (!mounted) return;
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Permissions Required'),
                    content: const Text(
                      'Gallery access requires permission. Please enable it in app settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          openAppSettings();
                        },
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
            );
            return;
          }

          // Check if still denied after request
          if (galleryStatus.isDenied || galleryStatus.isRestricted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gallery access requires permission'),
              ),
            );
            return;
          }
        } else if (source == ImageSource.camera) {
          // Check camera permission
          PermissionStatus cameraStatus = await Permission.camera.status;
          if (cameraStatus.isDenied) {
            cameraStatus = await Permission.camera.request();
          }
          cameraStatus = await Permission.camera.status;
          if (cameraStatus.isPermanentlyDenied) {
            if (!mounted) return;
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Permissions Required'),
                    content: const Text(
                      'Camera access requires permission. Please enable it in app settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          openAppSettings();
                        },
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
            );
            return;
          }
          if (cameraStatus.isDenied || cameraStatus.isRestricted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camera permission is required')),
            );
            return;
          }
        }
      }

      // Pick image
      final XFile? pickedImage = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      // Handle null result (user canceled)
      if (pickedImage == null) {
        return;
      }

      // Process image
      final File imageFile = File(pickedImage.path);
      final fileSize = await imageFile.length();

      // Check file size
      if (fileSize > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image is too large. Please select a smaller image.'),
          ),
        );
        return;
      }

      // Update state
      setState(() {
        _selectedImage = imageFile;
        _profileImage = imageFile;
        _isProfileChanged = true;
      });
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to get image: ${e.toString().contains('permission') ? 'Permission denied' : 'Please try again with a different image'}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _birthdayController.text.isNotEmpty
              ? DateFormat('MM/dd/yyyy').parse(_birthdayController.text)
              : DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<bool> _onWillPop() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Discard Changes?',
                  style: TextStyle(color: Color(0xFF333333)),
                ),
                content: const Text(
                  'Any unsaved changes will be lost.',
                  style: TextStyle(color: Colors.grey),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Discard',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Choose Profile Picture",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBrownColor,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImagePickerOption(
                    icon: Icons.photo_library,
                    label: "Gallery",
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildImagePickerOption(
                    icon: Icons.camera_alt,
                    label: "Camera",
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 2),
            ),
            child: Icon(icon, color: primaryColor, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: darkBrownColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'You are not logged in.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_userId.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'No user is currently logged in.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Show error message if it exists
    if (_errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
        _errorMessage = null;
      });
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldPop = await _onWillPop();
        if (shouldPop) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        // Use a custom scroll view to make the header static
        body: CustomScrollView(
          slivers: [
            // Static header with Brown background
            SliverAppBar(
              pinned: true, // Keeps the app bar visible when scrolling
              expandedHeight: 300.0, // Height of the expanded header
              backgroundColor: primaryColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () async {
                  if (await _onWillPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: const Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: SafeArea(
                  child: Column(
                    children: [
                      // Extra space to account for the AppBar title
                      const SizedBox(height: 56),

                      // Edit Profile Button at top with logo
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Pou logo image
                            Image.asset(
                              'assets/images/pou_logo_brown.png',
                              height: 24,
                              width: 24,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.person,
                                  size: 24,
                                  color: primaryColor,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Edit Profile',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Profile Photo Circle
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          GestureDetector(
                            // Make the entire circle clickable
                            onTap: () => _showImageSourceDialog(),
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child:
                                    _profileImage != null
                                        ? Image.file(
                                          _profileImage!,
                                          fit: BoxFit.cover,
                                          width: 110,
                                          height: 110,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return const Center(
                                              child: Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        )
                                        : (_googleProfileImageUrl != null
                                            ? Image.network(
                                              _googleProfileImageUrl!,
                                              fit: BoxFit.cover,
                                              width: 110,
                                              height: 110,
                                              errorBuilder: (
                                                context,
                                                error,
                                                stackTrace,
                                              ) {
                                                return const Center(
                                                  child: Icon(
                                                    Icons.person,
                                                    size: 60,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                            )
                                            : const Center(
                                              child: Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.grey,
                                              ),
                                            )),
                              ),
                            ),
                          ),
                          // Camera icon
                          GestureDetector(
                            onTap: () => _showImageSourceDialog(),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Choose Image Button
                      GestureDetector(
                        onTap: () => _showImageSourceDialog(),
                        child: Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.camera_alt,
                                color: primaryColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Change Photo',
                                style: TextStyle(
                                  color: darkBrownColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // The content below the header - scrollable
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Name and Bio section
                    _buildFormSection(
                      children: [
                        _buildFormField(
                          label: 'Name',
                          controller: _nameController,
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          label: 'Bio',
                          controller: _bioController,
                          maxLines: 3,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Gender and Birthday section
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildFormSection(
                            children: [
                              _buildFormField(
                                label: 'Gender',
                                controller: _genderController,
                                suffixIcon: PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color:
                                        darkBrownColor, // Changed from white to darkBrownColor
                                  ),
                                  onSelected: (value) {
                                    setState(() {
                                      _genderController.text = value;
                                    });
                                  },
                                  itemBuilder:
                                      (context) =>
                                          [
                                                'Male',
                                                'Female',
                                                'Non-binary',
                                                'Prefer not to say',
                                              ]
                                              .map(
                                                (gender) => PopupMenuItem(
                                                  value: gender,
                                                  child: Text(gender),
                                                ),
                                              )
                                              .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: _buildFormSection(
                            children: [
                              _buildFormField(
                                label: 'Birthday',
                                controller: _birthdayController,
                                hint: 'MM/DD/YYYY',
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color:
                                        darkBrownColor, // Changed from white to darkBrownColor
                                  ),
                                  onPressed: () => _selectDate(context),
                                ),
                                readOnly: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Phone and Email section
                    _buildFormSection(
                      children: [
                        _buildFormField(
                          label: 'Phone',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Cancel and Save buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              if (await _onWillPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: primaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: primaryColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveUserProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              'Save Changes',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Extra space at the bottom for better scrolling experience
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            readOnly: readOnly,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}
