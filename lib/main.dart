import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'home.dart'; // Import the HomePage widget
import 'profile.dart'; // Import the ProfilePage widget
import 'search.dart'; // Import the SearchPage widget
import 'session_manager.dart'; // Import the SessionManager widget
import 'login.dart'; // Import the LoginPage widget
import 'splash_screen.dart'; // Import the new splash screen
import 'cart.dart'; // Import the CartPage widget
import 'chat.dart'; // Import the ChatPage widget
import 'chatlist.dart'; // Import the ChatPage widget
import 'checkout_page.dart'; // Import the CheckoutPage widget
import 'package:flutter/services.dart'; // Import services for system UI

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;

  // Initialize app
  Future<void> _initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter is initialized

    // Initialize Firebase
    await Firebase.initializeApp();

    // Initialize Supabase
    await sb.Supabase.initialize(
      url: 'https://yvyknbymnqpwpxzkabnc.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2eWtuYnltbnFwd3B4emthYm5jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU4OTAyMzIsImV4cCI6MjA2MTQ2NjIzMn0.Y2Gpho8Hg_GBMo6P1J0i6fdVaKJ6nGdeaRm_HwzGSMY',
    );

    setState(() {
      _initialized = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    // Apply system UI style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ShaPou',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE47F43)),
        useMaterial3: true,
        fontFamily: 'Inter', // or 'Poppins' or 'Nunito'
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(fontFamily: 'Inter'),
          bodyMedium: TextStyle(fontFamily: 'Inter'),
          labelLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
          ),
        ),
        // Add page transitions theme
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: OpenUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home:
          !_initialized
              ? SplashScreen(
                onInitializationComplete: () {
                  if (!_initialized) {
                    // In case initialization takes longer than splash screen animation
                    setState(() {
                      _initialized = true;
                    });
                  }
                },
              )
              : SessionManager(
                onSessionValid:
                    (username) => MainScreen(
                      isLimited: false,
                      initialPageIndex: 0,
                      username: username,
                    ),
                onSessionInvalid:
                    () => MainScreen(
                      isLimited: true,
                      initialPageIndex: 0,
                      username: 'Guest',
                    ),
              ),
      routes: {
        // ...other routes...
        '/chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map? ?? {};
          return ChatPage(
            peerId: args['peerId'] ?? '',
            peerUsername: args['peerUsername'] ?? '',
            peerAvatar: args['peerAvatar'],
            sellerId: args['sellerId'], // <-- Now valid
            productName: args['productName'], // <-- Now valid
          );
        },
        '/checkout': (context) => CheckoutPage(items: []),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isLimited; // Add a flag for limited features
  final int initialPageIndex; // Add an initial page index
  final String username; // Add a username parameter

  const MainScreen({
    super.key,
    this.isLimited = false,
    this.initialPageIndex = 0, // Default to HomePage
    this.username = 'Guest',
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late int _selectedIndex;
  late AnimationController _animationController;

  // Create a list of pages that will be displayed
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialPageIndex; // Set the initial page index
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();

    // Define pages based on access level
    _pages = [
      const HomePage(title: 'Home', description: 'Welcome to the Home Page'),
      widget.isLimited
          ? const Center(child: Text('Upgrade to access the Cart'))
          : const CartPage(), // <-- This is your real cart.dart CartPage
      const SearchScreen(),
      widget.isLimited
          ? const Center(child: Text('Upgrade to access Chat features'))
          : ChatUserListPage(),
      ProfilePage(username: widget.username), // Pass username to ProfilePage
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index != _selectedIndex) {
      // Update the selected index and restart the animation
      setState(() {
        _selectedIndex = index;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(),
      ),
      body: SafeArea(
        // Wrap body with SafeArea
        bottom:
            false, // Don't add bottom padding since we handle it in bottomNavigationBar
        child: FadeTransition(
          opacity: _animationController,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: _pages[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          if (widget.isLimited && (index == 1 || index == 3)) {
            // Show a message for restricted features
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This feature is available for logged-in users.'),
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            _onItemTapped(index);
          }
        },
      ),
    );
  }
}

// Custom App Bar
class CustomAppBar extends StatelessWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(top: topPadding), // Add status bar padding
      height: 60 + topPadding, // Add status bar height to app bar height
      decoration: const BoxDecoration(
        color: Color(0xFFE47F43), // Orange color
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05, // Dynamic horizontal padding
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                child: Image.asset(
                  'assets/images/pou_logo.png',
                  height: screenWidth * 0.08, // Adjust logo size
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ShaPou',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter', // Add this
                  letterSpacing: 0.5, // Optional: adds modern spacing
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Bottom Navigation Bar with animations
class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    
    // Responsive sizing based on screen dimensions
    final bool isSmallScreen = screenWidth < 360 || screenHeight < 640;
    final bool isVerySmallScreen = screenWidth < 320;
    
    // Dynamic values based on screen size
    final double baseHeight = isVerySmallScreen ? 60 : (isSmallScreen ? 65 : 70);
    final double topPadding = isVerySmallScreen ? 2 : 4;
    final double verticalPadding = isVerySmallScreen ? 4 : 6;
    final double iconSize = isVerySmallScreen ? 20 : (isSmallScreen ? 22 : 24);
    final double searchIconSize = isVerySmallScreen ? 18 : (isSmallScreen ? 20 : 22);
    final double searchButtonSize = isVerySmallScreen ? 36 : (isSmallScreen ? 38 : 42);
    final double fontSize = isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 11);
    final double iconPadding = isVerySmallScreen ? 4 : 6;
    final double spacingHeight = isVerySmallScreen ? 1 : 2;

    return Container(
      height: baseHeight + bottomPadding,
      padding: EdgeInsets.only(
        bottom: bottomPadding,
        top: topPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_outlined, 'Home', screenWidth, iconSize, fontSize, verticalPadding, iconPadding, spacingHeight),
          _buildNavItem(1, Icons.shopping_cart_outlined, 'Cart', screenWidth, iconSize, fontSize, verticalPadding, iconPadding, spacingHeight),
          _buildSearchNavItem(screenWidth, searchIconSize, searchButtonSize, fontSize, verticalPadding, spacingHeight),
          _buildNavItem(3, Icons.chat_bubble_outline, 'Chat', screenWidth, iconSize, fontSize, verticalPadding, iconPadding, spacingHeight),
          _buildNavItem(4, Icons.person_outline, 'Profile', screenWidth, iconSize, fontSize, verticalPadding, iconPadding, spacingHeight),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    double screenWidth,
    double iconSize,
    double fontSize,
    double verticalPadding,
    double iconPadding,
    double spacingHeight,
  ) {
    final bool isSelected = selectedIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemTapped(index),
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFFE47F43).withOpacity(0.2),
          highlightColor: const Color(0xFFE47F43).withOpacity(0.1),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? const Color(0xFFE47F43).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: isSelected ? const Color(0xFFE47F43) : Colors.grey[600],
                  ),
                ),
                SizedBox(height: spacingHeight),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: fontSize,
                    color: isSelected ? const Color(0xFFE47F43) : Colors.grey[600],
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchNavItem(
    double screenWidth,
    double searchIconSize,
    double searchButtonSize,
    double fontSize,
    double verticalPadding,
    double spacingHeight,
  ) {
    final bool isSelected = selectedIndex == 2;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemTapped(2),
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0xFFE47F43).withOpacity(0.2),
          highlightColor: const Color(0xFFE47F43).withOpacity(0.1),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: searchButtonSize,
                  height: searchButtonSize,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE47F43)
                        : Colors.grey.withOpacity(0.15),
                    shape: BoxShape.circle,
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFFE47F43).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Icon(
                    Icons.search,
                    color: isSelected ? Colors.white : Colors.grey[600],
                    size: searchIconSize,
                  ),
                ),
                SizedBox(height: spacingHeight),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFE47F43) : Colors.grey[600],
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  child: const Text(
                    'Search',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// home.dart
