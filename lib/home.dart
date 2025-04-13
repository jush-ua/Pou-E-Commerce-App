import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'product_details.dart';

class HomePage extends StatefulWidget {
  final String title;
  final String description;

  const HomePage({super.key, required this.title, required this.description});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isExpanded = false;
  late PageController _pageController; // PageController for PageView
  int _currentPage = 0; // Track the current page
  late Timer _timer; // Timer for automatic page rotation

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // Start a timer to rotate pages every 3 seconds
    _timer = Timer.periodic(Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) {
        setState(() {
          _currentPage = (_currentPage + 1) % 3; // Assuming 3 pages
        });
        _pageController.animateToPage(
          _currentPage,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    _pageController.dispose(); // Dispose the PageController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child:
              _isExpanded ? _buildExpandedContent() : _buildCollapsedContent(),
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Your widget title and description
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFD88144),
                  ),
                  child: Text('Collapse'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedContent() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = true;
        });
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Featured',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController, // Attach the PageController
                    children: [
                      _buildFeaturedProduct(
                        icon: Icons.pets,
                        title: "Pou Plushie",
                        description: "Tap to see more details",
                      ),
                      _buildFeaturedProduct(
                        icon: Icons.coffee,
                        title: "Pou Mug",
                        description: "Tap to see more details",
                      ),
                      _buildFeaturedProduct(
                        icon: Icons.shopping_bag,
                        title: "Pou Bag",
                        description: "Tap to see more details",
                      ),
                    ],
                  ),
                  Positioned(
                    left: 10,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: Icon(Icons.chevron_left, size: 40),
                      onPressed: () {
                        if (_pageController.hasClients) {
                          setState(() {
                            _currentPage = (_currentPage - 1) % 3;
                          });
                          _pageController.previousPage(
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: Icon(Icons.chevron_right, size: 40),
                      onPressed: () {
                        if (_pageController.hasClients) {
                          setState(() {
                            _currentPage = (_currentPage + 1) % 3;
                          });
                          _pageController.nextPage(
                            duration: Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Best Seller',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              padding: EdgeInsets.all(10),
              children: [
                _buildProductCard(
                  'Poute Bag',
                  Icons.shopping_bag,
                  'P637.28',
                  '599',
                ),
                _buildProductCard('Pou Mug', Icons.coffee, 'P564.54', '478'),
                _buildProductCard('Pou Cap', Icons.face, 'P399.99', '325'),
                _buildProductCard(
                  'Pou Phone Case',
                  Icons.phone_iphone,
                  'P299.99',
                  '210',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    String name,
    IconData icon,
    String price,
    String soldCount,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ProductDetails(
                  productName: name,
                  productPrice: price,
                  productIcon: icon,
                  soldCount: soldCount,
                ),
          ),
        );
      },
      child: Card(
        elevation: 0,
        color: Color(0xFFF0F0F0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Center(child: Icon(icon, size: 60, color: Colors.brown)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        price,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Sold: $soldCount',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedProduct({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey[200],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.brown),
            SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            Text(description),
          ],
        ),
      ),
    );
  }
}
