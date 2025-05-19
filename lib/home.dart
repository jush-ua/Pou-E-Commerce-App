import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'product_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  // For long lists, implement pagination:
  final ScrollController _scrollController = ScrollController();
  int _limit = 10;
  bool _hasMore = true;

  // Add these variables to your _HomePageState class:
  List<Map<String, dynamic>> _featuredProducts = [];
  List<Map<String, dynamic>> _bestSellerProducts = [];

  Future<void> _fetchProducts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch all products
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('products')
              .limit(_limit)
              .get();

      // Fetch featured products (products marked as featured or top 3 by price)
      final featuredQuery =
          await FirebaseFirestore.instance
              .collection('products')
              .where('featured', isEqualTo: true)
              .limit(3)
              .get();

      // If no products explicitly marked as featured, use the top 3 newest products
      List<Map<String, dynamic>> featured = [];
      if (featuredQuery.docs.isEmpty) {
        final topProducts =
            await FirebaseFirestore.instance
                .collection('products')
                .orderBy('createdAt', descending: true)
                .limit(3)
                .get();

        featured =
            topProducts.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              data['id'] = doc.id; // Include document ID
              return data;
            }).toList();
      } else {
        featured =
            featuredQuery.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              data['id'] = doc.id; // Include document ID
              return data;
            }).toList();
      }

      // Fetch best sellers (products with highest soldCount)
      final bestSellersQuery =
          await FirebaseFirestore.instance
              .collection('products')
              .orderBy('soldCount', descending: true)
              .limit(6)
              .get();

      // If no products have soldCount or the result is empty,
      // fall back to newest products (same as featured but with more items)
      List<Map<String, dynamic>> bestSellers = [];
      if (bestSellersQuery.docs.isEmpty) {
        final newestProducts =
            await FirebaseFirestore.instance
                .collection('products')
                .orderBy('createdAt', descending: true)
                .limit(6)
                .get();

        bestSellers =
            newestProducts.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              data['id'] = doc.id; // Include document ID
              return data;
            }).toList();
      } else {
        bestSellers =
            bestSellersQuery.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              data['id'] = doc.id; // Include document ID
              return data;
            }).toList();
      }

      if (mounted) {
        setState(() {
          _products =
              querySnapshot.docs.map((doc) {
                Map<String, dynamic> data = doc.data();
                data['id'] = doc.id; // Include document ID
                return data;
              }).toList();

          _featuredProducts = featured;

          _bestSellerProducts = bestSellers; // Use the fallback data

          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _products = []; // Ensure lists are empty in case of an error
          _featuredProducts = [];
          _bestSellerProducts = [];
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

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        if (_hasMore) {
          setState(() {
            _limit += 10;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel(); // Cancel the timer when the widget is disposed
    _pageController.dispose(); // Dispose of the PageController
    _scrollController.dispose();
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
                    controller: _scrollController,
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
                                              '₱${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                                          productDescription:
                                              product['description'] ??
                                              'No description available',
                                          imageUrl: product['imageUrl'] ?? '',
                                          soldCount:
                                              product['soldCount']
                                                  ?.toString() ??
                                              '0',
                                          category:
                                              product['category'] ??
                                              'Unknown Category', // Pass category
                                          subcategory:
                                              product['subcategory'] ??
                                              'Unknown Subcategory', // Pass subcategory
                                        ),
                                  ),
                                );
                              },
                              child: _buildProductCard(
                                product['name'] ?? 'Unknown Product',
                                Icons.shopping_bag,
                                '₱${product['price']?.toStringAsFixed(2) ?? '0.00'}',
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured products section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Featured',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 200,
            child:
                _featuredProducts.isEmpty
                    ? Center(
                      child: Text(
                        'No featured products available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: _featuredProducts.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final product = _featuredProducts[index];
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
                                              '₱${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                                          productDescription:
                                              product['description'] ??
                                              'No description available',
                                          imageUrl: product['imageUrl'] ?? '',
                                          soldCount:
                                              product['soldCount']
                                                  ?.toString() ??
                                              '0',
                                          category:
                                              product['category'] ??
                                              'Unknown Category',
                                          subcategory:
                                              product['subcategory'] ??
                                              'Unknown Subcategory',
                                        ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: EdgeInsets.symmetric(horizontal: 8.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey[200],
                                ),
                                child: Stack(
                                  children: [
                                    if (product['imageUrl'] != null &&
                                        product['imageUrl'].isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(
                                          imageUrl: product['imageUrl'],
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          placeholder:
                                              (context, url) => Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Color(0xFFE47F43),
                                                    ),
                                              ),
                                          errorWidget:
                                              (context, url, error) => Icon(
                                                Icons.image,
                                                size: 60,
                                                color: Colors.grey,
                                              ),
                                        ),
                                      ),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.7),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'] ??
                                                'Unknown Product',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            '₱${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFE47F43),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Featured',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        if (_featuredProducts.length > 1)
                          Positioned(
                            left: 10,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: Icon(
                                Icons.chevron_left,
                                size: 40,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_pageController.hasClients) {
                                  final newPage =
                                      (_currentPage - 1) %
                                      _featuredProducts.length;
                                  setState(() {
                                    _currentPage =
                                        newPage < 0
                                            ? _featuredProducts.length - 1
                                            : newPage;
                                  });
                                  _pageController.animateToPage(
                                    _currentPage,
                                    duration: Duration(milliseconds: 500),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
                          ),
                        if (_featuredProducts.length > 1)
                          Positioned(
                            right: 10,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              icon: Icon(
                                Icons.chevron_right,
                                size: 40,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (_pageController.hasClients) {
                                  setState(() {
                                    _currentPage =
                                        (_currentPage + 1) %
                                        _featuredProducts.length;
                                  });
                                  _pageController.animateToPage(
                                    _currentPage,
                                    duration: Duration(milliseconds: 500),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
                          ),
                        if (_featuredProducts.length > 1)
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _featuredProducts.length,
                                (index) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    margin: EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          _currentPage == index
                                              ? Color(0xFFE47F43)
                                              : Colors.white.withOpacity(0.5),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
          ),

          // Best sellers section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Best Sellers',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_bestSellerProducts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No best-selling products available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
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
              itemCount: _bestSellerProducts.length,
              itemBuilder: (context, index) {
                final product = _bestSellerProducts[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ProductDetails(
                              productName: product['name'] ?? 'Unknown Product',
                              productPrice:
                                  '₱${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                              productDescription:
                                  product['description'] ??
                                  'No description available',
                              imageUrl: product['imageUrl'] ?? '',
                              soldCount:
                                  product['soldCount']?.toString() ?? '0',
                              category:
                                  product['category'] ?? 'Unknown Category',
                              subcategory:
                                  product['subcategory'] ??
                                  'Unknown Subcategory',
                            ),
                      ),
                    );
                  },
                  child: _buildProductCard(
                    product['name'] ?? 'Unknown Product',
                    Icons.shopping_bag,
                    '₱${product['price']?.toStringAsFixed(2) ?? '0.00'}',
                    'Sold: ${product['soldCount'] ?? '0'}',
                    product['imageUrl'] ?? '',
                  ),
                );
              },
            ),
        ],
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
                color: Colors.grey[200],
              ),
              child:
                  imageUrl.isNotEmpty
                      ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(10),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder:
                              (context, url) => Center(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFFE47F43),
                                  ),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              ),
                          memCacheWidth: 300, // Limit memory cache size
                        ),
                      )
                      : const Center(
                        child: Icon(Icons.image, size: 60, color: Colors.grey),
                      ),
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
}
