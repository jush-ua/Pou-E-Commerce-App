import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestSellerPage extends StatefulWidget {
  const RequestSellerPage({super.key});

  @override
  State<RequestSellerPage> createState() => _RequestSellerPageState();
}

class _RequestSellerPageState extends State<RequestSellerPage> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnackBar('You must be logged in to submit a request.');
        setState(() => _isSubmitting = false);
        return;
      }

      // Add the request to the Firestore collection
      await FirebaseFirestore.instance
          .collection('seller_requests')
          .doc(user.uid) // Use the user's UID as the document ID
          .set({
            'storeName': _storeNameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'email': user.email,
            'status': 'pending',
            'userId': user.uid,
            'requestedAt': FieldValue.serverTimestamp(),
          });

      _showSnackBar('Request submitted successfully!');
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Failed to submit request: $e');
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryColor = Color(0xFFE47F43);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Seller'),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section with info message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.store, color: primaryColor),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Fill out the form below to apply for a seller account. '
                            'We\'ll review your application and get back to you soon.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Store name field
                  _buildSectionTitle('Store Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _storeNameController,
                    decoration: _inputDecoration(
                      hintText: 'Enter your store name',
                      prefixIcon: Icons.storefront,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Store name is required';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Description field
                  _buildSectionTitle('Description'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: _inputDecoration(
                      hintText:
                          'Tell us about your store and what you plan to sell',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Description is required';
                      }
                      if (value.trim().length < 20) {
                        return 'Description should be at least 20 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 32),

                  // Submit button
                  Center(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                      child:
                          _isSubmitting
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                'Submit Application',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Terms notice
                  Center(
                    child: Text(
                      'By submitting, you agree to our seller terms and policies',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon:
          prefixIcon != null ? Icon(prefixIcon, color: Colors.grey) : null,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE47F43), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
