import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({Key? key, required this.onInitializationComplete})
    : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Reduced animation duration for faster loading
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Smoother fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Subtle scale animation for logo
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    // Start animation immediately
    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Preload critical resources
      await _preloadAssets();

      // Minimum splash duration for branding (reduced from 2000ms)
      await Future.delayed(const Duration(milliseconds: 1500));

      setState(() {
        _isInitialized = true;
      });

      // Small delay before navigation
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        widget.onInitializationComplete();
      }
    } catch (e) {
      // If initialization fails, still proceed after timeout
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        widget.onInitializationComplete();
      }
    }
  }

  Future<void> _preloadAssets() async {
    try {
      // Preload the logo image to avoid loading delays
      await precacheImage(
        const AssetImage('assets/images/pou_logo.png'),
        context,
      );
    } catch (e) {
      // Continue if image preloading fails
      debugPrint('Failed to preload logo: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar color for better visual consistency
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFE47F43),
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE47F43),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Center(
                  child: SingleChildScrollView(
                    // Prevent overflow on very small screens
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo with optimized loading
                          _buildLogo(),
                          const SizedBox(height: 28),

                          // App name with responsive font size
                          _buildAppName(),
                          const SizedBox(height: 8),

                          // Tagline with responsive styling
                          _buildTagline(),
                          const SizedBox(height: 40),

                          // Loading indicator with status
                          _buildLoadingIndicator(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120, // Slightly smaller for better performance
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/pou_logo.png',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          // Optimized for better performance
          cacheWidth: 240, // 2x for high DPI screens
          cacheHeight: 240,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.shopping_bag,
                size: 60,
                color: Color(0xFFE47F43),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppName() {
    // Responsive font size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 360 ? 42.0 : 52.0;

    return Text(
      'ShaPou',
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.5,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTagline() {
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize = screenWidth < 360 ? 16.0 : 18.0;

    return Text(
      'your shopping companion',
      style: TextStyle(
        color: Colors.white70,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLoadingIndicator() {
    return Column(
      children: [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isInitialized ? 'Ready!' : 'Loading...',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 14,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
