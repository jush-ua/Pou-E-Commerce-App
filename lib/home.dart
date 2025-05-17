import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'product_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  Future<void> _fetchProducts() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('products').get();

      if (mounted) {
        setState(() {
          _products =
              querySnapshot.docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _products = []; // Ensure the list is empty in case of an error
        });
      }

      // Show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('permission-denied')
                ? 'You do not have permission to access the products.'
                : 'Failed to fetch products. Please try again later.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    // Start a timer to rotate pages every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_pageController.hasClients) {
        setState(() {
          _currentPage = (_currentPage + 1) % 3; // Assuming 3 pages
        });
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
    _fetchProducts();
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    _pageController.dispose(); // Dispose of the PageController
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
              _isLoading
                  ? const Center(
                    child:
                        CircularProgressIndicator(), // Show a loading indicator
                  )
                  : _products.isEmpty
                  ? const Center(
                    child: Text(
                      'No products available.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                  : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'All Products',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ProductDetails(
                                          productName:
                                              product['name'] ??
                                              'Unknown Product',
                                          productPrice:
                                              'P${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                                          productDescription:
                                              product['description'] ??
                                              'No description available',
                                          imageUrl: product['imageUrl'] ?? '',
                                          soldCount:
                                              product['soldCount']
                                                  ?.toString() ??
                                              '0',
                                        ),
                                  ),
                                );
                              },
                              child: _buildProductCard(
                                product['name'] ?? 'Unknown Product',
                                Icons.shopping_bag,
                                'P${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                                'Sold: ${product['soldCount'] ?? '0'}',
                                product['imageUrl'] ?? '',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
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
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_isLoading)
              const Center(
                child:
                    CircularProgressIndicator(), // Show a loading indicator while fetching data
              )
            else if (_products.isEmpty)
              const Center(
                child: Text(
                  'No products available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                ),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ProductDetails(
                                productName:
                                    product['name'] ?? 'Unknown Product',
                                productPrice:
                                    'P${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                                productDescription:
                                    product['description'] ??
                                    'No description available',
                                imageUrl: product['imageUrl'] ?? '',
                                soldCount:
                                    product['soldCount']?.toString() ?? '0',
                              ),
                        ),
                      );
                    },
                    child: _buildProductCard(
                      product['name'] ?? 'Unknown Product',
                      Icons.shopping_bag,
                      'P${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                      'Sold: ${product['soldCount'] ?? '0'}',
                      product['imageUrl'] ?? '',
                    ),
                  );
                },
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
    String imageUrl,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                image:
                    imageUrl.isNotEmpty
                        ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                        : null,
                color: Colors.grey[200],
              ),
              child:
                  imageUrl.isEmpty
                      ? const Center(
                        child: Icon(Icons.image, size: 60, color: Colors.grey),
                      )
                      : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE47F43),
                      ),
                    ),
                    Text(
                      soldCount,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProduct({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => ProductDetails(
                  productName: title,
                  productPrice: "N/A",
                  productDescription:
                      "Description not available", // Add placeholder
                  imageUrl: "", // Add placeholder
                  soldCount: "N/A",
                ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              var curve = Curves.easeOutCubic;
              var curveTween = CurveTween(curve: curve);

              var fadeTween = Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).chain(curveTween);

              var scaleTween = Tween<double>(
                begin: 0.85,
                end: 1.0,
              ).chain(curveTween);

              return FadeTransition(
                opacity: animation.drive(fadeTween),
                child: ScaleTransition(
                  scale: animation.drive(scaleTween),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      },
      child: Container(
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
      ),
    );
  }
}
