import 'package:flutter/material.dart';
import 'main.dart'; // Import the file where CartPage is defined
import 'search.dart';

class ProductDetails extends StatefulWidget {
  final String productName;
  final String productPrice;
  final String productDescription;
  final String imageUrl;
  final String soldCount;

  const ProductDetails({
    super.key,
    required this.productName,
    required this.productPrice,
    required this.productDescription,
    required this.imageUrl,
    required this.soldCount,
  });

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails>
    with SingleTickerProviderStateMixin {
  String selectedSize = '10x12';
  bool isFavorite = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color(0xFFE47F43),
          elevation: 0,
          title: Text(widget.productName),
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
                  Text(
                    widget.productName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.black,
                        ),
                        onPressed: () {
                          setState(() => isFavorite = !isFavorite);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Price
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Price: ${widget.productPrice}',
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFFE47F43),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Sold Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Sold: ${widget.soldCount}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),

            const Divider(thickness: 1, height: 32),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                "Product Description",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                widget.productDescription,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeOption(String size) {
    bool isSelected = selectedSize == size;

    return GestureDetector(
      onTap: () => setState(() => selectedSize = size),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE47F43) : Colors.grey[200],
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
            style: TextStyle(
              color: Color(0xFFE47F43),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
