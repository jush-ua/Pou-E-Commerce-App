import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_product_screen.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSeller = false;
  bool _isLoading = true;
  String _storeName = "";
  Map<String, dynamic>? _sellerData;

  // Dashboard statistics
  int _totalProducts = 0;
  int _totalOrders = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _checkIfSeller();
  }

  Future<void> _checkIfSeller() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      final sellerDoc =
          await FirebaseFirestore.instance
              .collection('sellers')
              .doc(user.uid)
              .get();

      if (sellerDoc.exists) {
        final data = sellerDoc.data();
        setState(() {
          _isSeller = true;
          _sellerData = data;
          _storeName = data?['storeName'] ?? 'My Store';
        });

        // Fetch dashboard data
        await _fetchDashboardData(user.uid);
      } else {
        setState(() {
          _isSeller = false;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to verify seller status: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDashboardData(String sellerId) async {
    try {
      // Get total products count
      final productsQuery =
          await FirebaseFirestore.instance
              .collection('products')
              .where('sellerId', isEqualTo: sellerId)
              .get();

      // Get orders for this seller
      final ordersQuery =
          await FirebaseFirestore.instance
              .collection('orders')
              .where('sellerId', isEqualTo: sellerId)
              .get();

      double revenue = 0.0;
      for (var order in ordersQuery.docs) {
        revenue += (order.data()['totalAmount'] ?? 0.0);
      }

      setState(() {
        _totalProducts = productsQuery.docs.length;
        _totalOrders = ordersQuery.docs.length;
        _totalRevenue = revenue;
      });
    } catch (e) {
      _showSnackBar('Failed to load dashboard data: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddProductScreen()),
    );
  }

  void _navigateToManageOrders() {
    // TODO: Navigate to manage orders screen
    _showSnackBar('Manage Orders functionality coming soon');
  }

  void _navigateToManageProducts() {
    // TODO: Navigate to manage products screen
    _showSnackBar('Manage Products functionality coming soon');
  }

  void _navigateToStoreSettings() {
    // TODO: Navigate to store settings screen
    _showSnackBar('Store Settings functionality coming soon');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isSeller) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'You are not authorized to access the Seller Dashboard.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                  ); // Navigate back to the previous screen
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('$_storeName Dashboard'),
        backgroundColor: const Color(0xFFE47F43),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToStoreSettings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _checkIfSeller();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store information card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey.shade200,
                            child: Text(
                              _storeName.isNotEmpty
                                  ? _storeName[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _storeName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _sellerData?['email'] ?? 'No email provided',
                                  style: TextStyle(color: Colors.grey.shade700),
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

              const SizedBox(height: 20),

              // Stats cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Products',
                      _totalProducts.toString(),
                      Icons.inventory,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Orders',
                      _totalOrders.toString(),
                      Icons.shopping_bag,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Revenue',
                      '\$${_totalRevenue.toStringAsFixed(2)}',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Action buttons
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    'Add Product',
                    Icons.add_circle,
                    Colors.green,
                    _navigateToAddProduct, // Calls the updated method
                  ),
                  _buildActionButton(
                    'Manage Products',
                    Icons.inventory_2,
                    Colors.blue,
                    _navigateToManageProducts,
                  ),
                  _buildActionButton(
                    'Orders',
                    Icons.shopping_cart,
                    Colors.orange,
                    _navigateToManageOrders,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent activity section
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Card(
                child:
                    _totalOrders > 0
                        ? const ListTile(
                          title: Text('Recent orders will appear here'),
                          subtitle: Text('Implement order listing here'),
                        )
                        : const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No recent orders found'),
                        ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE47F43),
        onPressed: _navigateToAddProduct, // Calls the updated method
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            backgroundColor: color,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  Future<void> _addProduct() async {
    final picker = ImagePicker();
    try {
      // Step 1: Pick an image
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        _showSnackBar('No image selected');
        return;
      }

      final File imageFile = File(pickedFile.path);

      // Step 2: Upload the image to Supabase
      final supabaseClient = Supabase.instance.client;
      final String fileName =
          'products/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
      await supabaseClient.storage
          .from('product-images') // Ensure this matches your bucket name
          .upload(fileName, imageFile);

      // Get the public URL of the uploaded image
      final String imageUrl = supabaseClient.storage
          .from('product-images')
          .getPublicUrl(fileName);

      // Proceed with saving product details to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      final productData = {
        'sellerId': user.uid, // Add the sellerId
        'name': 'Sample Product', // Replace with actual product name
        'description': 'Sample Description', // Replace with actual description
        'price': 19.99, // Replace with actual price
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Add product to the main 'products' collection
      final productRef = await FirebaseFirestore.instance
          .collection('products')
          .add(productData);

      // Add product to the seller's specific collection
      await FirebaseFirestore.instance
          .collection('sellers')
          .doc(user.uid)
          .collection('seller_products')
          .doc(
            productRef.id,
          ) // Use the same document ID as in the 'products' collection
          .set(productData);

      _showSnackBar('Product added successfully!');
    } catch (e) {
      // Handle upload or Firestore errors
      _showSnackBar('Failed to add product: $e');
    }
  }
}
