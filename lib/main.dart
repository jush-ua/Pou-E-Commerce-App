import 'package:flutter/material.dart';
import 'home.dart'; // Import the HomePage widget
import 'profile.dart'; // Import the ProfilePage widget

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 2; // Start with Search (index 2) selected
  late AnimationController _animationController;

  // Create a list of pages that will be displayed
  final List<Widget> _pages = [
    const HomePage(
      title: 'Home',
      description: 'Welcome to the Home Page',
    ), // Actual HomePage
    const CartPage(), // Placeholder for CartPage
    const SearchPage(), // Placeholder for SearchPage
    const ChatPage(), // Placeholder for ChatPage
    const ProfilePage(), // Actual ProfilePage
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
      // Reset animation and start it again
      _animationController.reset();
      setState(() {
        _selectedIndex = index;
      });
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Add the custom app bar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: CustomAppBar(),
      ),
      // Add fade transition for page switching
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
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFFE47F43), // Orange color
        boxShadow: [
          BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      // Add a subtle animation to the app bar
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cloud icon with a subtle rotation
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(seconds: 1),
                builder: (context, double value, child) {
                  return Transform.rotate(
                    angle: (1 - value) * 0.1,
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.cloud, color: Colors.white, size: 30),
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
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color orangeColor = Color(0xFFE47F43);

    return Container(
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
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_outlined, 'Home', orangeColor),
          _buildNavItem(1, Icons.shopping_cart_outlined, 'Cart', orangeColor),
          _buildSearchNavItem(orangeColor),
          _buildNavItem(3, Icons.chat_bubble_outline, 'Chat', orangeColor),
          _buildNavItem(4, Icons.person_outline, 'Profile', orangeColor),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    Color orangeColor,
  ) {
    final bool isSelected = selectedIndex == index;

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      builder: (context, double value, child) {
        return Transform.scale(scale: isSelected ? value : 1.0, child: child);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemTapped(index),
          splashColor: orangeColor.withOpacity(0.2),
          highlightColor: orangeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            width: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  transform:
                      isSelected
                          ? (Matrix4.identity()..scale(1.1))
                          : Matrix4.identity(),
                  child: Icon(
                    icon,
                    color: isSelected ? orangeColor : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: isSelected ? orangeColor : Colors.grey,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchNavItem(Color orangeColor) {
    final bool isSelected = selectedIndex == 2;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemTapped(2),
        splashColor: orangeColor.withOpacity(0.2),
        highlightColor: orangeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Animated container for search button
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.elasticOut,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: isSelected ? value : 1.0,
                  child: child,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isSelected ? orangeColor : Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? orangeColor : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
              child: const Text('Search'),
            ),
          ],
        ),
      ),
    );
  }
}

// home.dart

class CartPage extends StatelessWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart, size: 80, color: Color(0xFFE47F43)),
            SizedBox(height: 16),
            Text('Cart Page', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}

class SearchPage extends StatelessWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 80, color: Color(0xFFE47F43)),
            const SizedBox(height: 16),
            const Text('Search Page', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFFE47F43),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
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
  const ChatPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble, size: 80, color: Color(0xFFE47F43)),
            SizedBox(height: 16),
            Text('Chat Page', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 80, color: Color(0xFFE47F43)),
            SizedBox(height: 16),
            Text('Profile Page', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}
