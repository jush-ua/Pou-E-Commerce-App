import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'cart.dart';
import 'addresses_page.dart';

class CheckoutPage extends StatefulWidget {
  final List<CartItem> items;

  const CheckoutPage({Key? key, required this.items}) : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  int _currentStep = 0;
  String? _selectedAddressId;
  Map<String, dynamic>? _selectedAddress;
  String? _selectedPaymentMethod;
  bool _isProcessing = false;

  final Color _primaryColor = const Color(0xFFD18050);
  final List<String> _paymentMethods = [
    'Credit Card',
    'GCash',
    'Cash on Delivery',
  ];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _fetchDefaultAddress();
  }

  Future<void> _fetchDefaultAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final addresses =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .orderBy('isDefault', descending: true)
            .get();
    if (addresses.docs.isNotEmpty) {
      setState(() {
        _selectedAddressId = addresses.docs.first.id;
        _selectedAddress = addresses.docs.first.data();
      });
    }
  }

  Future<void> _promptAddAddress() async {
    final result = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('No Saved Addresses'),
            content: const Text(
              'You have no saved addresses. Would you like to add one now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Address'),
              ),
            ],
          ),
    );
    if (result == true) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddressesPage()),
      );
      await _fetchDefaultAddress();
    }
  }

  Future<void> _processOrder() async {
    if (_currentStep != 2) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Create order ID
      final orderId = FirebaseFirestore.instance.collection('orders').doc().id;

      // Build order data
      final orderData = {
        'orderId': orderId,
        'buyerId': userId,
        'items':
            widget.items
                .map(
                  (item) => {
                    'id': item.id,
                    'name': item.name,
                    'price': item.price,
                    'quantity': item.quantity,
                    'imageUrl': item.imageUrl,
                    'sellerId': item.sellerId,
                  },
                )
                .toList(),
        'shippingAddress': _selectedAddress?['addressLine'] ?? '',
        'recipient': _selectedAddress?['name'] ?? '',
        'phoneNumber': _selectedAddress?['phone'] ?? '',
        'paymentMethod': _selectedPaymentMethod,
        'total': widget.items.fold(0.0, (t, i) => t + i.price * i.quantity),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      };

      // Save order for buyer
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('orders')
          .doc(orderId)
          .set(orderData);

      // Group items by seller
      final sellerGroups = <String, List<CartItem>>{};
      for (final item in widget.items) {
        sellerGroups.putIfAbsent(item.sellerId, () => []).add(item);
      }

      // Create a separate order for each seller
      for (final sellerId in sellerGroups.keys) {
        if (sellerId == null || sellerId.isEmpty) {
          debugPrint(
            'Invalid sellerId in cart item, skipping order creation for this seller.',
          );
          continue;
        }
        final sellerOrderId =
            FirebaseFirestore.instance.collection('orders').doc().id;
        final sellerItems = sellerGroups[sellerId]!;

        final sellerOrderData = {
          'orderId': sellerOrderId,
          'buyerId': userId,
          'items':
              sellerItems
                  .map(
                    (item) => {
                      'id': item.id,
                      'name': item.name,
                      'price': item.price,
                      'quantity': item.quantity,
                      'imageUrl': item.imageUrl,
                    },
                  )
                  .toList(),
          'shippingAddress': _selectedAddress?['addressLine'] ?? '',
          'recipient': _selectedAddress?['name'] ?? '',
          'phoneNumber': _selectedAddress?['phone'] ?? '',
          'paymentMethod': _selectedPaymentMethod,
          'total': sellerItems.fold(0.0, (t, i) => t + i.price * i.quantity),
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .collection('sales')
            .doc(sellerOrderId)
            .set(sellerOrderData);
      }

      // Remove items from cart
      for (final item in widget.items) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('cart')
            .doc(item.id)
            .delete();
      }

      // Order completed successfully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order placed! Paid via $_selectedPaymentMethod.'),
            backgroundColor: Colors.green,
          ),
        );

        // Return to previous page after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate success
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isProcessing = false;
          _currentStep = 2; // Go back to review step
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: SafeArea(
        child:
            _isProcessing ? _buildProcessingState() : _buildCheckoutStepper(),
      ),
      bottomNavigationBar:
          _isProcessing ? null : SafeArea(top: false, child: _buildBottomBar()),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _primaryColor),
          const SizedBox(height: 24),
          const Text(
            'Processing your order...',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment method: $_selectedPaymentMethod',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutStepper() {
    return Stepper(
      currentStep: _currentStep,
      onStepContinue: () async {
        if (_currentStep == 0) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          final addresses =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('addresses')
                  .get();
          if (addresses.docs.isEmpty) {
            await _promptAddAddress();
            return;
          }
          if (_selectedAddress == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select a shipping address'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } else if (_currentStep == 1) {
          if (_selectedPaymentMethod == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please select a payment method'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        } else if (_currentStep == 2) {
          _processOrder();
          return;
        }

        setState(() {
          _currentStep = (_currentStep + 1) % 3;
        });
      },
      onStepCancel: () {
        if (_currentStep > 0) {
          setState(() {
            _currentStep--;
          });
        }
      },
      steps: [
        Step(
          title: const Text('Shipping Information'),
          content: _buildAddressSelector(),
          isActive: _currentStep >= 0,
          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Payment Method'),
          content: Column(
            children:
                _paymentMethods
                    .map(
                      (method) => RadioListTile<String>(
                        title: Text(method),
                        value: method,
                        groupValue: _selectedPaymentMethod,
                        activeColor: _primaryColor,
                        onChanged:
                            (val) =>
                                setState(() => _selectedPaymentMethod = val),
                      ),
                    )
                    .toList(),
          ),
          isActive: _currentStep >= 1,
          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Review Order'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...widget.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            item.imageUrl.isNotEmpty
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: item.imageUrl,
                                    fit: BoxFit.cover,
                                    errorWidget:
                                        (_, __, ___) => Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Colors.grey[500],
                                        ),
                                  ),
                                )
                                : Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey[500],
                                ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '₱${item.price.toStringAsFixed(2)} × ${item.quantity}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₱${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              if (_selectedAddress != null)
                _buildInfoRow(
                  'Shipping Address:',
                  _selectedAddress!['addressLine'] ?? '',
                ),
              if (_selectedAddress != null)
                _buildInfoRow('Recipient:', _selectedAddress!['name'] ?? ''),
              if (_selectedAddress != null)
                _buildInfoRow('Phone:', _selectedAddress!['phone'] ?? ''),
              if (_selectedPaymentMethod != null)
                _buildInfoRow('Payment Method:', _selectedPaymentMethod!),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    '₱${widget.items.fold(0.0, (t, i) => t + i.price * i.quantity).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          isActive: _currentStep >= 2,
          state: StepState.indexed,
        ),
      ],
      controlsBuilder: (BuildContext context, ControlsDetails details) {
        return const SizedBox.shrink(); // Hide default controls, we use bottom bar
      },
    );
  }

  Widget _buildAddressSelector() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Text('Not logged in');
    }
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('addresses')
              .orderBy('isDefault', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Column(
            children: [
              const Text('No saved addresses.'),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Add Address'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddressesPage(),
                    ),
                  );
                  await _fetchDefaultAddress();
                },
              ),
            ],
          );
        }
        return Column(
          children: [
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return RadioListTile<String>(
                value: doc.id,
                groupValue: _selectedAddressId,
                activeColor: _primaryColor,
                title: Text(data['name'] ?? ''),
                subtitle: Text('${data['addressLine']}\n${data['phone']}'),
                isThreeLine: true,
                onChanged: (val) {
                  setState(() {
                    _selectedAddressId = val;
                    _selectedAddress = data;
                  });
                },
                secondary:
                    data['isDefault'] == true
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
              );
            }),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.edit_location_alt),
                label: const Text('Manage Addresses'),
                style: TextButton.styleFrom(foregroundColor: _primaryColor),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddressesPage(),
                    ),
                  );
                  await _fetchDefaultAddress();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final actionText = _currentStep == 2 ? 'PLACE ORDER' : 'CONTINUE';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
              },
              child: Text('BACK', style: TextStyle(color: _primaryColor)),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('CANCEL', style: TextStyle(color: Colors.grey[600])),
            ),
          ElevatedButton(
            onPressed: () {
              if (_currentStep == 0) {
                if (_selectedAddress == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a shipping address'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                setState(() {
                  _currentStep = 1;
                });
              } else if (_currentStep == 1) {
                if (_selectedPaymentMethod == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a payment method'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                setState(() {
                  _currentStep = 2;
                });
              } else if (_currentStep == 2) {
                _processOrder();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(actionText),
          ),
        ],
      ),
    );
  }
}
