import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: const Center(child: Text('Please log in to view your wishlist.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        backgroundColor: Color(0xFFD18050),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('wishlist')
            .orderBy('addedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Your wishlist is empty.'));
          }
          final wishlist = snapshot.data!.docs;
          return ListView.builder(
            itemCount: wishlist.length,
            itemBuilder: (context, index) {
              final item = wishlist[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: item['imageUrl'] != null && item['imageUrl'].isNotEmpty
                    ? Image.network(item['imageUrl'], width: 60, height: 60, fit: BoxFit.cover)
                    : const Icon(Icons.image, size: 60, color: Colors.grey),
                title: Text(item['productName'] ?? ''),
                subtitle: Text(item['productPrice'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await wishlist[index].reference.delete();
                  },
                ),
                onTap: () {
                  // Optionally, navigate to product details
                },
              );
            },
          );
        },
      ),
    );
  }
}