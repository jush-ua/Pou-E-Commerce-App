import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'edit_product_page.dart';
import 'checkout_page.dart';
import 'cart.dart';

class ProductDetails extends StatefulWidget {
  final String productName;
  final String productPrice;
  final String productDescription;
  final String imageUrl;
  final String soldCount;
  final String category; // Add category
  final String subcategory; // Add subcategory

  const ProductDetails({
    super.key,
    required this.productName,
    required this.productPrice,
    required this.productDescription,
    required this.imageUrl,
    required this.soldCount,
    required this.category, // Add category
    required this.subcategory, // Add subcategory
  });

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  bool isFavorite = false;
  static const Color primaryColor = Color(0xFFD18050);
  String selectedSize = 'M';
  List<dynamic> _sizes = [];
  bool _hasMultipleSizes = false;
  String _sizeSystem = 'Metric (cm)';
  String? _selectedSize;
  bool _canWriteReview = false;
  bool _isSeller = false; // <-- Add this
  bool _hasReviewed = false; // Add this
  List<Map<String, dynamic>> _relatedProducts = [];
  bool _loadingRelated = true;
  String? _sellerName;
  String? _sellerId;
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = true;
  int _stock = 0; // <-- Add this line

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
    _fetchProductSizes();
    _checkIfCanWriteReview();
    _checkIfSeller();
    _fetchRelatedProducts();
    _checkIfAlreadyReviewed();
    _fetchSellerInfo(); // <-- Add this
    _fetchReviews(); // <-- Add this
  }

  Future<void> _checkIfFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('wishlist')
            .where('productName', isEqualTo: widget.productName)
            .limit(1)
            .get();
    setState(() {
      isFavorite = doc.docs.isNotEmpty;
    });
  }

  Future<void> _toggleWishlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please log in to use wishlist."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final wishlistRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('wishlist');
    final query =
        await wishlistRef
            .where('productName', isEqualTo: widget.productName)
            .limit(1)
            .get();

    if (isFavorite && query.docs.isNotEmpty) {
      // Remove from wishlist
      await wishlistRef.doc(query.docs.first.id).delete();
      setState(() => isFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Removed from wishlist."),
          backgroundColor: primaryColor,
        ),
      );
    } else if (!isFavorite) {
      // Add to wishlist
      await wishlistRef.add({
        'productName': widget.productName,
        'productPrice': widget.productPrice,
        'productDescription': widget.productDescription,
        'imageUrl': widget.imageUrl,
        'category': widget.category,
        'subcategory': widget.subcategory,
        'addedAt': FieldValue.serverTimestamp(),
      });
      setState(() => isFavorite = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Added to wishlist!"),
          backgroundColor: primaryColor,
        ),
      );
    }
  }

  // Add to Cart Function
  Future<void> _addToCart() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please log in to add items to your cart."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final cartCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart');

      // Use product name and size as a unique cart item ID (or use product ID if available)
      final cartItemId = '${widget.productName}_${_selectedSize ?? "One Size"}';

      // Before adding to cart, fetch the product's sellerId from Firestore
      final productSnap =
          await FirebaseFirestore.instance
              .collection('products')
              .where('name', isEqualTo: widget.productName)
              .limit(1)
              .get();

      String sellerId = '';
      if (productSnap.docs.isNotEmpty) {
        sellerId = productSnap.docs.first['sellerId'] ?? '';
      }

      await cartCollection.doc(cartItemId).set({
        'name': widget.productName,
        'price':
            widget.productPrice is double
                ? widget.productPrice
                : double.tryParse(
                      widget.productPrice.toString().replaceAll('₱', ''),
                    ) ??
                    0.0,
        'imageUrl': widget.imageUrl,
        'quantity': 1,
        'size': _selectedSize ?? "One Size",
        'category': widget.category,
        'subcategory': widget.subcategory,
        'addedAt': FieldValue.serverTimestamp(),
        'sellerId': sellerId,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Added to cart!"),
          backgroundColor: primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to add to cart: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchProductSizes() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('products')
            .where('name', isEqualTo: widget.productName)
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      int stock = 0;
      if ((data['hasMultipleSizes'] ?? false) && data['sizes'] != null) {
        for (var size in data['sizes']) {
          stock += (size['stock'] ?? 0) as int;
        }
      } else {
        stock = data['stock'] ?? 0;
      }
      setState(() {
        _sizes = data['sizes'] ?? [];
        _hasMultipleSizes = data['hasMultipleSizes'] ?? false;
        _sizeSystem = data['sizeSystem'] ?? 'Metric (cm)';
        _stock = stock; // <-- Set the stock here
        if (_hasMultipleSizes && _sizes.isNotEmpty) {
          final available = _sizes.where((s) => (s['stock'] ?? 0) > 0).toList();
          _selectedSize = available.isNotEmpty ? available.first['size'] : null;
        } else {
          _selectedSize = 'One Size';
        }
      });
    }
  }

  // Check if user has completed order for this product
  Future<void> _checkIfCanWriteReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final orders =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('orders')
            .where('status', isEqualTo: 'completed')
            .get();

    bool hasOrdered = false;
    for (final doc in orders.docs) {
      final items = (doc['items'] as List?) ?? [];
      if (items.any((item) => item['name'] == widget.productName)) {
        hasOrdered = true;
        break;
      }
    }
    setState(() {
      _canWriteReview = hasOrdered;
    });
  }

  Future<void> _checkIfSeller() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final sellerDoc =
        await FirebaseFirestore.instance
            .collection('sellers')
            .doc(user.uid)
            .get();
    setState(() {
      _isSeller = sellerDoc.exists;
    });
  }

  // Check if user already reviewed this product
  Future<void> _checkIfAlreadyReviewed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final productSnap =
        await FirebaseFirestore.instance
            .collection('products')
            .where('name', isEqualTo: widget.productName)
            .limit(1)
            .get();
    if (productSnap.docs.isNotEmpty) {
      final productId = productSnap.docs.first.id;
      final reviewSnap =
          await FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .collection('reviews')
              .where('userId', isEqualTo: user.uid)
              .limit(1)
              .get();
      setState(() {
        _hasReviewed = reviewSnap.docs.isNotEmpty;
      });
    }
  }

  // Fetch related products based on category and subcategory
  Future<void> _fetchRelatedProducts() async {
    setState(() {
      _loadingRelated = true;
    });

    try {
      print('Fetching related products for category: ${widget.category}');
      final snapshot =
          await FirebaseFirestore.instance
              .collection('products')
              .where('category', isEqualTo: widget.category)
              // .where('status', isEqualTo: 'active') // Uncomment only if all products have this
              .limit(10)
              .get();
      print('Found ${snapshot.docs.length} products in category');

      final List<Map<String, dynamic>> relatedProducts = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['name'] == widget.productName) continue;
        relatedProducts.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Product',
          'price': data['price']?.toString() ?? '0',
          'imageUrl': data['imageUrl'] ?? '',
          'category': data['category'] ?? '',
          'subcategory': data['subcategory'] ?? '',
          'description': data['description'] ?? '',
          'soldCount': data['soldCount']?.toString() ?? '0',
        });
        if (relatedProducts.length >= 5) break;
      }

      setState(() {
        _relatedProducts = relatedProducts;
        _loadingRelated = false;
      });
    } catch (e) {
      print('Error fetching related products: $e');
      setState(() {
        _loadingRelated = false;
      });
    }
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _loadingReviews = true;
    });
    try {
      final productSnap =
          await FirebaseFirestore.instance
              .collection('products')
              .where('name', isEqualTo: widget.productName)
              .limit(1)
              .get();
      if (productSnap.docs.isNotEmpty) {
        final productId = productSnap.docs.first.id;
        final reviewsSnap =
            await FirebaseFirestore.instance
                .collection('products')
                .doc(productId)
                .collection('reviews')
                .orderBy('createdAt', descending: true)
                .limit(10)
                .get();
        setState(() {
          _reviews = reviewsSnap.docs.map((doc) => doc.data()).toList();
          _loadingReviews = false;
        });
      } else {
        setState(() {
          _reviews = [];
          _loadingReviews = false;
        });
      }
    } catch (e) {
      setState(() {
        _reviews = [];
        _loadingReviews = false;
      });
    }
  }

  // Replace the old size selection UI with:
  Widget _buildSizesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          _hasMultipleSizes ? "Available Sizes ($_sizeSystem)" : "Size",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _hasMultipleSizes
            ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.from(
                (_sizes as List).map((sizeData) {
                  final String sizeName = sizeData['size']?.toString() ?? 'N/A';
                  final int stock = sizeData['stock'] ?? 0;
                  final bool isAvailable = stock > 0;
                  final String system = sizeData['system'] ?? _sizeSystem;
                  // Show unit if metric
                  final String displaySize =
                      system.contains('Metric')
                          ? "$sizeName ${system == 'Metric (cm)' ? 'cm' : 'mm'}"
                          : sizeName;

                  return ChoiceChip(
                    label: Text(displaySize),
                    selected: _selectedSize == sizeName,
                    onSelected:
                        isAvailable
                            ? (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedSize = sizeName;
                                }
                              });
                            }
                            : null,
                    backgroundColor: Colors.white,
                    selectedColor: primaryColor.withOpacity(0.3),
                    labelStyle: TextStyle(
                      color:
                          isAvailable
                              ? _selectedSize == sizeName
                                  ? primaryColor
                                  : Colors.black87
                              : Colors.grey,
                      fontWeight:
                          _selectedSize == sizeName
                              ? FontWeight.bold
                              : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color:
                            isAvailable
                                ? _selectedSize == sizeName
                                    ? primaryColor
                                    : Colors.grey.shade300
                                : Colors.grey.shade300,
                      ),
                    ),
                    disabledColor: Colors.grey.shade200,
                  );
                }),
              ),
            )
            : Text("One Size", style: TextStyle(color: Colors.black87)),
      ],
    );
  }

  Future<void> _showWriteReviewDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Prevent duplicate reviews
    final productSnap =
        await FirebaseFirestore.instance
            .collection('products')
            .where('name', isEqualTo: widget.productName)
            .limit(1)
            .get();
    if (productSnap.docs.isNotEmpty) {
      final productId = productSnap.docs.first.id;
      final reviewSnap =
          await FirebaseFirestore.instance
              .collection('products')
              .doc(productId)
              .collection('reviews')
              .where('userId', isEqualTo: user.uid)
              .limit(1)
              .get();
      if (reviewSnap.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already reviewed this product.'),
            backgroundColor: primaryColor,
          ),
        );
        return;
      }
    }

    double rating = 5;
    final reviewController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Write a Review'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your Rating:'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      rating = i + 1.0;
                      (context as Element).markNeedsBuild();
                    },
                  );
                }),
              ),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(
                  labelText: 'Your review',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reviewText = reviewController.text.trim();
                if (reviewText.isEmpty) return;
                if (productSnap.docs.isNotEmpty) {
                  final productId = productSnap.docs.first.id;
                  await FirebaseFirestore.instance
                      .collection('products')
                      .doc(productId)
                      .collection('reviews')
                      .add({
                        'userId': user.uid,
                        'userName': user.displayName ?? '',
                        'rating': rating,
                        'review': reviewText,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                }
                if (mounted) Navigator.pop(context);
                setState(() {
                  _hasReviewed = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Review submitted!'),
                    backgroundColor: primaryColor,
                  ),
                );
              },
              child: const Text('SUBMIT'),
            ),
          ],
        );
      },
    );
  }

  // Navigate to the product details page for a related product
  void _navigateToRelatedProduct(Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProductDetails(
              productName: product['name'],
              productPrice: product['price'],
              productDescription: product['description'],
              imageUrl: product['imageUrl'],
              soldCount: product['soldCount'],
              category: product['category'],
              subcategory: product['subcategory'],
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          title: Text(
            widget.productName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () {
                // Share functionality
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Product Image with Hero Animation
              Hero(
                tag: widget.productName,
                child: Container(
                  width: double.infinity,
                  height: 380,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child:
                        widget.imageUrl.isNotEmpty
                            ? Image.network(
                              widget.imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (
                                context,
                                child,
                                loadingProgress,
                              ) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: primaryColor,
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder:
                                  (context, error, stackTrace) => Container(
                                    color: Colors.grey[100],
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 80,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                            )
                            : Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                  ),
                ),
              ),

              // Enhanced Product Info Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Favorite Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.productName,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_sellerName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.storefront,
                                        size: 16,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _sellerName!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!_isSeller)
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  isFavorite
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    isFavorite ? Colors.red : Colors.grey[600],
                                size: 28,
                              ),
                              onPressed: _toggleWishlist,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Enhanced Category Tags
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildCategoryChip(widget.category, Icons.category),
                        _buildCategoryChip(widget.subcategory, Icons.label),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Enhanced Price Section
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Price",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${double.parse(widget.productPrice.replaceAll('₱', '')).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    size: 16,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.soldCount} sold',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Stock: $_stock',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Enhanced Size Selection
              if (_hasMultipleSizes || _selectedSize != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _buildEnhancedSizesSection(),
                ),

              const SizedBox(height: 20),

              // Enhanced Reviews Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Product Reviews",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                        ),
                        if (_canWriteReview && !_isSeller && !_hasReviewed)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.rate_review, size: 18),
                            label: const Text("Write Review"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _showWriteReviewDialog,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _loadingReviews
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(
                              color: primaryColor,
                            ),
                          ),
                        )
                        : _reviews.isEmpty
                        ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              "No reviews yet. Be the first to leave a review!",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                        : Column(
                          children:
                              _reviews.map((review) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.account_circle,
                                        size: 36,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  review['userName'] ?? 'User',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ...List.generate(
                                                  (review['rating'] ?? 5)
                                                      .round(),
                                                  (i) => const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              review['review'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (review['createdAt'] != null)
                                              Text(
                                                (review['createdAt']
                                                        as Timestamp)
                                                    .toDate()
                                                    .toString()
                                                    .split('.')[0],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Enhanced Description Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Product Description",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.productDescription,
                      style: const TextStyle(
                        color: Color(0xFF4A5568),
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Enhanced Related Products Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.recommend,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "You Might Also Like",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _loadingRelated
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(
                              color: primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                        : _relatedProducts.isEmpty
                        ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              "No related products found",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                        : SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _relatedProducts.length,
                            itemBuilder: (context, index) {
                              final product = _relatedProducts[index];
                              return _buildEnhancedRelatedProductItem(product);
                            },
                          ),
                        ),
                  ],
                ),
              ),

              const SizedBox(height: 100), // Space for bottom navigation
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildEnhancedBottomBar(),
    );
  }

  // Enhanced helper widgets
  Widget _buildCategoryChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSizesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.straighten, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              _hasMultipleSizes ? "Available Sizes ($_sizeSystem)" : "Size",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _hasMultipleSizes
            ? Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List<Widget>.from(
                (_sizes as List).map((sizeData) {
                  final String sizeName = sizeData['size']?.toString() ?? 'N/A';
                  final int stock = sizeData['stock'] ?? 0;
                  final bool isAvailable = stock > 0;
                  final String system = sizeData['system'] ?? _sizeSystem;
                  final String displaySize =
                      system.contains('Metric')
                          ? "$sizeName ${system == 'Metric (cm)' ? 'cm' : 'mm'}"
                          : sizeName;

                  return GestureDetector(
                    onTap:
                        isAvailable
                            ? () {
                              setState(() {
                                _selectedSize = sizeName;
                              });
                            }
                            : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _selectedSize == sizeName
                                ? primaryColor
                                : isAvailable
                                ? Colors.grey[100]
                                : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _selectedSize == sizeName
                                  ? primaryColor
                                  : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        displaySize,
                        style: TextStyle(
                          color:
                              _selectedSize == sizeName
                                  ? Colors.white
                                  : isAvailable
                                  ? Colors.black87
                                  : Colors.grey,
                          fontWeight:
                              _selectedSize == sizeName
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            )
            : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "One Size",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildEnhancedRelatedProductItem(Map<String, dynamic> product) {
    String formattedPrice = '';
    try {
      double price = double.parse(
        product['price'].toString().replaceAll('₱', ''),
      );
      formattedPrice = '₱${price.toStringAsFixed(2)}';
    } catch (e) {
      formattedPrice = '₱${product['price']}';
    }

    return GestureDetector(
      onTap: () => _navigateToRelatedProduct(product),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child:
                    product['imageUrl'] != null &&
                            product['imageUrl'].isNotEmpty
                        ? Image.network(
                          product['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                        )
                        : const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
              ),
            ),
            // Product details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Unknown Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF2D3748),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formattedPrice,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sold: ${product['soldCount']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              if (!_isSeller) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _addToCart,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Add to Cart',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _addToCart();
                      if (mounted) {
                        // Fetch the sellerId from Firestore if not already loaded
                        String sellerIdToPass = _sellerId ?? '';
                        if (sellerIdToPass.isEmpty) {
                          final productSnap =
                              await FirebaseFirestore.instance
                                  .collection('products')
                                  .where('name', isEqualTo: widget.productName)
                                  .limit(1)
                                  .get();
                          if (productSnap.docs.isNotEmpty) {
                            sellerIdToPass =
                                productSnap.docs.first['sellerId'] ?? '';
                          }
                        }
                        final cartItem = CartItem(
                          id:
                              '${widget.productName}_${_selectedSize ?? "One Size"}',
                          name: widget.productName,
                          price:
                              double.tryParse(
                                widget.productPrice.replaceAll('₱', ''),
                              ) ??
                              0.0,
                          imageUrl: widget.imageUrl,
                          quantity: 1,
                          sellerId: sellerIdToPass, // Pass the sellerId here
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => CheckoutPage(items: [cartItem]),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.flash_on, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Buy Now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_isSeller) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final productSnap =
                          await FirebaseFirestore.instance
                              .collection('products')
                              .where('name', isEqualTo: widget.productName)
                              .limit(1)
                              .get();
                      if (productSnap.docs.isNotEmpty) {
                        final productId = productSnap.docs.first.id;
                        final productData = productSnap.docs.first.data();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => EditProductPage(
                                  productId: productId,
                                  productData: productData,
                                ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.edit, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Edit Product',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeOption(String size) {
    bool isSelected = selectedSize == size;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSize = size;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          size,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Updated to display real related products
  Widget _buildRelatedProductItem(Map<String, dynamic> product) {
    // Format price correctly
    String formattedPrice = '';
    try {
      double price = double.parse(
        product['price'].toString().replaceAll('₱', ''),
      );
      formattedPrice = '₱${price.toStringAsFixed(2)}';
    } catch (e) {
      formattedPrice = '₱${product['price']}';
    }

    return GestureDetector(
      onTap: () => _navigateToRelatedProduct(product),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Container(
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
                image:
                    product['imageUrl'] != null &&
                            product['imageUrl'].isNotEmpty
                        ? DecorationImage(
                          image: NetworkImage(product['imageUrl']),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  product['imageUrl'] == null || product['imageUrl'].isEmpty
                      ? const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 40,
                        ),
                      )
                      : null,
            ),
            const SizedBox(height: 8),
            // Product name
            Text(
              product['name'] ?? 'Unknown Product',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF333333),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Product price
            Text(
              formattedPrice,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            // Sold count
            Text(
              'Sold: ${product['soldCount']}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchSellerInfo() async {
    // Get the product document to find sellerId
    final productSnap =
        await FirebaseFirestore.instance
            .collection('products')
            .where('name', isEqualTo: widget.productName)
            .limit(1)
            .get();
    if (productSnap.docs.isNotEmpty) {
      final data = productSnap.docs.first.data();
      final sellerId = data['sellerId'];
      if (sellerId != null && sellerId.toString().isNotEmpty) {
        final sellerDoc =
            await FirebaseFirestore.instance
                .collection('sellers')
                .doc(sellerId)
                .get();
        setState(() {
          _sellerId = sellerId;
          _sellerName =
              sellerDoc.exists
                  ? (sellerDoc.data()?['storeName'] ?? 'Unknown Seller')
                  : 'Unknown Seller';
        });
      }
    }
  }
}
