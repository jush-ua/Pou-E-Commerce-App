import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final user = FirebaseAuth.instance.currentUser;
  final Color _primaryColor = const Color(0xFFE47F43);
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Addresses'),
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Please log in to manage your addresses')),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('addresses')
            .orderBy('isDefault', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data?.docs ?? [];
          
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No saved addresses',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a new address to use during checkout',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddressDialog(context, null, null),
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('ADD NEW ADDRESS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }
          
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length + 1, // +1 for the header
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Your Saved Addresses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      );
                    }
                    
                    final docIndex = index - 1;
                    final doc = docs[docIndex];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: data['isDefault'] == true
                              ? BorderSide(color: _primaryColor, width: 2)
                              : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['name'] ?? 'Unnamed Address',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (data['isDefault'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _primaryColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'DEFAULT',
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                data['phone'] ?? '',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                data['addressLine'] ?? '',
                                style: TextStyle(color: Colors.grey[800]),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (data['isDefault'] != true)
                                    TextButton.icon(
                                      onPressed: () async {
                                        setState(() {
                                          _isLoading = true;
                                        });
                                        
                                        try {
                                          // Unset previous default
                                          final prevDefaults = await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(user!.uid)
                                              .collection('addresses')
                                              .where('isDefault', isEqualTo: true)
                                              .get();
                                          
                                          for (final prevDoc in prevDefaults.docs) {
                                            await prevDoc.reference.update({'isDefault': false});
                                          }
                                          
                                          // Set this as default
                                          await doc.reference.update({'isDefault': true});
                                          
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Default address updated'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        } finally {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.check_circle_outline, size: 16),
                                      label: const Text('Set as Default'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: _primaryColor,
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _showAddressDialog(context, doc.id, data),
                                    color: Colors.grey[700],
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _confirmDelete(context, doc.id, data),
                                    color: Colors.red[700],
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddressDialog(context, null, null),
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add_location_alt),
      ),
    );
  }

  void _showAddressDialog(BuildContext context, String? id, Map<String, dynamic>? data) {
    final nameController = TextEditingController(text: data?['name'] ?? '');
    final phoneController = TextEditingController(text: data?['phone'] ?? '');
    final addressController = TextEditingController(text: data?['addressLine'] ?? '');
    bool isDefault = data?['isDefault'] ?? (id == null);  // Default to true for new addresses
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          id == null ? 'Add New Address' : 'Edit Address',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: 'Complete Address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.home_outlined),
                        hintText: 'Street, Building, City, Region, Postal Code',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: isDefault,
                      onChanged: (val) => setState(() => isDefault = val ?? false),
                      title: const Text(
                        'Set as default shipping address',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text('This will be selected by default at checkout'),
                      activeColor: _primaryColor,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          // Validate inputs
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a name'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          
                          if (phoneController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a phone number'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          
                          if (addressController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an address'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          
                          final addressData = {
                            'name': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'addressLine': addressController.text.trim(),
                            'isDefault': isDefault,
                            'updatedAt': FieldValue.serverTimestamp(),
                          };
                          
                          try {
                            final ref = FirebaseFirestore.instance
                                .collection('users')
                                .doc(user!.uid)
                                .collection('addresses');
                                
                            if (isDefault) {
                              // Unset previous default
                              final prevDefaults = await ref
                                  .where('isDefault', isEqualTo: true)
                                  .get();
                                  
                              for (final doc in prevDefaults.docs) {
                                if (id != null && doc.id == id) continue;
                                await doc.reference.update({'isDefault': false});
                              }
                            }
                            
                            if (id == null) {
                              // Add creation timestamp for new addresses
                              addressData['createdAt'] = FieldValue.serverTimestamp();
                              await ref.add(addressData);
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Address added successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              await ref.doc(id).update(addressData);
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Address updated successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                            
                            if (mounted) Navigator.pop(context);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: Text(id == null ? 'ADD ADDRESS' : 'SAVE CHANGES'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this address?'),
            const SizedBox(height: 16),
            Text(
              data['name'] ?? 'Unnamed Address',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(data['addressLine'] ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('addresses')
                    .doc(id)
                    .delete();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address deleted'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting address: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}