import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add this dependency for date formatting

class ChatPage extends StatefulWidget {
  final String peerId;
  final String peerUsername;
  final String? peerAvatar; // Optional peer avatar URL

  const ChatPage({
    super.key,
    required this.peerId,
    required this.peerUsername,
    this.peerAvatar,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late String _currentUserId;
  bool _isLoading = false;
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
    // Mark messages as read when chat opens
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get chatId {
    // Create a consistent chatId regardless of who initiated the chat
    return _currentUserId.compareTo(widget.peerId) <= 0
        ? '${_currentUserId}_${widget.peerId}'
        : '${widget.peerId}_${_currentUserId}';
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final batch = _firestore.batch();
      final messagesQuery = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: _currentUserId)
          .where('read', isEqualTo: false)
          .get();

      for (final doc in messagesQuery.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isComposing = false;
    });

    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'senderId': _currentUserId,
            'receiverId': widget.peerId,
            'text': text,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

      // Also update the chat metadata in a separate collection
      await _firestore.collection('chat_meta').doc(chatId).set({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [_currentUserId, widget.peerId],
        'lastSenderId': _currentUserId,
      }, SetOptions(merge: true));

      _controller.clear();

      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == _currentUserId;
    final text = data['text'] as String? ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final time = timestamp != null
        ? DateFormat('h:mm a').format(timestamp.toDate())
        : '';
    final isRead = data['read'] as bool? ?? false;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFFD18050) // Your app's orange
              : Colors.grey[200], // Light grey for received messages
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                  ),
                ),
                if (isMe) const SizedBox(width: 4),
                if (isMe) Icon(
                  isRead ? Icons.done_all : Icons.done,
                  size: 12,
                  color: Colors.white70,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(String date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          date,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD18050),
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              radius: 18,
              backgroundImage: widget.peerAvatar != null
                  ? NetworkImage(widget.peerAvatar!)
                  : null,
              child: widget.peerAvatar == null
                  ? Text(
                      widget.peerUsername.isNotEmpty
                          ? widget.peerUsername[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerUsername,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('user_status')
                      .where('userId', isEqualTo: widget.peerId)
                      .limit(1)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final data = snapshot.data!.docs.first.data()
                          as Map<String, dynamic>;
                      final isOnline = data['isOnline'] as bool? ?? false;
                      final lastSeen = data['lastSeen'] as Timestamp?;

                      if (isOnline) {
                        return const Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        );
                      } else if (lastSeen != null) {
                        return Text(
                          'Last seen ${_formatLastSeen(lastSeen.toDate())}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        );
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Show options menu (e.g., block user, clear chat)
              showModalBottomSheet(
                context: context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete),
                      title: const Text('Clear chat'),
                      onTap: () {
                        // Implement clear chat functionality
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: const Text('Block user'),
                      onTap: () {
                        // Implement block user functionality
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .doc(chatId)
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .limit(100) // Limit for performance
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD18050),
                      )
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.message, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Say hello to start a conversation!',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Mark incoming messages as read
                  _markMessagesAsRead();

                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      // Add date separators
                      final currentDoc = docs[index];
                      final currentData = currentDoc.data() as Map<String, dynamic>;
                      final currentTimestamp = currentData['timestamp'] as Timestamp?;

                      // Only add a date separator if we have a timestamp and if it's
                      // different from the next message's date
                      if (currentTimestamp != null) {
                        final currentDate = DateTime(
                          currentTimestamp.toDate().year,
                          currentTimestamp.toDate().month,
                          currentTimestamp.toDate().day,
                        );

                        // Add separator for first message or when date changes
                        if (index == docs.length - 1) {
                          // Last message (first chronologically)
                          return Column(
                            children: [
                              _buildDateSeparator(
                                _formatMessageDate(currentTimestamp.toDate()),
                              ),
                              _buildMessageItem(currentDoc),
                            ],
                          );
                        } else {
                          final nextDoc = docs[index + 1];
                          final nextData = nextDoc.data() as Map<String, dynamic>;
                          final nextTimestamp = nextData['timestamp'] as Timestamp?;

                          if (nextTimestamp != null) {
                            final nextDate = DateTime(
                              nextTimestamp.toDate().year,
                              nextTimestamp.toDate().month,
                              nextTimestamp.toDate().day,
                            );

                            if (currentDate.compareTo(nextDate) != 0) {
                              return Column(
                                children: [
                                  _buildDateSeparator(
                                    _formatMessageDate(currentTimestamp.toDate()),
                                  ),
                                  _buildMessageItem(currentDoc),
                                ],
                              );
                            }
                          }
                        }
                      }

                      return _buildMessageItem(currentDoc);
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo),
                    color: const Color(0xFFD18050),
                    onPressed: () {
                      // TODO: Add image/file attachment functionality
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (text) {
                        setState(() {
                          _isComposing = text.trim().isNotEmpty;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isComposing
                          ? const Color(0xFFD18050)
                          : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isComposing && !_isLoading ? _sendMessage : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == today) {
      return 'today at ${DateFormat('h:mm a').format(dateTime)}';
    } else if (dateToCheck == yesterday) {
      return 'yesterday at ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  String _formatMessageDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateToCheck).inDays < 7) {
      return DateFormat('EEEE').format(dateTime); // Day of week
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
}
