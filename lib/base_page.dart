import 'package:flutter/material.dart';
import 'home.dart';
import 'product_details.dart';
import 'profile.dart';

class BasePage extends StatefulWidget {
  final int initialIndex;

  const BasePage({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<BasePage> createState() => _BasePageState();
}

class _BasePageState extends State<BasePage> {
  int _currentIndex = 0;

  // Initialize _pages directly when declared
  final List<Widget> _pages = [
    HomePage(title: 'Home', description: 'Welcome to Pou!'),
    Center(child: Text('Cart Page')), // Placeholder for Cart Page
    Center(child: Text('Chat Page')), // Placeholder for Chat Page
    ProfilePage(), // Profile Page
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex; // Set the initial index
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _pages[_currentIndex], // Display the selected page
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Update the selected index
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD88144),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "Cart",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Chat",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
