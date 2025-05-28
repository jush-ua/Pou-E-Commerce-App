import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class EditProductPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const EditProductPage({
    Key? key,
    required this.productId,
    required this.productData,
  }) : super(key: key);

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _description;
  late double _price;
  late int _stock;
  late String _category;
  String? _currentImageUrl;
  File? _newImageFile;
  bool _isLoading = false;
  final _picker = ImagePicker();

  // Theme colors
  final Color _primaryColor = const Color(0xFFE47F43);
  final Color _accentColor = const Color(0xFF2D3748);

  bool _hasMultipleSizes = false;
  List<Map<String, dynamic>> _sizes = [];
  String _selectedSizeSystem = 'Metric (cm)';
  final List<String> _sizeSystemOptions = [
    'Metric (cm)',
    'Metric (mm)',
    'US',
    'EU',
    'UK',
    'Free Size',
  ];

  @override
  void initState() {
    super.initState();
    _name = widget.productData['name'] ?? '';
    _description = widget.productData['description'] ?? '';
    _price = widget.productData['price'] ?? 0.0;
    _stock = widget.productData['stock'] ?? 0;
    _category = widget.productData['category'] ?? 'Other';
    _currentImageUrl = widget.productData['imageUrl'];
    _hasMultipleSizes = widget.productData['hasMultipleSizes'] ?? false;
    _selectedSizeSystem = widget.productData['sizeSystem'] ?? 'Metric (cm)';
    final sizesRaw = widget.productData['sizes'];
    if (sizesRaw is List) {
      _sizes = List<Map<String, dynamic>>.from(sizesRaw);
    }
  }

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

  // Helper for image source option
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
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _primaryColor, width: 2),
            ),
            child: Icon(icon, color: _primaryColor, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: _accentColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImage() async {
    if (_newImageFile == null) return _currentImageUrl;

    try {
      final fileName = path.basename(_newImageFile!.path);
      final destination = 'products/${widget.productId}/$fileName';

      final ref = FirebaseStorage.instance.ref().child(destination);
      await ref.putFile(_newImageFile!);

      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      return null;
    }
  }

  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus(); // <-- Add this line
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload new image if selected
      final imageUrl = await _uploadImage();

      // Update product data
      final updates = {
        'name': _name,
        'description': _description,
        'price': _price,
        'stock':
            _hasMultipleSizes
                ? _sizes.fold(
                  0,
                  (int sum, size) => sum + ((size['stock'] ?? 0) as int),
                )
                : _stock,
        'category': _category,
        'lastUpdated': FieldValue.serverTimestamp(),
        'hasMultipleSizes': _hasMultipleSizes,
        'sizeSystem': _hasMultipleSizes ? _selectedSizeSystem : null,
        'sizes': _hasMultipleSizes ? _sizes : [],
      };

      // Only update image URL if a new image was uploaded
      if (imageUrl != null) {
        updates['imageUrl'] = imageUrl;
      }

      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update(updates);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully!'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context, true); // Pass true to indicate successful update
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

        PermissionStatus galleryStatus;
        if (source == ImageSource.gallery) {
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
          if (galleryStatus.isDenied || galleryStatus.isRestricted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gallery access requires permission'),
              ),
            );
            return;
          }
        } else if (source == ImageSource.camera) {
          PermissionStatus cameraStatus = await Permission.camera.status;
          if (cameraStatus.isDenied) {
            cameraStatus = await Permission.camera.request();
          }
          cameraStatus = await Permission.camera.status;
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
          if (cameraStatus.isDenied || cameraStatus.isRestricted) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Camera permission is required')),
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
        _newImageFile = initialFile;
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
          _newImageFile = compressedFile;
        });
      } else {
        // If compression fails, use the original image
        setState(() {
          _newImageFile = initialFile;
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
                      borderSide: BorderSide(color: _primaryColor, width: 2),
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
                ..._sizes.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> sizeData = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
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
                                  _category == 'Clothing'
                                      ? "e.g. 38, 40, 42"
                                      : _category == 'Shoes'
                                      ? "e.g. 24, 25, 26"
                                      : "e.g. S, M, L, 42, 10...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: _primaryColor,
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
                                  color: _primaryColor,
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
                  style: TextButton.styleFrom(foregroundColor: _primaryColor),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        backgroundColor: _primaryColor,
        elevation: 0,
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: _primaryColor))
              : SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      color: _primaryColor.withOpacity(0.1),
                      child: Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 3,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child:
                                      _newImageFile != null
                                          ? Image.file(
                                            _newImageFile!,
                                            fit: BoxFit.cover,
                                          )
                                          : _currentImageUrl != null
                                          ? Image.network(
                                            _currentImageUrl!,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (
                                              context,
                                              child,
                                              progress,
                                            ) {
                                              if (progress == null)
                                                return child;
                                              return Center(
                                                child: CircularProgressIndicator(
                                                  color: _primaryColor,
                                                  value:
                                                      progress.expectedTotalBytes !=
                                                              null
                                                          ? progress
                                                                  .cumulativeBytesLoaded /
                                                              progress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                ),
                                              );
                                            },
                                          )
                                          : Icon(
                                            Icons.image,
                                            size: 100,
                                            color: _accentColor.withOpacity(
                                              0.5,
                                            ),
                                          ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFormSection('Product Details'),
                            TextFormField(
                              initialValue: _name,
                              decoration: _buildInputDecoration('Product Name'),
                              onSaved: (value) => _name = value ?? '',
                              validator:
                                  (value) =>
                                      value!.isEmpty
                                          ? 'Name is required'
                                          : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _description,
                              decoration: _buildInputDecoration('Description'),
                              maxLines: 3,
                              onSaved: (value) => _description = value ?? '',
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _category,
                              decoration: _buildInputDecoration('Category'),
                              items:
                                  [
                                        'Clothing',
                                        'Electronics',
                                        'Home',
                                        'Beauty',
                                        'Sports',
                                        'Other',
                                      ]
                                      .map(
                                        (category) => DropdownMenuItem(
                                          value: category,
                                          child: Text(category),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _category = value ?? 'Other';
                                });
                              },
                              onSaved: (value) => _category = value ?? 'Other',
                            ),
                            const SizedBox(height: 24),
                            _buildFormSection('Pricing & Inventory'),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _price.toString(),
                                    decoration: InputDecoration(
                                      labelText:
                                          'Price (₱)', // Update to Philippine Peso symbol
                                      prefixIcon: const Icon(
                                        Icons.money,
                                      ), // Alternative to Icons.currency_peso
                                      labelStyle: TextStyle(
                                        color: _accentColor.withOpacity(0.7),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: _accentColor.withOpacity(0.2),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: _primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: _accentColor.withOpacity(0.2),
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onSaved:
                                        (value) =>
                                            _price =
                                                double.tryParse(value ?? '0') ??
                                                0.0,
                                    validator:
                                        (value) =>
                                            double.tryParse(value ?? '') == null
                                                ? 'Enter a valid price'
                                                : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _stock.toString(),
                                    decoration: _buildInputDecoration('Stock'),
                                    keyboardType: TextInputType.number,
                                    onSaved:
                                        (value) =>
                                            _stock =
                                                int.tryParse(value ?? '0') ?? 0,
                                    validator:
                                        (value) =>
                                            int.tryParse(value ?? '') == null
                                                ? 'Enter a valid number'
                                                : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: _saveChanges,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            _buildSizeSection(), // Add size section to the form
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildFormSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _accentColor,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: _accentColor.withOpacity(0.2)),
        const SizedBox(height: 16),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _accentColor.withOpacity(0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _accentColor.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _accentColor.withOpacity(0.2)),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
