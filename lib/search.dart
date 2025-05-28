import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_details.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  // Filter states
  RangeValues _priceRange = const RangeValues(0, 10000);
  String _selectedCategory = 'All';
  String _sortBy = 'Relevance';
  bool _showOnlyDiscounted = false;

  // Theme colors
  final Color _primaryColor = const Color(0xFFE47F43);

  // Available filter options
  final List<String> _categories = [
    'All',
    'Electronics',
    'Clothing',
    'Home',
    'Beauty',
  ];
  final List<String> _sortOptions = [
    'Relevance',
    'Price: Low to High',
    'Price: High to Low',
    'Newest First',
    'Popularity',
  ];

  Future<void> _performSearch() async {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .limit(100)
          .get();

      List<Map<String, dynamic>> results = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'description': data['description'] ?? '',
              'price': (data['price'] ?? 0).toDouble(),
              'originalPrice': (data['originalPrice'] ?? data['price'] ?? 0).toDouble(),
              'imageUrl': data['imageUrl'] ?? '',
              'category': data['category'] ?? 'Other',
              'discountPercentage': data['discountPercentage'] ?? 0,
              'rating': (data['rating'] ?? 0.0).toDouble(),
              'createdAt': data['createdAt'] ?? Timestamp.now(),
              'popularity': data['soldCount'] ?? 0,
            };
          })
          .where((product) {
            final name = product['name'].toString().toLowerCase();
            final description = product['description'].toString().toLowerCase();

            // Apply filters
            bool matchesSearch = name.contains(query) || description.contains(query);
            bool matchesCategory = _selectedCategory == 'All' || product['category'] == _selectedCategory;
            bool matchesPriceRange = product['price'] >= _priceRange.start && product['price'] <= _priceRange.end;
            bool matchesDiscount = !_showOnlyDiscounted || (product['discountPercentage'] != null && product['discountPercentage'] > 0);

            return matchesSearch && matchesCategory && matchesPriceRange && matchesDiscount;
          })
          .toList();

      // Apply sorting
      results.sort((a, b) {
        switch (_sortBy) {
          case 'Price: Low to High':
            return a['price'].compareTo(b['price']);
          case 'Price: High to Low':
            return b['price'].compareTo(a['price']);
          case 'Newest First':
            return (b['createdAt'] as Timestamp).compareTo(a['createdAt'] as Timestamp);
          case 'Popularity':
            return b['popularity'].compareTo(a['popularity']);
          case 'Relevance':
          default:
            final aNameContains = a['name'].toString().toLowerCase().contains(query);
            final bNameContains = b['name'].toString().toLowerCase().contains(query);
            if (aNameContains && !bNameContains) return -1;
            if (!aNameContains && bNameContains) return 1;
            return 0;
        }
      });

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: ${e.toString()}')),
      );
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _priceRange = const RangeValues(0, 10000);
                            _selectedCategory = 'All';
                            _sortBy = 'Relevance';
                            _showOnlyDiscounted = false;
                          });
                        },
                        child: Text('Reset', style: TextStyle(color: _primaryColor)),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        // Price Range
                        const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        RangeSlider(
                          values: _priceRange,
                          min: 0,
                          max: 10000,
                          divisions: 100,
                          activeColor: _primaryColor,
                          labels: RangeLabels('₱${_priceRange.start.round()}', '₱${_priceRange.end.round()}'),
                          onChanged: (RangeValues values) {
                            setModalState(() {
                              _priceRange = values;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Category
                        const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _categories.map((category) {
                            return ChoiceChip(
                              label: Text(category),
                              selected: _selectedCategory == category,
                              selectedColor: _primaryColor.withOpacity(0.2),
                              onSelected: (selected) {
                                setModalState(() {
                                  _selectedCategory = selected ? category : 'All';
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        
                        // Sort By
                        const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _sortOptions.map((option) {
                            return ChoiceChip(
                              label: Text(option),
                              selected: _sortBy == option,
                              selectedColor: _primaryColor.withOpacity(0.2),
                              onSelected: (selected) {
                                setModalState(() {
                                  _sortBy = selected ? option : 'Relevance';
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                        
                        // Discount Filter
                        SwitchListTile(
                          title: const Text('Show only discounted items'),
                          value: _showOnlyDiscounted,
                          activeColor: _primaryColor,
                          onChanged: (value) {
                            setModalState(() {
                              _showOnlyDiscounted = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _performSearch();
                      },
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search for products...',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _performSearch(),
            onChanged: (value) {
              if (value.isEmpty) {
                setState(() {
                  _searchResults = [];
                });
              }
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: _primaryColor),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: _primaryColor),
            )
          : _searchResults.isEmpty
              ? _buildEmptyState()
              : _buildSearchResults(),
    );
  }

  Widget _buildEmptyState() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search for products',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Find what you\'re looking for',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or filters',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSearchResults() {
    return Column(
      children: [
        // Results count
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
          child: Text(
            '${_searchResults.length} results found',
            style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final product = _searchResults[index];
              final hasDiscount = product['discountPercentage'] != null && product['discountPercentage'] > 0;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetails(
                        productName: product['name'] ?? '',
                        productPrice: product['price'].toString(),
                        productDescription: product['description'] ?? '',
                        imageUrl: product['imageUrl'] ?? '',
                        soldCount: (product['soldCount'] ?? 0).toString(),
                        category: product['category'] ?? '',
                        subcategory: product['subcategory'] ?? '',
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image
                      Stack(
                        children: [
                          Container(
                            height: 140,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: product['imageUrl'] != ''
                                  ? CachedNetworkImage(
                                      imageUrl: product['imageUrl'],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: CircularProgressIndicator(color: _primaryColor),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.image, size: 40),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image, size: 40),
                                    ),
                            ),
                          ),
                          if (hasDiscount)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '-${product['discountPercentage'].round()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      // Product Details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Text(
                                '₱${product['price'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                  fontSize: 16,
                                ),
                              ),
                              if (hasDiscount && product['originalPrice'] != null)
                                Text(
                                  '₱${product['originalPrice'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
