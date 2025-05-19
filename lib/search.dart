import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_details.dart'; // Import the product details screen

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
      final snapshot =
          await FirebaseFirestore.instance
              .collection('products')
              .limit(100)
              .get();

      List<Map<String, dynamic>> results =
          snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return {
                  'id': doc.id,
                  'name': data['name'] ?? '',
                  'description': data['description'] ?? '',
                  'price': (data['price'] ?? 0).toDouble(),
                  'originalPrice':
                      (data['originalPrice'] ?? data['price'] ?? 0).toDouble(),
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
                final description =
                    product['description'].toString().toLowerCase();

                // Apply text search
                bool matchesSearch =
                    name.contains(query) || description.contains(query);

                // Apply category filter
                bool matchesCategory =
                    _selectedCategory == 'All' ||
                    product['category'] == _selectedCategory;

                // Apply price range filter
                bool matchesPriceRange =
                    product['price'] >= _priceRange.start &&
                    product['price'] <= _priceRange.end;

                // Apply discount filter
                bool matchesDiscount =
                    !_showOnlyDiscounted ||
                    (product['discountPercentage'] != null &&
                        product['discountPercentage'] > 0);

                return matchesSearch &&
                    matchesCategory &&
                    matchesPriceRange &&
                    matchesDiscount;
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
            return (b['createdAt'] as Timestamp).compareTo(
              a['createdAt'] as Timestamp,
            );
          case 'Popularity':
            return b['popularity'].compareTo(a['popularity']);
          case 'Relevance':
          default:
            // For relevance, prioritize products with query in the name
            final aNameContains = a['name'].toString().toLowerCase().contains(
              query,
            );
            final bNameContains = b['name'].toString().toLowerCase().contains(
              query,
            );
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
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
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Replace the remaining fixed content with a scrollable list
                  Expanded(
                    child: ListView(
                      children: [
                        const Text(
                          'Price Range',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        RangeSlider(
                          values: _priceRange,
                          min: 0,
                          max: 10000,
                          divisions: 100,
                          labels: RangeLabels(
                            '₱${_priceRange.start.round()}',
                            '₱${_priceRange.end.round()}',
                          ),
                          onChanged: (RangeValues values) {
                            setModalState(() {
                              _priceRange = values;
                            });
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('₱${_priceRange.start.round()}'),
                              Text('₱${_priceRange.end.round()}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Category',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children:
                              _categories.map((category) {
                                return ChoiceChip(
                                  label: Text(category),
                                  selected: _selectedCategory == category,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      _selectedCategory =
                                          selected ? category : 'All';
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sort By',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children:
                              _sortOptions.map((option) {
                                return ChoiceChip(
                                  label: Text(option),
                                  selected: _sortBy == option,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      _sortBy = selected ? option : 'Relevance';
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Show only discounted items'),
                          value: _showOnlyDiscounted,
                          onChanged: (value) {
                            setModalState(() {
                              _showOnlyDiscounted = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // Keep the Apply button at the bottom
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
      backgroundColor: Colors.grey[50], // Lighter background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[600],
                          size: 18,
                        ),
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
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Active filters row with improved styling
          if (_selectedCategory != 'All' ||
              _priceRange.start > 0 ||
              _priceRange.end < 10000 ||
              _sortBy != 'Relevance' ||
              _showOnlyDiscounted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text(
                      'Filters: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    if (_selectedCategory != 'All')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          label: Text(
                            'Category: $_selectedCategory',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          deleteIconColor: Theme.of(context).primaryColor,
                          onDeleted: () {
                            setState(() {
                              _selectedCategory = 'All';
                              _performSearch();
                            });
                          },
                        ),
                      ),
                    if (_priceRange.start > 0 || _priceRange.end < 10000)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            'Price: ₱${_priceRange.start.round()} - ₱${_priceRange.end.round()}',
                          ),
                          onDeleted: () {
                            setState(() {
                              _priceRange = const RangeValues(0, 10000);
                              _performSearch();
                            });
                          },
                        ),
                      ),
                    if (_sortBy != 'Relevance')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('Sort: $_sortBy'),
                          onDeleted: () {
                            setState(() {
                              _sortBy = 'Relevance';
                              _performSearch();
                            });
                          },
                        ),
                      ),
                    if (_showOnlyDiscounted)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: const Text('Discounted Only'),
                          onDeleted: () {
                            setState(() {
                              _showOnlyDiscounted = false;
                              _performSearch();
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Search results
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Finding products...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                    : _searchResults.isEmpty
                    ? _searchController.text.isEmpty
                        ? _buildEmptySearchState()
                        : _buildNoResultsState()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  // Improved empty search state
  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search, size: 60, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          const Text(
            'Search for products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Type in the search bar to find products you\'re looking for',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  // Improved no results state
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off, size: 60, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          Text(
            'No results for "${_searchController.text}"',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Try a different search term or adjust your filters',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filters'),
            onPressed: () {
              setState(() {
                _priceRange = const RangeValues(0, 10000);
                _selectedCategory = 'All';
                _sortBy = 'Relevance';
                _showOnlyDiscounted = false;
                _performSearch();
              });
            },
          ),
        ],
      ),
    );
  }

  // Enhanced product grid
  Widget _buildSearchResults() {
    return Column(
      children: [
        // Results count bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          alignment: Alignment.centerLeft,
          child: Text(
            '${_searchResults.length} results found',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final product = _searchResults[index];
              final hasDiscount =
                  product['discountPercentage'] != null &&
                  product['discountPercentage'] > 0;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ProductDetails(
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
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stack for product image and discount badge
                      Stack(
                        children: [
                          SizedBox(
                            height: 140,
                            width: double.infinity,
                            child:
                                product['imageUrl'] != ''
                                    ? CachedNetworkImage(
                                      imageUrl: product['imageUrl'],
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => Container(
                                            color: Colors.grey[200],
                                          ),
                                      errorWidget:
                                          (context, url, error) => Container(
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              size: 40,
                                            ),
                                          ),
                                    )
                                    : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image, size: 40),
                                    ),
                          ),
                          if (hasDiscount)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
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

                      // Product details
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['category'],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 4),

                              Text(
                                product['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const Spacer(),

                              // Price section
                              Row(
                                children: [
                                  Text(
                                    '₱${product['price']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          hasDiscount
                                              ? Colors.red[700]
                                              : Theme.of(context).primaryColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (hasDiscount &&
                                      product['originalPrice'] != null)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Text(
                                          '₱${product['originalPrice']}',
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // Rating and sold count
                              Row(
                                children: [
                                  if (product['rating'] != null) ...[
                                    Icon(
                                      Icons.star,
                                      size: 12,
                                      color: Colors.amber[700],
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${product['rating'].toStringAsFixed(1)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const Text(
                                      ' • ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: Text(
                                      product['soldCount'] != null
                                          ? '${product['soldCount']} sold'
                                          : 'New',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
