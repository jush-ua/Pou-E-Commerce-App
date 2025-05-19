import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AddProductScreen extends StatefulWidget {
  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  File? _selectedImage;
  bool _isSubmitting = false;
  final Color primaryColor = const Color(0xFFD18050);

  // Category and Subcategory
  String? _selectedCategory;
  String? _selectedSubcategory;
  final Map<String, List<String>> _categories = {
    'Clothing': [
      'Shirts',
      'Pants',
      'Shoes',
      'Dresses',
      'Jackets',
      'Accessories',
    ],
    'Electronics': ['Phones', 'Laptops', 'Tablets', 'Cameras', 'Accessories'],
    'Home': ['Furniture', 'Decor', 'Appliances', 'Kitchenware', 'Bedding'],
    'Beauty & Personal Care': ['Skincare', 'Makeup', 'Haircare', 'Fragrances'],
    'Sports & Outdoors': [
      'Fitness Equipment',
      'Sportswear',
      'Camping Gear',
      'Bicycles',
    ],
    'Toys & Games': [
      'Action Figures',
      'Board Games',
      'Puzzles',
      'Outdoor Toys',
    ],
    'Books & Media': [
      'Fiction',
      'Non-Fiction',
      'Comics',
      'Magazines',
      'Music',
      'Movies',
    ],
    'Automotive': ['Car Accessories', 'Motorcycle Gear', 'Tools', 'Tires'],
    'Groceries': [
      'Fruits & Vegetables',
      'Snacks',
      'Beverages',
      'Dairy Products',
    ],
    'Health & Wellness': [
      'Supplements',
      'Medical Supplies',
      'Fitness Trackers',
    ],
    'Jewelry': ['Necklaces', 'Rings', 'Bracelets', 'Earrings', 'Watches'],
    'Pet Supplies': ['Pet Food', 'Toys', 'Grooming', 'Accessories'],
    'Baby Products': ['Clothing', 'Toys', 'Diapers', 'Feeding Supplies'],
    'Office Supplies': [
      'Stationery',
      'Printers',
      'Office Furniture',
      'Storage',
    ],
  };

  final ImagePicker _picker = ImagePicker();

  // Add these at the top with your other state variables
  bool _hasMultipleSizes = false;
  List<Map<String, dynamic>> _sizes = [];
  String _selectedSizeSystem = 'US';
  final List<String> _sizeSystemOptions = [
    'US',
    'EU',
    'UK',
    'Metric (cm)',
    'Metric (mm)',
    'Free Size',
  ];

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Choose Product Image",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64350F), // darkBrownColor
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    title: "Gallery",
                    onTap: () async {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.gallery);
                    },
                  ),
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    title: "Camera",
                    onTap: () async {
                      Navigator.pop(context);
                      _pickImageFromSource(ImageSource.camera);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 2),
            ),
            child: Icon(icon, color: primaryColor, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64350F), // darkBrownColor
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _requestImagePermissions() async {
    if (Platform.isAndroid) {
      final statuses =
          await [
            Permission.camera,
            Permission.photos,
            Permission.storage,
          ].request();
      return statuses.values.every((status) => status.isGranted);
    }
    return true;
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      // Handle permissions for Android
      if (Platform.isAndroid) {
        final deviceInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = deviceInfo.version.sdkInt;

        if (source == ImageSource.gallery) {
          PermissionStatus galleryStatus;
          if (sdkInt >= 33) {
            galleryStatus = await Permission.photos.status;
            if (galleryStatus.isDenied) {
              galleryStatus = await Permission.photos.request();
            }
          } else {
            galleryStatus = await Permission.storage.status;
            if (galleryStatus.isDenied) {
              galleryStatus = await Permission.storage.request();
            }
          }

          if (galleryStatus.isPermanentlyDenied) {
            if (!mounted) return;
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Permissions Required'),
                    content: const Text(
                      'Gallery access requires permission. Please enable it in app settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          openAppSettings();
                        },
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
            );
            return;
          }
        } else if (source == ImageSource.camera) {
          PermissionStatus cameraStatus = await Permission.camera.status;
          if (cameraStatus.isDenied) {
            cameraStatus = await Permission.camera.request();
          }

          if (cameraStatus.isPermanentlyDenied) {
            if (!mounted) return;
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Permissions Required'),
                    content: const Text(
                      'Camera access requires permission. Please enable it in app settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          openAppSettings();
                        },
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
            );
            return;
          }
        }
      }

      // Pick image
      final XFile? pickedImage = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedImage == null) return; // User cancelled

      // Set the selected image immediately
      final File initialFile = File(pickedImage.path);
      if (!await initialFile.exists()) {
        throw Exception('Image file not found');
      }

      setState(() {
        _selectedImage = initialFile;
      });

      // Compress the image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        initialFile.path,
        minWidth: 600,
        minHeight: 600,
        quality: 70,
      );

      if (compressedBytes != null && compressedBytes.isNotEmpty) {
        final tempDir = Directory.systemTemp;
        final compressedFile = File(
          '${tempDir.path}/product_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await compressedFile.writeAsBytes(compressedBytes);

        setState(() {
          _selectedImage = compressedFile;
        });
      } else {
        // If compression fails, use the original image
        setState(() {
          _selectedImage = initialFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
      }
    }
  }

  // Update the size section to allow "No size options" for products that don't have sizes
  Widget _buildSizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              "Product Sizes",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            DropdownButton<bool>(
              value: _hasMultipleSizes,
              underline: SizedBox(),
              items: const [
                DropdownMenuItem(value: false, child: Text("No Size Options")),
                DropdownMenuItem(value: true, child: Text("Has Size Options")),
              ],
              onChanged: (value) {
                setState(() {
                  _hasMultipleSizes = value ?? false;
                  if (_hasMultipleSizes && _sizes.isEmpty) {
                    _sizes.add({
                      'size': '',
                      'stock': 0,
                      'system': _selectedSizeSystem,
                    });
                  } else if (!_hasMultipleSizes) {
                    _sizes.clear();
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        _hasMultipleSizes
            ? Column(
              children: [
                // Size System Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedSizeSystem,
                  decoration: InputDecoration(
                    labelText: "Size System",
                    prefixIcon: const Icon(
                      Icons.straighten,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  items:
                      _sizeSystemOptions
                          .map(
                            (system) => DropdownMenuItem(
                              value: system,
                              child: Text(system),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSizeSystem = value!;
                      for (var size in _sizes) {
                        size['system'] = _selectedSizeSystem;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Size entries
                ..._sizes.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> sizeData = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        // Size name field
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: sizeData['size']?.toString() ?? '',
                            decoration: InputDecoration(
                              labelText:
                                  _selectedSizeSystem.contains('Metric')
                                      ? "Size (${_selectedSizeSystem == 'Metric (cm)' ? 'cm' : 'mm'})"
                                      : "Size",
                              hintText:
                                  _selectedCategory == 'Clothing'
                                      ? "e.g. 38, 40, 42"
                                      : _selectedCategory == 'Shoes'
                                      ? "e.g. 24, 25, 26"
                                      : "e.g. S, M, L, 42, 10...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _sizes[index]['size'] = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Stock for this size
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: sizeData['stock']?.toString() ?? '0',
                            decoration: InputDecoration(
                              labelText: "Stock",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                _sizes[index]['stock'] =
                                    int.tryParse(value) ?? 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Delete button
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                          ),
                          onPressed:
                              _sizes.length > 1
                                  ? () {
                                    setState(() {
                                      _sizes.removeAt(index);
                                    });
                                  }
                                  : null,
                        ),
                      ],
                    ),
                  );
                }).toList(),

                // Add size button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _sizes.add({
                        'size': '',
                        'stock': 0,
                        'system': _selectedSizeSystem,
                      });
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add Another Size"),
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                ),
              ],
            )
            : const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "No size options for this product",
                style: TextStyle(color: Colors.grey),
              ),
            ),
      ],
    );
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null) {
      _showErrorSnackBar('Please select a product image');
      return;
    }

    if (_selectedCategory == null || _selectedSubcategory == null) {
      _showErrorSnackBar('Please select a category and subcategory');
      return;
    }

    if (_hasMultipleSizes) {
      bool hasMissingSizeNames = _sizes.any(
        (size) =>
            size['size'] == null || size['size'].toString().trim().isEmpty,
      );
      if (hasMissingSizeNames) {
        _showErrorSnackBar('Please provide names for all sizes');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Step 1: Upload the image to Supabase
      final supabaseClient = Supabase.instance.client;
      final String fileName =
          'products/${DateTime.now().millisecondsSinceEpoch}_${_selectedImage!.path.split('/').last}';
      await supabaseClient.storage
          .from('product-images')
          .upload(fileName, _selectedImage!);

      // Get the public URL of the uploaded image
      final String imageUrl = supabaseClient.storage
          .from('product-images')
          .getPublicUrl(fileName);

      // Step 2: Save product details to Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('You must be logged in to add a product');
        return;
      }

      // Create product data with automatic fields
      final productData = {
        'sellerId': user.uid,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'imageUrl': imageUrl,
        'category': _selectedCategory,
        'subcategory': _selectedSubcategory,
        'createdAt': FieldValue.serverTimestamp(),
        'rating': 0,
        'totalReviews': 0,
        'featured': false,
        'soldCount': 0,
        'hasMultipleSizes': _hasMultipleSizes,
        'sizeSystem': _hasMultipleSizes ? _selectedSizeSystem : null,
      };

      if (_hasMultipleSizes) {
        productData['sizes'] = _sizes;
        productData['stock'] = _sizes.fold(
          0,
          (sum, size) => (sum as int) + ((size['stock'] ?? 0) as int),
        );
      } else {
        productData['stock'] = int.tryParse(_stockController.text) ?? 0;
        productData['sizes'] = []; // No size options
      }

      // Add product to the main 'products' collection
      final productRef = await FirebaseFirestore.instance
          .collection('products')
          .add(productData);

      // Add product to the seller's specific collection
      await FirebaseFirestore.instance
          .collection('sellers')
          .doc(user.uid)
          .collection('seller_products')
          .doc(productRef.id)
          .set(productData);

      _showSuccessSnackBar('Product added successfully!');

      Navigator.pop(context); // Go back to the previous screen
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        _showErrorSnackBar('You do not have permission to add a product.');
      } else {
        _showErrorSnackBar('Failed to add product: $e');
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add New Product',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          _isSubmitting
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    const Text("Adding your product..."),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    // Header with upload image section
                    Container(
                      width: double.infinity,
                      color: primaryColor.withOpacity(0.1),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            "Product Image",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 180,
                              width: 180,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                image:
                                    _selectedImage != null
                                        ? DecorationImage(
                                          image: FileImage(_selectedImage!),
                                          fit: BoxFit.cover,
                                        )
                                        : null,
                              ),
                              child:
                                  _selectedImage == null
                                      ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo,
                                            size: 40,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            "Add Product Photo",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      )
                                      : null,
                            ),
                          ),
                          if (_selectedImage != null)
                            TextButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text("Change Image"),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Form
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Product Details",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Product Name
                            _buildTextField(
                              controller: _nameController,
                              label: "Product Name",
                              prefixIcon: Icons.shopping_bag_outlined,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a product name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Price & Stock Row
                            Row(
                              children: [
                                // Price Field
                                Expanded(
                                  child: _buildTextField(
                                    controller: _priceController,
                                    label: "Price (₱)",
                                    prefixIcon:
                                        Icons
                                            .money, // Alternative to Icons.currency_peso
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      if (double.tryParse(value) == null) {
                                        return 'Invalid price';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Stock Field
                                Expanded(
                                  child: _buildTextField(
                                    controller: _stockController,
                                    label: "Stock Quantity",
                                    prefixIcon: Icons.inventory_2_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        if (int.tryParse(value) == null) {
                                          return 'Invalid number';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Category
                            _buildDropdownField(
                              value: _selectedCategory,
                              label: "Category",
                              prefixIcon: Icons.category_outlined,
                              items:
                                  _categories.keys
                                      .map(
                                        (category) => DropdownMenuItem(
                                          value: category,
                                          child: Text(category),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategory = value;
                                  _selectedSubcategory =
                                      null; // Reset subcategory
                                  // Default to metric for clothing, shoes, etc.
                                  if ([
                                    'Clothing',
                                    'Shoes',
                                    'Dresses',
                                    'Jackets',
                                  ].contains(value)) {
                                    _selectedSizeSystem = 'Metric (cm)';
                                  } else if (['Jewelry'].contains(value)) {
                                    _selectedSizeSystem = 'Metric (mm)';
                                  } else {
                                    _selectedSizeSystem = 'Free Size';
                                  }
                                  _sizes.clear();
                                  _hasMultipleSizes = false;
                                });
                              },
                              validator:
                                  (value) =>
                                      value == null
                                          ? 'Please select a category'
                                          : null,
                            ),
                            const SizedBox(height: 16),

                            // Subcategory
                            if (_selectedCategory != null)
                              _buildDropdownField(
                                value: _selectedSubcategory,
                                label: "Subcategory",
                                prefixIcon: Icons.bookmark_border,
                                items:
                                    _categories[_selectedCategory]!
                                        .map(
                                          (subcategory) => DropdownMenuItem(
                                            value: subcategory,
                                            child: Text(subcategory),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedSubcategory = value;
                                  });
                                },
                                validator:
                                    (value) =>
                                        value == null
                                            ? 'Please select a subcategory'
                                            : null,
                              ),

                            const SizedBox(height: 24),

                            // Description
                            const Text(
                              "Product Description",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: InputDecoration(
                                hintText: "Describe your product in detail...",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Colors.grey,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: primaryColor,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              maxLines: 5,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a product description';
                                }
                                return null;
                              },
                            ),

                            // Size section
                            _buildSizeSection(),

                            const SizedBox(height: 32),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _addProduct,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: const Text(
                                  'Add Product',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    IconData? prefixIcon,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }
}
