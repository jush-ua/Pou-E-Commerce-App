import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
  final Color _primaryColor = const Color(0xFFD18050);

  // Track which items are selected for checkout
  final Set<String> _selectedCartItemIds = {};

  // Helper to update quantity in Firestore
  Future<void> _updateQuantity(String cartItemId, int newQuantity) async {
    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to access your cart')),
      );
      return;
    }

    if (_userId == null) return;
    if (newQuantity < 1) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cart')
        .doc(cartItemId)
        .update({'quantity': newQuantity});
  }

  // Helper to remove item from cart
  Future<void> _removeItem(String cartItemId) async {
    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to access your cart')),
      );
      return;
    }

    if (_userId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cart')
        .doc(cartItemId)
        .delete();
  }

  // Helper to clear the cart
  Future<void> _clearCart() async {
    // Check if user is authenticated
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to access your cart')),
      );
      return;
    }

    if (_userId == null) return;
    final items =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('cart')
            .get();
    for (var doc in items.docs) {
      await doc.reference.delete();
    }
  }

  double _calculateTotal(List<CartItem> items) {
    return items.fold(0, (total, item) => total + (item.price * item.quantity));
  }

  // Toggle selection for a cart item
  void _toggleCartItemSelection(String cartItemId) {
    setState(() {
      if (_selectedCartItemIds.contains(cartItemId)) {
        _selectedCartItemIds.remove(cartItemId);
      } else {
        _selectedCartItemIds.add(cartItemId);
      }
    });
  }

  // Calculate total for selected items only
  double _calculateSelectedTotal(List<CartItem> items) {
    return items
        .where((item) => _selectedCartItemIds.contains(item.id))
        .fold(0, (total, item) => total + (item.price * item.quantity));
  }

  // Checkout only selected items
  void _checkoutSelected(BuildContext context, List<CartItem> items) async {
    final selectedItems =
        items.where((item) => _selectedCartItemIds.contains(item.id)).toList();
    if (selectedItems.isEmpty) return;

    // Navigate to the separate checkout page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(items: selectedItems),
      ),
    );

    // If checkout was successful, clear selection
    if (result == true) {
      setState(() {
        _selectedCartItemIds.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return Scaffold(
        body: const Center(child: Text('Please log in to view your cart.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[200],
      // Remove the AppBar completely
      body: Column(
        children: [
          // Add a top navigation row instead of AppBar
          Container(
            padding: const EdgeInsets.only(
              top: 48,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title moved to the left for better balance
                const Text(
                  'My Cart',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                // Clear cart button
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Clear Cart'),
                            content: const Text(
                              'Are you sure you want to remove all items from your cart?',
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: const Text('CANCEL'),
                              ),
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                child: const Text(
                                  'CLEAR',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );

                    // Only clear if user confirmed
                    if (confirm == true) {
                      await _clearCart();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cart cleared successfully'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          // Remove the standalone cart title since it's now in the top row

          // Cart items list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(_userId)
                      .collection('cart')
                      .limit(20) // Limit items
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your cart is empty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final items =
                    snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return CartItem(
                        id: doc.id,
                        name: data['name'] ?? '',
                        price: (data['price'] ?? 0).toDouble(),
                        quantity: (data['quantity'] ?? 1) as int,
                        imageUrl: data['imageUrl'] ?? '',
                        sellerId: data['sellerId'] ?? '', // <-- Add this
                      );
                    }).toList();

                // Ensure all items are selected by default if none selected yet
                if (_selectedCartItemIds.isEmpty) {
                  for (final item in items) {
                    _selectedCartItemIds.add(item.id);
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedCartItemIds.contains(item.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          // Product image (no change)
                          Container(
                            width: 80,
                            height: 80,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                            child:
                                item.imageUrl.isNotEmpty
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: item.imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => const SizedBox(
                                              width: 30,
                                              height: 30,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFFD18050),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) =>
                                                _buildPlaceholderImage(
                                                  item.name,
                                                ),
                                        memCacheWidth: 300,
                                      ),
                                    )
                                    : _buildPlaceholderImage(item.name),
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
                                    '₱${(item.price * item.quantity).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // Quantity controls
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            InkWell(
                                              onTap:
                                                  () => _updateQuantity(
                                                    item.id,
                                                    item.quantity - 1,
                                                  ),
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.remove,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 30,
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${item.quantity}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap:
                                                  () => _updateQuantity(
                                                    item.id,
                                                    item.quantity + 1,
                                                  ),
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.add,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Remove button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        onPressed: () => _removeItem(item.id),
                                      ),

                                      // Spacer to push the checkbox to the right
                                      const Spacer(),

                                      // Check icon on the right side
                                      InkWell(
                                        splashColor: _primaryColor.withOpacity(
                                          0.3,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                        onTap: () {
                                          print(
                                            "Before: ${_selectedCartItemIds.contains(item.id)}",
                                          );
                                          setState(() {
                                            if (_selectedCartItemIds.contains(
                                              item.id,
                                            )) {
                                              _selectedCartItemIds.remove(
                                                item.id,
                                              );
                                            } else {
                                              _selectedCartItemIds.add(item.id);
                                            }
                                          });
                                          print(
                                            "After: ${_selectedCartItemIds.contains(item.id)}",
                                          );
                                        },
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                _selectedCartItemIds.contains(
                                                      item.id,
                                                    )
                                                    ? _primaryColor
                                                    : Colors.white,
                                            border: Border.all(
                                              color: _primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.check,
                                              color:
                                                  _selectedCartItemIds.contains(
                                                        item.id,
                                                      )
                                                      ? Colors.white
                                                      : _primaryColor,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Total and checkout section
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(_userId)
                    .collection('cart')
                    .snapshots(),
            builder: (context, snapshot) {
              final items =
                  snapshot.hasData
                      ? snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return CartItem(
                          id: doc.id,
                          name: data['name'] ?? '',
                          price: (data['price'] ?? 0).toDouble(),
                          quantity: (data['quantity'] ?? 1) as int,
                          imageUrl: data['imageUrl'] ?? '',
                          sellerId: data['sellerId'] ?? '', // <-- Add this
                        );
                      }).toList()
                      : <CartItem>[];
              final selectedTotal = _calculateSelectedTotal(items);

              return Container(
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
                          '₱${selectedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed:
                          _selectedCartItemIds.isEmpty
                              ? null
                              : () => _checkoutSelected(context, items),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'CHECK OUT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Placeholder for product images if imageUrl is empty or fails
  Widget _buildPlaceholderImage(String itemName) {
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
  final int quantity;
  final String imageUrl;
  final String sellerId; // <-- Add this

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.sellerId, // <-- Add this
  });
}
