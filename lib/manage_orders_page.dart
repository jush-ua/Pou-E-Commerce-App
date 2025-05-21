import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageOrdersPage extends StatefulWidget {
  final String sellerId;
  final Color primaryColor;
  final Color accentColor;

  const ManageOrdersPage({
    super.key,
    required this.sellerId,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  State<ManageOrdersPage> createState() => _ManageOrdersPageState();
}

class _ManageOrdersPageState extends State<ManageOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    'Pending',
    'To Ship',
    'To Receive',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders Management'),
        backgroundColor: widget.primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList('pending'),
          _buildOrdersList('to ship'),
          _buildOrdersList('to receive'),
          _buildOrdersList('completed'),
          _buildOrdersList('cancelled'),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('orders')
              .where('sellerId', isEqualTo: widget.sellerId)
              .where('status', isEqualTo: status)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading orders: ${snapshot.error}'));
        }

        final orders = snapshot.data?.docs ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No ${status.replaceAll('_', ' ')} orders',
                  style: TextStyle(color: Colors.grey[600], fontSize: 18),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final order = doc.data() as Map<String, dynamic>;

              if (status == 'pending') {
                return _buildPendingOrderCard(doc);
              } else {
                return _buildOrderCard(doc, order, status);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(
    DocumentSnapshot doc,
    Map<String, dynamic> order,
    String status,
  ) {
    final formattedDate =
        order['createdAt'] != null
            ? DateFormat('MMM dd, yyyy').format((order['createdAt'] as Timestamp).toDate())
            : 'N/A';

    final nextAction =
        status == 'to ship'
            ? 'Mark as Shipped'
            : status == 'to receive'
            ? 'Mark as Delivered'
            : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order ID and status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${order['orderId'] ?? doc.id.substring(0, 6)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),

            // Customer and date info - Make this wrap when needed
            Wrap(
              spacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(formattedDate, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        order['buyerName'] ?? 'Customer',
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // Order total
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total (${order['itemCount'] ?? 1} ${(order['itemCount'] ?? 1) > 1 ? 'items' : 'item'})',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '₱${order['total']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: widget.accentColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons - stacked vertically to prevent overflow
            if (nextAction != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => _updateOrderStatus(doc, status),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(nextAction),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showOrderDetails(doc, order),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.accentColor,
                      side: BorderSide(color: widget.accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: () => _showOrderDetails(doc, order),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.accentColor,
                  side: BorderSide(color: widget.accentColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    String displayStatus = status.toUpperCase();

    switch (status.toLowerCase()) {
      case 'pending':
        badgeColor = Colors.amber;
        break;
      case 'to ship':
        badgeColor = Colors.orange;
        displayStatus = 'TO SHIP';
        break;
      case 'to receive':
        badgeColor = Colors.blue;
        displayStatus = 'TO RECEIVE';
        break;
      case 'completed':
        badgeColor = Colors.green;
        break;
      case 'cancelled':
        badgeColor = Colors.red;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showOrderDetails(DocumentSnapshot doc, Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${order['orderId'] ?? doc.id.substring(0, 6)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildDetailSection('Delivery Information', [
                      'Customer: ${order['buyerName'] ?? 'N/A'}',
                      'Address: ${order['address'] ?? 'N/A'}',
                      'Phone: ${order['phone'] ?? 'N/A'}',
                    ]),

                    const SizedBox(height: 24),

                    _buildDetailSection('Order Information', [
                      'Date: ${order['createdAt'] != null ? DateFormat('MMM dd, yyyy').format((order['createdAt'] as Timestamp).toDate()) : 'N/A'}',
                      'Status: ${order['status']?.toString().toUpperCase() ?? 'N/A'}',
                      'Payment Method: ${order['paymentMethod'] ?? 'N/A'}',
                    ]),

                    const SizedBox(height: 24),

                    // Order Items
                    const Text(
                      'Order Items',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (order['items'] != null) ...[
                      for (var item in (order['items'] as List))
                        _buildOrderItem(item),
                    ] else
                      const Text('No item details available'),

                    const Divider(height: 32),

                    // Order summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text(
                          '₱${order['subtotal']?.toStringAsFixed(2) ?? '0.00'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Shipping Fee'),
                        Text(
                          '₱${order['shippingFee']?.toStringAsFixed(2) ?? '0.00'}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '₱${order['total']?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: widget.accentColor,
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
    );
  }

  Widget _buildDetailSection(String title, List<String> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...details.map(
          (detail) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(detail),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(dynamic item) {
    if (item is! Map) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item['imageUrl'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item['imageUrl'],
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    ),
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              color: Colors.grey[200],
              child: const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Product',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '₱${item['price']?.toString() ?? '0.00'} × ${item['quantity']?.toString() ?? '1'}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '₱${(item['price'] != null && item['quantity'] != null) ? (item['price'] * item['quantity']).toStringAsFixed(2) : '0.00'}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _updateOrderStatus(DocumentSnapshot doc, String currentStatus) async {
    String newStatus;
    switch (currentStatus.toLowerCase()) {
      case 'to ship':
        newStatus = 'to receive';
        break;
      case 'to receive':
        newStatus = 'completed';
        break;
      default:
        return;
    }

    try {
      final order = doc.data() as Map<String, dynamic>;

      // Update order in the main collection
      await doc.reference.update({'status': newStatus});
      if (order['buyerId'] != null && order['orderId'] != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(order['buyerId'])
            .collection('orders')
            .doc(order['orderId'])
            .update({'status': newStatus});
      }
      if (order['sellerId'] != null && order['orderId'] != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(order['sellerId'])
            .collection('sales')
            .doc(order['orderId'])
            .update({'status': newStatus});
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Switch to the appropriate tab
      if (mounted) {
        int tabIndex = 0;
        switch (newStatus) {
          case 'to receive':
            tabIndex = 2;
            break;
          case 'completed':
            tabIndex = 3;
            break;
        }
        _tabController.animateTo(tabIndex);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPendingOrderCard(DocumentSnapshot orderDoc) {
    final order = orderDoc.data() as Map<String, dynamic>;
    final formattedDate =
        order['createdAt'] != null
            ? DateFormat('MMM dd, yyyy').format((order['createdAt'] as Timestamp).toDate())
            : 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order ID and status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${order['orderId'] ?? orderDoc.id.substring(0, 6)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber, width: 1),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer and date info
            Wrap(
              spacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(formattedDate, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        order['buyerName'] ?? 'Customer',
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 24),

            // Order total
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total (${order['itemCount'] ?? 1} ${(order['itemCount'] ?? 1) > 1 ? 'items' : 'item'})',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '₱${order['total']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: widget.accentColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons - stacked vertically to prevent overflow
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final buyerId = order['buyerId'];
                    final sellerId = order['sellerId'];
                    final orderId = order['orderId'];

                    if (buyerId == null || buyerId.isEmpty ||
                        sellerId == null || sellerId.isEmpty ||
                        orderId == null || orderId.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order data is incomplete. Cannot update status.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    try {
                      // Update in buyer's orders
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(buyerId)
                          .collection('orders')
                          .doc(orderId)
                          .update({'status': 'to ship'});

                      await orderDoc.reference.update({'status': 'to ship'});
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(sellerId)
                          .collection('sales')
                          .doc(orderId)
                          .update({'status': 'to ship'});

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order confirmed and ready to ship'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Switch to To Ship tab
                        _tabController.animateTo(1);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to confirm order: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Confirm Order'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showOrderDetails(orderDoc, order),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.accentColor,
                    side: BorderSide(color: widget.accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
