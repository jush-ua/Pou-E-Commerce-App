import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class LoginModal extends StatefulWidget {
  const LoginModal({super.key});

  @override
  State<LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends State<LoginModal>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  bool _obscurePassword = true;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<TextEditingController, FocusNode> _focusNodes = {};
  final Map<TextEditingController, bool> _isFocused = {};

  @override
  void initState() {
    super.initState();

    // Initialize focus nodes and listeners
    [_emailController, _passwordController, _usernameController].forEach((
      controller,
    ) {
      final focusNode = FocusNode();
      _focusNodes[controller] = focusNode;
      _isFocused[controller] = false;

      focusNode.addListener(() {
        setState(() {
          _isFocused[controller] = focusNode.hasFocus;
        });
      });
    });

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Create fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Create slide animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    // Dispose focus nodes
    _focusNodes.values.forEach((node) => node.dispose());

    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleForm() {
    // Reset animation and play again
    _animationController.reset();
    setState(() {
      _isRegistering = !_isRegistering;
    });
    _animationController.forward();
  }

  // Login, register, and Google sign-in methods remain the same
  Future<void> _loginUser() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null && mounted) {
        final userData =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        final username = userData.data()?['username'] ?? 'Guest';

        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => MainScreen(
                  isLimited: false,
                  initialPageIndex: 4,
                  username: username,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Login failed';
        if (e is FirebaseAuthException) {
          errorMessage =
              e.code == 'user-not-found'
                  ? 'No user found with this email'
                  : e.code == 'wrong-password'
                  ? 'Incorrect email or password'
                  : 'Login failed: ${e.message}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerUser() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        const defaultProfilePictureUrl =
            'https://yvyknbymnqpwpxzkabnc.supabase.co/storage/v1/object/public/profile-pictures/image_2025-05-16_221317901.png';

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'profile_image_url': defaultProfilePictureUrl,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (e is FirebaseAuthException && e.code == 'email-already-in-use') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This email is already registered.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Always sign out first to force account picker
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth = FirebaseAuth.instance;
      final userCredential = await auth.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'username': user.displayName ?? 'Guest',
                'email': user.email ?? '',
                'profile_image_url': user.photoURL ?? '',
                'role': 'user',
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In successful!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => MainScreen(
                  isLimited: false,
                  initialPageIndex: 4,
                  username: user.displayName ?? 'Guest',
                ),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close the modal first
      Future.delayed(const Duration(milliseconds: 100), () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google Sign-In failed: ${e is FirebaseAuthException ? e.message : e.toString()}',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          // Ensures content is scrollable
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle indicator at top of modal
                    Container(
                      height: 5,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),

                    // Logo/branding element
                    Container(
                      width: isSmallScreen ? 80 : 100,
                      height: isSmallScreen ? 80 : 100,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE47F43).withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/pou_logo_brown.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to icon if image loading fails
                          return Icon(
                            Icons.shopping_bag_outlined,
                            size: isSmallScreen ? 30 : 40,
                            color: const Color(0xFFE47F43),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // Title with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (
                        Widget child,
                        Animation<double> animation,
                      ) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.5),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _isRegistering ? 'Create Account' : 'Welcome',
                        key: ValueKey(_isRegistering),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF333333),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),

                    // Subtitle with animation
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _isRegistering
                            ? 'Sign up to start shopping'
                            : 'Sign in to continue',
                        key: ValueKey(_isRegistering),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),

                    // Form fields
                    if (_isRegistering)
                      _buildAnimatedTextField(
                        controller: _usernameController,
                        labelText: 'Username',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          if (value.length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                    if (_isRegistering)
                      SizedBox(height: isSmallScreen ? 12 : 16),

                    _buildAnimatedTextField(
                      controller: _emailController,
                      labelText: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),

                    _buildAnimatedTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),

                    // Primary action button with loading animation
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : _isRegistering
                                ? _registerUser
                                : _loginUser,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          backgroundColor: const Color(0xFFD18050),
                        ).copyWith(
                          backgroundColor: MaterialStateProperty.resolveWith((
                            states,
                          ) {
                            // Use a subtle gradient effect for the background
                            return const Color(0xFFE47F43);
                          }),
                          overlayColor: MaterialStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(MaterialState.pressed)) {
                              return Colors.white.withOpacity(0.1);
                            }
                            return null;
                          }),
                        ),
                        child:
                            _isLoading
                                ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                )
                                : Row(
                                  mainAxisSize:
                                      MainAxisSize
                                          .min, // Ensure row doesn't expand too much
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _isRegistering
                                            ? 'Create Account'
                                            : 'Sign In',
                                        overflow:
                                            TextOverflow
                                                .ellipsis, // Handle text overflow
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 4 : 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: isSmallScreen ? 14 : 18,
                                    ),
                                  ],
                                ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // Divider with "or" text
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 16,
                          ),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // Google Sign-In button with animation
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: AnimatedOpacity(
                        opacity: _isLoading ? 0.6 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: Image.network(
                            'https://developers.google.com/identity/images/g-logo.png',
                            height: isSmallScreen ? 20 : 24,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.g_mobiledata, size: 24);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                height: isSmallScreen ? 20 : 24,
                                width: isSmallScreen ? 20 : 24,
                                child: const Center(
                                  child: SizedBox(
                                    height: 12,
                                    width: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFD18050),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          label: Text(
                            'Continue with Google',
                            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 12 : 16,
                              horizontal: 20,
                            ),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 20),

                    // Toggle between login and register
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRegistering
                              ? 'Already have an account? '
                              : 'Don\'t have an account? ',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleForm,
                          child: Text(
                            _isRegistering ? 'Sign In' : 'Sign Up',
                            style: TextStyle(
                              color: const Color(0xFFE47F43),
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 12 : 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Add bottom padding to ensure the last element is not cut off on small screens
                    SizedBox(height: isSmallScreen ? 16 : 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to create animated text fields with properly centered text
  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    final isFocused = _isFocused[controller] ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? const Color(0xFFD18050) : Colors.grey.shade300,
          width: isFocused ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isFocused
                    ? const Color(0xFFD18050).withOpacity(0.1)
                    : Colors.black.withOpacity(0.03),
            blurRadius: 8,
            spreadRadius: isFocused ? 2 : 1,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: _focusNodes[controller],
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16),
        textAlignVertical: TextAlignVertical.center, // Centers text vertically
        decoration: InputDecoration(
          isDense: true, // Makes the field more compact
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16, // Increase slightly for better vertical centering
            horizontal: 12,
          ),
          border: InputBorder.none,
          labelText: labelText,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 15, // Slightly adjust font size
          ),
          alignLabelWithHint: true,
          // Remove height property that could cause misalignment
          prefixIcon: Container(
            width: 48,
            margin: const EdgeInsets.only(right: 4), // Add margin for spacing
            child: Center(
              child: Icon(icon, color: const Color(0xFFD18050), size: 22),
            ),
          ),
          // Use Container instead of SizedBox for better control
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          // Ensure consistent constraints for suffix icons
          suffixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
        validator: validator,
      ),
    );
  }
}

void showLoginModal(BuildContext context) {
  HapticFeedback.lightImpact(); // Provide haptic feedback

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 400),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.9, // Start at 90% of screen height
        minChildSize: 0.6, // Minimum 60% of screen height
        maxChildSize: 0.95, // Maximum 95% of screen height
        expand: false,
        builder: (context, scrollController) {
          return const LoginModal();
        },
      );
    },
  );
}
