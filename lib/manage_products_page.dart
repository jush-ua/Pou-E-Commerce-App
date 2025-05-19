import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_product_page.dart';

class ManageProductsPage extends StatefulWidget {
  const ManageProductsPage({Key? key}) : super(key: key);

  @override
  State<ManageProductsPage> createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _allProducts = [];

  // Theme colors
  final Color _primaryColor = const Color(0xFFE47F43);
  final Color _accentColor = const Color(0xFF2D3748);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _allProducts = await _fetchSellerProducts();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading products: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSellerProducts() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }

    final querySnapshot =
        await FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isEqualTo: user.uid)
            .get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Product deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadProducts(); // Refresh the product list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteProduct(String productId, String productName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Product'),
            content: Text('Are you sure you want to delete "$productName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: _accentColor)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteProduct(productId);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _editProduct(String productId, Map<String, dynamic> productData) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                EditProductPage(productId: productId, productData: productData),
      ),
    );

    if (result == true) {
      _loadProducts(); // Refresh if product was updated
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _allProducts.where((product) {
      // Apply category filter
      if (_selectedCategory != 'All' &&
          product['category'] != _selectedCategory) {
        return false;
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final name = product['name']?.toString().toLowerCase() ?? '';
        final description =
            product['description']?.toString().toLowerCase() ?? '';
        final searchLower = _searchQuery.toLowerCase();

        return name.contains(searchLower) || description.contains(searchLower);
      }

      return true;
    }).toList();
  }

  List<String> get _availableCategories {
    final categories =
        _allProducts
            .map((p) => p['category']?.toString() ?? 'Other')
            .toSet()
            .toList();

    return ['All', ...categories];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        backgroundColor: _primaryColor,
        elevation: 0,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : Column(
                children: [
                  _buildFilterBar(),
                  Expanded(
                    child:
                        _filteredProducts.isEmpty
                            ? _buildEmptyState()
                            : _buildProductsGrid(),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add product page
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Product feature coming soon')),
          );
        },
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: _primaryColor.withOpacity(0.1),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _availableCategories
                      .map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = category;
                                });
                              }
                            },
                            selectedColor: _primaryColor,
                            labelStyle: TextStyle(
                              color:
                                  _selectedCategory == category
                                      ? Colors.white
                                      : _accentColor,
                              fontWeight:
                                  _selectedCategory == category
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 80,
            color: _accentColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty || _selectedCategory != 'All'
                ? 'No products match your filters'
                : 'You haven\'t added any products yet',
            style: TextStyle(
              fontSize: 18,
              color: _accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isNotEmpty || _selectedCategory != 'All')
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'All';
                });
              },
              child: Text(
                'Clear filters',
                style: TextStyle(color: _primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: _primaryColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editProduct(product['id'], product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image - fixed height
            Stack(
              alignment: Alignment.topRight,
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: product['imageUrl'] != null
                      ? Image.network(
                          product['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.broken_image),
                          ),
                        )
                      : Container(
                          color: _accentColor.withOpacity(0.1),
                          child: Icon(
                            Icons.image_not_supported,
                            size: 40,
                            color: _accentColor.withOpacity(0.5),
                          ),
                        ),
                ),
                // Category badge
                if (product['category'] != null)
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      product['category'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            // Product info - fill remaining space to avoid overflow
            Flexible(
              fit: FlexFit.loose,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product['name'] ?? 'Unnamed Product',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _accentColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stock: ${product['stock'] ?? 0}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _accentColor.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₱${product['price'].toStringAsFixed(2)}',
                          style: TextStyle(
                            color: _accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _editProduct(product['id'], product),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _confirmDeleteProduct(
                                product['id'],
                                product['name'] ?? 'this product',
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
