import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_product_screen.dart';
import 'manage_products_page.dart';
import 'manage_orders_page.dart';

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

  // Theme colors
  final Color _primaryColor = const Color(0xFFE47F43);
  final Color _accentColor = const Color(0xFF2D3748);

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
        final data = order.data();
        if (data['status'] == 'COMPLETED') {
          // Use totalAmount if available, otherwise fallback to total
          num? amount = data['totalAmount'] ?? data['total'];
          if (amount is num) {
            revenue += amount.toDouble();
          }
        }
      }

      setState(() {
        _totalProducts = productsQuery.docs.length;
        _totalOrders = ordersQuery.docs.length;
        _totalRevenue = revenue;
      });
    } catch (e) {
      print('Error loading dashboard data: $e'); // Log detailed error
      _showSnackBar('Failed to load dashboard data. Please check permissions.');

      // Set defaults if data loading fails
      setState(() {
        _totalProducts = 0;
        _totalOrders = 0;
        _totalRevenue = 0.0;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: _accentColor),
    );
  }

  void _navigateTo(String destination) {
    switch (destination) {
      case 'addProduct':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddProductScreen()),
        );
        break;
      case 'manageProducts':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ManageProductsPage()),
        );
        break;
      case 'manageOrders':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ManageOrdersPage(
                  sellerId: FirebaseAuth.instance.currentUser!.uid,
                  primaryColor: _primaryColor,
                  accentColor: _accentColor,
                ),
          ),
        );
        break;
      case 'storeSettings':
        _showSnackBar('Store Settings functionality coming soon');
        break;
      case 'orderDetails':
        _showSnackBar('Order details functionality coming soon');
        break;
      default:
        _showSnackBar('Navigation not implemented');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    if (!_isSeller) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store_mall_directory, size: 64, color: _accentColor),
                const SizedBox(height: 24),
                const Text(
                  'You are not authorized to access the Seller Dashboard.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Go Back', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('$_storeName Dashboard'),
        backgroundColor: _primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateTo('storeSettings'),
            tooltip: 'Store Settings',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _checkIfSeller,
        color: _primaryColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStoreInfoCard(),
              const SizedBox(height: 20),
              _buildStatCardsRow(),
              const SizedBox(height: 24),
              _buildQuickActionsSection(),
              _buildTopProductsSection(),
              const SizedBox(height: 16),
              _buildRecentActivitySection(),
              const SizedBox(height: 24),
              // Add monthly sales chart here if you want
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        onPressed: () => _navigateTo('addProduct'),
        tooltip: 'Add New Product',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStoreInfoCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      _storeName.isNotEmpty ? _storeName[0].toUpperCase() : 'S',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
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
                      const SizedBox(height: 4),
                      Text(
                        _sellerData?['email'] ?? 'No email provided',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Seller since: ${_sellerData?['createdAt']?.toDate().toString().split(' ')[0] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
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
    );
  }

  Widget _buildStatCardsRow() {
    return Row(
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
            '₱${_totalRevenue.toStringAsFixed(2)}', // Changed $ to ₱
            Icons.payments_outlined, // Changed icon to better represent money
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 16.0),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _accentColor,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              'Add Product',
              Icons.add_circle,
              Colors.green,
              () => _navigateTo('addProduct'),
            ),
            _buildActionButton(
              'Manage Products',
              Icons.inventory_2,
              Colors.blue,
              () => _navigateTo('manageProducts'),
            ),
            _buildActionButton(
              'Orders',
              Icons.shopping_cart,
              Colors.orange,
              () => _navigateTo('manageOrders'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
              TextButton(
                onPressed: () => _navigateTo('manageOrders'),
                child: Text('See All', style: TextStyle(color: _primaryColor)),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('orders')
                  .where(
                    'sellerId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .orderBy('createdAt', descending: true)
                  .limit(3)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading orders: ${snapshot.error}'),
              );
            }

            final orders = snapshot.data?.docs ?? [];

            if (orders.isEmpty) {
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.grey, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No recent orders found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your recent orders will appear here',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final orderData =
                      orders[index].data() as Map<String, dynamic>;
                  final orderId = orders[index].id;
                  final createdAt =
                      orderData['createdAt'] as Timestamp? ?? Timestamp.now();
                  final total = orderData['total'] ?? 0;
                  final status = orderData['status'] ?? 'Processing';

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: _primaryColor,
                      ),
                    ),
                    title: Text('Order #${orderId.substring(0, 6)}'),
                    subtitle: Text(
                      '${createdAt.toDate().toString().split(' ')[0]} • ₱${total is num ? total.toStringAsFixed(2) : '0.00'}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () => _navigateTo('orderDetails'),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'TO SHIP':
        return Colors.orange;
      case 'TO RECEIVE':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTopProductsSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 16.0, top: 32.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Products',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _accentColor,
                ),
              ),
              TextButton(
                onPressed: () => _navigateTo('manageProducts'),
                child: Text('See All', style: TextStyle(color: _primaryColor)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('products')
                    .where('sellerId', isEqualTo: user.uid)
                    .orderBy('sold', descending: true)
                    .limit(5)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading products'));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'No products yet. Add your first product!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(right: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                data['imageUrl'] != null &&
                                        data['imageUrl'].toString().isNotEmpty
                                    ? Image.network(
                                      data['imageUrl'],
                                      height: 80,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          height: 80,
                                          color: Colors.grey.withOpacity(0.2),
                                          child: Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    )
                                    : Container(
                                      height: 80,
                                      color: Colors.grey.withOpacity(0.2),
                                      child: Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                      ),
                                    ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['name'] ?? 'Product Name',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₱${(data['price'] is num) ? (data['price'] as num).toStringAsFixed(2) : data['price'] ?? '0.00'}',
                            style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                '${data['sold'] ?? 0} sold',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
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
        Material(
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
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
