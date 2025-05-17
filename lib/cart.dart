import 'package:flutter/material.dart';

class CartPage extends StatefulWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // Sample cart items
  final List<CartItem> _cartItems = [
    CartItem(
      id: '1',
      name: 'Pou Totebag',
      price: 637.28,
      quantity: 1,
      imageUrl: 'assets/images/pou_totebag.png',
    ),
    CartItem(
      id: '2',
      name: 'Pou Mug',
      price: 364.54,
      quantity: 1,
      imageUrl: 'assets/images/pou_mug.png',
    ),
    CartItem(
      id: '3',
      name: 'Pou Cap',
      price: 0.0, // Price not visible in the image
      quantity: 1,
      imageUrl: 'assets/images/pou_cap.png',
    ),
  ];

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQuantity = _cartItems[index].quantity + delta;
      if (newQuantity >= 1) {
        _cartItems[index].quantity = newQuantity;
      }
    });
  }

  double get _totalPrice {
    return _cartItems.fold(0, (total, item) => total + (item.price * item.quantity));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: const Color(0xFFD18050), // Orange color
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFFD18050),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'pou',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () {
              // Implement delete cart functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Cart title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: const Text(
              'My Cart',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Cart items list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Product image
                      Container(
                        width: 100,
                        height: 100,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                          ),
                        ),
                        child: _buildPlaceholderImage(item.name),
                      ),
                      
                      // Product details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'P${item.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Quantity controls
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        // Decrement button
                                        InkWell(
                                          onTap: () => _updateQuantity(index, -1),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.remove, size: 16),
                                          ),
                                        ),
                                        
                                        // Quantity
                                        Container(
                                          width: 30,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        
                                        // Increment button
                                        InkWell(
                                          onTap: () => _updateQuantity(index, 1),
                                          child: Container(
                                            width: 24,
                                            height: 24,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.add, size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Checkmark
                      Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: index == 2 ? Border.all(color: const Color(0xFFD18050)) : null,
                          color: index != 2 ? const Color(0xFFD18050) : Colors.transparent,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.check,
                          color: index != 2 ? Colors.white : const Color(0xFFD18050),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Total and checkout section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFD18050),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                // Total price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'P${_totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Checkout button
                ElevatedButton(
                  onPressed: () {
                    // Implement checkout functionality
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'CHECK OUT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Placeholder for product images since we don't have the actual assets
  Widget _buildPlaceholderImage(String itemName) {
    // This would normally be replaced with Image.asset() with the actual image path
    late IconData iconData;
    
    if (itemName.contains('Totebag')) {
      iconData = Icons.shopping_bag_outlined;
    } else if (itemName.contains('Mug')) {
      iconData = Icons.coffee_outlined;
    } else {
      iconData = Icons.face_outlined;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(iconData, size: 40, color: Colors.grey[700]),
    );
  }
}

// Model class for cart items
class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final String imageUrl;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });
}