import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
    _fetchProductSizes();
    _checkIfCanWriteReview();
    _checkIfSeller(); // <-- Add this
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
      setState(() {
        _sizes = data['sizes'] ?? [];
        _hasMultipleSizes = data['hasMultipleSizes'] ?? false;
        _sizeSystem = data['sizeSystem'] ?? 'Metric (cm)';
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
                await FirebaseFirestore.instance
                    .collection('products')
                    .where('name', isEqualTo: widget.productName)
                    .limit(1)
                    .get()
                    .then((snapshot) async {
                      if (snapshot.docs.isNotEmpty) {
                        final productId = snapshot.docs.first.id;
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
                    });
                if (mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: primaryColor,
          elevation: 0,
          title: Row(
            children: [
              Text(
                widget.productName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                ),
                onPressed: () {
                  // Navigate to cart
                },
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Container(
              width: double.infinity,
              height: 350,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
                image:
                    widget.imageUrl.isNotEmpty
                        ? DecorationImage(
                          image: NetworkImage(widget.imageUrl),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  widget.imageUrl.isEmpty
                      ? const Center(
                        child: Icon(Icons.image, size: 100, color: Colors.grey),
                      )
                      : null,
            ),

            // Title + Favorite
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.productName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (!_isSeller)
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.black,
                            size: 28,
                          ),
                          onPressed: _toggleWishlist,
                        ),
                      IconButton(
                        icon: const Icon(Icons.share, size: 24),
                        onPressed: () {
                          // Share functionality
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Category and Subcategory
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    "Category: ",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Text(
                    widget.category,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    "Subcategory: ",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Text(
                    widget.subcategory,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Price",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    '₱${double.parse(widget.productPrice.replaceAll('₱', '')).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),

            // Sold Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Sold: ${widget.soldCount}',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),

            // Size Selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: _buildSizesSection(),
            ),

            const Divider(thickness: 1, height: 32),

            // Product Reviews Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    "Product Reviews",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const Spacer(),
                  if (_canWriteReview && !_isSeller)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.rate_review, size: 18),
                      label: const Text("Write Review"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _showWriteReviewDialog,
                    ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () {
                      // Navigate to reviews page
                    },
                  ),
                ],
              ),
            ),

            // Reviews Placeholder
            Container(
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: Text(
                  "No reviews yet. Be the first to leave a review!",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),

            const Divider(thickness: 1, height: 32),

            // Description with icon for better visual hierarchy
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF333333),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Product Description",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                widget.productDescription,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // You Might Also Like section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "You Might Also Like",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        5,
                        (index) => _buildRecommendationItem(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (!_isSeller) ...[
              // Chat with seller button removed
              const SizedBox(width: 0), // Optionally keep spacing
              Expanded(
                child: OutlinedButton(
                  onPressed: _addToCart,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Buy now logic: add to cart, then go to checkout
                    await _addToCart();
                    if (mounted) {
                      // Create a CartItem for this product
                      final cartItem = CartItem(
                        id: '${widget.productName}_${_selectedSize ?? "One Size"}',
                        name: widget.productName,
                        price:
                            double.tryParse(
                              widget.productPrice.replaceAll('₱', ''),
                            ) ??
                            0.0,
                        imageUrl: widget.imageUrl,
                        quantity: 1,
                        sellerId:
                            '', // You may want to fetch the sellerId if needed
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutPage(items: [cartItem]),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Buy Now',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            if (_isSeller) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // Navigate to edit product page
                    // Fetch productId from Firestore
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
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Product not found."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Edit Product',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
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

  Widget _buildRecommendationItem() {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Related Product",
            style: TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const Text(
            "\$14.99",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
