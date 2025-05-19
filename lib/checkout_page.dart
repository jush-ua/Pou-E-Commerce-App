import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'cart.dart';

class CheckoutPage extends StatefulWidget {
  final List<CartItem> items;

  const CheckoutPage({Key? key, required this.items}) : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  int _currentStep = 0;
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
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
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
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
        'shippingAddress': _addressController.text,
        'phoneNumber': _phoneController.text,
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
          'shippingAddress': _addressController.text,
          'phoneNumber': _phoneController.text,
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
      ),
      body: _isProcessing ? _buildProcessingState() : _buildCheckoutStepper(),
      bottomNavigationBar: _isProcessing ? null : _buildBottomBar(),
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
      onStepContinue: () {
        if (_currentStep == 0) {
          if (_formKey.currentState?.validate() != true) return;
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
          content: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Shipping Address',
                    hintText: 'Enter your complete address',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your shipping address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter your contact number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
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
              if (_addressController.text.isNotEmpty)
                _buildInfoRow('Shipping Address:', _addressController.text),
              if (_phoneController.text.isNotEmpty)
                _buildInfoRow('Phone:', _phoneController.text),
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
                if (_formKey.currentState?.validate() != true) return;
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
