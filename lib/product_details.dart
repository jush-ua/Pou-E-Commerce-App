import 'package:flutter/material.dart';

class ProductDetailsPage extends StatelessWidget {
  const ProductDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // App Bar
          Container(
            padding: const EdgeInsets.only(
              top: 40,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            color: const Color(0xFFD88144),
            child: Row(
              children: [
                const Icon(Icons.cloud, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'pou',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // Product Content - Scrollable
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image with Favorite Icon
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          height: 280,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/pou_bag.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 24,
                        right: 24,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () {},
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Product Name
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Pou Bag',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Product Description
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      'Baby got drip drip drip drip drip drip drip (Description lng to)',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),

                  // Availability with Icon
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'In-stock',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_box, color: Colors.green),
                          const Spacer(),
                          const Text(
                            'Pick up in store is available!',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Sizes Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sizes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buildSizeOption('8x10'),
                            buildSizeOption('10x12'),
                            buildSizeOption('12x14'),
                            buildSizeOption('14x16'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: Color(0xFFEEEEEE), thickness: 1),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Navigation Bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.home_outlined,
                    color: Color(0xFFD88144),
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.grey,
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline, color: Colors.grey),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Refactored _buildSizeOption as a standalone function
Widget buildSizeOption(String size) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(size, style: const TextStyle(fontWeight: FontWeight.w500)),
  );
}

class ProductDetails extends StatelessWidget {
  final String productName;
  final String productPrice;
  final IconData productIcon;
  final String soldCount;

  const ProductDetails({
    super.key,
    required this.productName,
    required this.productPrice,
    required this.productIcon,
    required this.soldCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(productName),
        backgroundColor: const Color(0xFFD88144),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Icon(productIcon, size: 100, color: Colors.brown)),
            const SizedBox(height: 16),
            Text(
              productName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Price: $productPrice',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Sold: $soldCount',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD88144),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
