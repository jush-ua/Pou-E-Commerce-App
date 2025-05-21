import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class PurchaseHistoryPage extends StatefulWidget {
  final String initialTab; // e.g. 'TO SHIP', 'TO RECEIVE', etc.
  const PurchaseHistoryPage({super.key, this.initialTab = 'TO SHIP'});

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    'PENDING',
    'TO SHIP',
    'TO RECEIVE',
    'COMPLETED',
    'TO RATE',
  ];
  final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    int initialIndex = _tabs.indexOf(widget.initialTab);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getOrdersStream(String status) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
      final String userId = user.uid; // This matches your backend's userId

    String firestoreStatus;
    switch (status) {
      case 'PENDING':
        firestoreStatus = 'pending';
        break;
      case 'TO SHIP':
        firestoreStatus = 'to_ship';
        break;
      case 'TO RECEIVE':
        firestoreStatus = 'to_receive';
        break;
      case 'COMPLETED':
        firestoreStatus = 'completed';
        break;
      case 'TO RATE':
        firestoreStatus = 'to_rate';
        break;
      default:
        firestoreStatus = status.toLowerCase();
    }
    return FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: userId) // userId matches backend logic
        .where('status', isEqualTo: firestoreStatus)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.deepPurple;
      case 'TO SHIP':
        return Colors.orange;
      case 'TO RECEIVE':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'TO RATE':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState(String status) {
    IconData icon;
    String message;

    switch (status) {
      case 'PENDING':
        icon = Icons.hourglass_empty;
        message = 'No pending orders';
        break;
      case 'TO SHIP':
        icon = Icons.inventory_2;
        message = 'No orders waiting to be shipped';
        break;
      case 'TO RECEIVE':
        icon = Icons.local_shipping;
        message = 'No orders in transit';
        break;
      case 'COMPLETED':
        icon = Icons.check_circle;
        message = 'No completed orders yet';
        break;
      case 'TO RATE':
        icon = Icons.star_border;
        message = 'No orders to rate';
        break;
      default:
        icon = Icons.shopping_bag;
        message = 'No orders found';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Items you order will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD18050),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Continue Shopping'),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  Widget _buildOrderList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getOrdersStream(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD18050)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(status);
        }

        final orders = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
            final orderDate =
                order['timestamp'] as Timestamp? ?? Timestamp.now();
            final total = order['total'] ?? 0;
            final formattedTotal =
                total is num ? currencyFormat.format(total) : '₹0';
            final orderId = orders[index].id;

            print(order['status']);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order header with ID and date
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 18,
                          color: Color(0xFFD18050),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Order #${orderId.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _getStatusColor(status)),
                          ),
                          child: Text(
                            (order['status'] ?? status).toString().toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor((order['status'] ?? status).toString().toUpperCase()),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Order items list
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: items.length > 3 ? 3 : items.length,
                    itemBuilder: (context, idx) {
                      final item = items[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  item['imageUrl'] != null &&
                                          item['imageUrl'].toString().isNotEmpty
                                      ? Image.network(
                                        item['imageUrl'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[200],
                                            child: const Icon(
                                              Icons.image_not_supported,
                                            ),
                                          );
                                        },
                                      )
                                      : Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.shopping_bag),
                                      ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? 'Product Name',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Qty: ${item['quantity'] ?? 1} × ${item['price'] != null ? currencyFormat.format(item['price']) : '₹0'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Show more items if there are more than 3
                  if (items.length > 3)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        '+ ${items.length - 3} more items',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),

                  const Divider(),

                  // Order total and date
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order Date',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(_formatDate(orderDate)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Order Total',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              formattedTotal,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD18050),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action buttons based on status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'TO SHIP')
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              // Cancel order functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cancellation request sent'),
                                ),
                              );
                            },
                            child: const Text('Cancel Order'),
                          ),
                        if (status == 'TO RECEIVE')
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              // Track order functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tracking information not available',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Track Package'),
                          ),
                        if (status == 'TO RATE')
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD18050),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              // Rate product functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Rating feature coming soon'),
                                ),
                              );
                            },
                            child: const Text('Rate Product'),
                          ),
                        if (status == 'COMPLETED')
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD18050),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              // Buy again functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Adding items to cart'),
                                ),
                              );
                            },
                            child: const Text('Buy Again'),
                          ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD18050),
                            side: const BorderSide(color: Color(0xFFD18050)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            // View details functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Order details coming soon'),
                              ),
                            );
                          },
                          child: const Text('View Details'),
                        ),
                      ],
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFD18050),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xFFD18050),
              child: TabBar(
                controller: _tabController,
                tabs:
                    _tabs.map((tab) {
                      String label;
                      IconData icon;

                      switch (tab) {
                        case 'PENDING':
                          label = 'Pending';
                          icon = Icons.hourglass_empty;
                          break;
                        case 'TO SHIP':
                          label = 'To Ship';
                          icon = Icons.inventory_2;
                          break;
                        case 'TO RECEIVE':
                          label = 'To Receive';
                          icon = Icons.local_shipping;
                          break;
                        case 'COMPLETED':
                          label = 'Completed';
                          icon = Icons.check_circle;
                          break;
                        case 'TO RATE':
                          label = 'To Rate';
                          icon = Icons.star_border;
                          break;
                        default:
                          label = tab;
                          icon = Icons.shopping_bag;
                      }

                      return Tab(icon: Icon(icon, size: 20), text: label);
                    }).toList(),
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _tabs.map((tab) => _buildOrderList(tab)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
