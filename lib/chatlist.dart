import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat.dart';

class ChatUserListPage extends StatefulWidget {
  const ChatUserListPage({super.key});

  @override
  State<ChatUserListPage> createState() => _ChatUserListPageState();
}

class _ChatUserListPageState extends State<ChatUserListPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in to access messages',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Chat header with search
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Messages',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.add_comment,
                          color: Color(0xFFD18050),
                        ),
                        onPressed: () {
                          // Show all users to start a new chat
                          setState(() {
                            _searchQuery = '';
                            _tabController.animateTo(1);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tab bar for Recent/All Users
                  TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFFD18050),
                    labelColor: const Color(0xFFD18050),
                    unselectedLabelColor: Colors.grey[600],
                    tabs: const [
                      Tab(text: 'Recent Chats'),
                      Tab(text: 'All Users'),
                    ],
                  ),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Recent chats tab
                  _searchQuery.isEmpty
                      ? _buildRecentChats()
                      : _buildSearchResults(),
                  // All users tab
                  _buildAllUsers(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show recent chats
  Widget _buildRecentChats() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('chat_meta')
              .where('participants', arrayContains: _currentUserId)
              .orderBy('lastMessageTime', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD18050)),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.message_outlined, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search for users to start chatting',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD18050),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    _tabController.animateTo(1);
                  },
                  child: const Text('Find Users'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            // Extract peer ID (the other user in the conversation)
            final participants = List<String>.from(data['participants'] ?? []);
            final peerId = participants.firstWhere(
              (id) => id != _currentUserId,
              orElse: () => '',
            );

            if (peerId.isEmpty) return const SizedBox.shrink();

            final lastMessage = data['lastMessage'] as String? ?? '';
            final lastMessageTime =
                data['lastMessageTime'] as Timestamp? ?? Timestamp.now();
            final lastSenderId = data['lastSenderId'] as String? ?? '';
            final isSender = lastSenderId == _currentUserId;
            final unreadCount =
                data['unreadCount_$_currentUserId'] as int? ?? 0;

            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(peerId)
                      .get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    title: Text('Loading...'),
                  );
                }

                if (!userSnap.data!.exists) {
                  return const SizedBox.shrink();
                }

                final userData = userSnap.data!.data() as Map<String, dynamic>;
                final username = userData['username'] as String? ?? 'Unknown';
                final avatarUrl = userData['avatarUrl'] as String?;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        // User avatar
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey[300],
                          backgroundImage:
                              avatarUrl != null
                                  ? NetworkImage(avatarUrl)
                                  : null,
                          child:
                              avatarUrl == null
                                  ? Text(
                                    username.isNotEmpty
                                        ? username[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                  : null,
                        ),
                        // Online indicator (placeholder - implement with real status)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        if (isSender)
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.grey,
                          ),
                        if (isSender) const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            lastMessage,
                            style: TextStyle(
                              color:
                                  unreadCount > 0
                                      ? Colors.black87
                                      : Colors.grey[600],
                              fontWeight:
                                  unreadCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatDate(lastMessageTime.toDate()),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                unreadCount > 0
                                    ? const Color(0xFFD18050)
                                    : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD18050),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatPage(
                                peerId: peerId,
                                peerUsername: username,
                                peerAvatar: avatarUrl,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Search users and conversations
  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .where('username', isGreaterThanOrEqualTo: _searchQuery)
              .where('username', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD18050)),
          );
        }

        final docs =
            snapshot.data!.docs
                .where((doc) => doc.id != _currentUserId)
                .toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final username = data['username'] as String? ?? 'Unknown';
            final avatarUrl = data['avatarUrl'] as String?;

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child:
                    avatarUrl == null
                        ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                        : null,
              ),
              title: Text(username),
              trailing: const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFFD18050),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ChatPage(
                          peerId: docs[index].id,
                          peerUsername: username,
                          peerAvatar: avatarUrl,
                        ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Show all users
  Widget _buildAllUsers() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .limit(50) // Limit for performance
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFD18050)),
          );
        }

        final docs =
            snapshot.data!.docs
                .where((doc) => doc.id != _currentUserId)
                .toList();

        if (docs.isEmpty) {
          return const Center(child: Text('No other users found.'));
        }

        // Group users by first letter
        final Map<String, List<DocumentSnapshot>> groupedUsers = {};

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final username = (data['username'] as String? ?? 'Unknown');
          final firstLetter =
              username.isNotEmpty ? username[0].toUpperCase() : '#';

          if (!groupedUsers.containsKey(firstLetter)) {
            groupedUsers[firstLetter] = [];
          }

          groupedUsers[firstLetter]!.add(doc);
        }

        final sortedKeys = groupedUsers.keys.toList()..sort();

        return ListView.builder(
          itemCount: sortedKeys.length,
          itemBuilder: (context, index) {
            final letter = sortedKeys[index];
            final users = groupedUsers[letter]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                ...users.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final username = data['username'] as String? ?? 'Unknown';
                  final avatarUrl = data['avatarUrl'] as String?;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child:
                          avatarUrl == null
                              ? Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                              : null,
                    ),
                    title: Text(username),
                    trailing: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      color: const Color(0xFFD18050),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => ChatPage(
                                  peerId: doc.id,
                                  peerUsername: username,
                                  peerAvatar: avatarUrl,
                                ),
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatPage(
                                peerId: doc.id,
                                peerUsername: username,
                                peerAvatar: avatarUrl,
                              ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }

  // Format the timestamp
  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == today) {
      return DateFormat.jm().format(dateTime); // Just time for today
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateToCheck).inDays < 7) {
      return DateFormat.E().format(dateTime); // Weekday name
    } else {
      return DateFormat.MMMd().format(dateTime); // Month and day
    }
  }
}
