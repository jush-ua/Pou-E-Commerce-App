import 'package:flutter/material.dart';
import 'home.dart'; // Import the HomePage widget
import 'profile.dart'; // Import the ProfilePage widget
import 'search.dart'; // Import the SearchPage widget

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Custom App Bar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE47F43)),
        useMaterial3: true,
        // Add page transitions theme
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: OpenUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0; // Set HomePage (index 0) as the starting page
  late AnimationController _animationController;

  // Create a list of pages that will be displayed
  final List<Widget> _pages = [
    const HomePage(
      title: 'Home',
      description: 'Welcome to the Home Page',
    ), // Actual HomePage
    const CartPage(), // CartPage
    const SearchScreen(), // SearchPage
    const ChatPage(), // ChatPage
    const ProfilePage(), // ProfilePage
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
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
      body: FadeTransition(
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
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
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

    return Container(
      height: screenWidth * 0.15, // Adjust height based on screen width
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
                'pou',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
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

    return Container(
      height: screenWidth * 0.15, // Adjust height dynamically
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
          _buildNavItem(0, Icons.home_outlined, 'Home', screenWidth),
          _buildNavItem(1, Icons.shopping_cart_outlined, 'Cart', screenWidth),
          _buildSearchNavItem(screenWidth),
          _buildNavItem(3, Icons.chat_bubble_outline, 'Chat', screenWidth),
          _buildNavItem(4, Icons.person_outline, 'Profile', screenWidth),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    double screenWidth,
  ) {
    final bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: SizedBox(
        width: screenWidth * 0.18, // Adjust width dynamically
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: screenWidth * 0.07, // Adjust icon size
              color: isSelected ? const Color(0xFFE47F43) : Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: isSelected ? const Color(0xFFE47F43) : Colors.grey,
              ), // Adjust font size
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchNavItem(double screenWidth) {
    final bool isSelected = selectedIndex == 2;

    return GestureDetector(
      onTap: () => onItemTapped(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE47F43)
                  : Colors.grey.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search,
              color: isSelected ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSelected ? const Color(0xFFE47F43) : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}

// home.dart

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart,
              size: screenWidth * 0.2, // Adjust icon size
              color: const Color(0xFFE47F43),
            ),
            const SizedBox(height: 16),
            Text(
              'Cart Page',
              style: TextStyle(
                fontSize: screenWidth * 0.06,
              ), // Adjust font size
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Processing your order...'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.2, // Adjust padding
                  vertical: screenWidth * 0.04,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                'Check Out',
                style: TextStyle(
                  fontSize: screenWidth * 0.05, // Adjust font size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Chat Icon
            const Icon(Icons.chat_bubble, size: 80, color: Color(0xFFE47F43)),
            const SizedBox(height: 16),
            // Chat Text
            const Text('Chat Page', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}
