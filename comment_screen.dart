import 'dart:async'; // Import for StreamSubscription
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // For base64Decode
import 'package:intl/intl.dart'; // For date formatting

class CommentScreen extends StatefulWidget {
  final String postId;

  CommentScreen({required this.postId});

  @override
  _CommentScreenState createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  final TextEditingController _commentController = TextEditingController();

  // Remove final User? currentUser = FirebaseAuth.instance.currentUser;

  String? _replyToCommentId;
  String? _replyToUsername;
  User? _currentUser; // Make currentUser mutable and private
  StreamSubscription<
      User?>? _authStateSubscription; // To listen for auth changes

  String? _userProfilePic;
  String? _username;
  bool _isLoadingUserData = true; // Track user data loading state
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
          if (mounted) { // Check if the widget is still in the tree
            setState(() {
              _currentUser = user;
              _isLoadingUserData =
              true; // Reset loading state when user changes
              _userProfilePic = null; // Clear previous user data
              _username = null;
            });
            if (_currentUser != null) {
              _loadUserProfile(
                  _currentUser!); // Load profile when user is available
            } else {
              // Handle user being logged out if necessary
              setState(() {
                _isLoadingUserData = false;
              });
              print("CommentScreen: No user logged in.");
            }
          }
        });
  }

  @override
  void dispose() {
    _authStateSubscription
        ?.cancel(); // Cancel subscription to prevent memory leaks
    _commentController.dispose();
    super.dispose();
  }

  // Modify _loadUserProfile to accept the user
  void _loadUserProfile(User user) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) { // Check mounted state again after async operation
        if (userDoc.exists) {
          setState(() {
            _userProfilePic = userDoc['profilePic'];
            _username = userDoc['name'];
            _isLoadingUserData = false; // Mark loading as complete
          });
          print("CommentScreen: User profile loaded: $_username");
        } else {
          print("CommentScreen: User document does not exist for ${user.uid}");
          setState(() {
            _isLoadingUserData = false; // Still complete, but no data
          });
        }
      }
    } catch (e) {
      print("Error loading user profile: $e");
      if (mounted) {
        setState(() {
          _isLoadingUserData = false; // Loading failed
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading your profile data.')),
        );
      }
    }
  }

  void _postComment() async {
    final commentText = _commentController.text.trim();

    // --- Updated Check ---
    if (commentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment cannot be empty.')),
      );
      return;
    }
    // Check if user data is loaded *and* user is logged in
    if (_isLoadingUserData || _currentUser == null || _username == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User data not loaded yet. Please wait.')),
      );
      return;
    }
    // --- End Updated Check ---


    if (_isSending) return; // Prevent double taps

    setState(() => _isSending = true);

    final postRef = FirebaseFirestore.instance.collection('posts').doc(
        widget.postId);
    final commentColRef = postRef.collection('comments');

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.set(commentColRef.doc(), {
        'userId': _currentUser!.uid,
        'username': _username,
        'profilePic': _userProfilePic ?? '',
        'text': commentText,
        'timestamp': FieldValue.serverTimestamp(),
        'parentId': _replyToCommentId,
        'replyToUsername': _replyToUsername,
      });

      batch.update(postRef, {
        'commentCount': FieldValue.increment(1),
      });

      await batch.commit();

      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      print("Error posting comment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
    _replyToCommentId = null;
    _replyToUsername = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Comments"),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Error loading comments stream: ${snapshot
                      .error}"); // Log error
                  return Center(child: Text("Error loading comments."));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No comments yet. Be the first!"));
                }

                final rawComments = snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  return data;
                }).toList();

                final parentComments = rawComments.where((c) => c['parentId'] == null).toList();
                final replies = rawComments.where((c) => c['parentId'] != null).toList();

                return ListView(
                  padding: EdgeInsets.only(bottom: 8),
                  children: parentComments.map((parent) {
                    return _buildCommentWithReplies(parent, rawComments);
                  }).toList(),
                );
              },
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentWithReplies(
      Map<String, dynamic> comment,
      List<Map<String, dynamic>> allComments, {
        int indentLevel = 0,
      }) {
    final commentId = comment['id'];
    final replies = allComments
        .where((c) => c['parentId'] == commentId)
        .toList()
      ..sort((a, b) {
        final tA = a['timestamp'] as Timestamp?;
        final tB = b['timestamp'] as Timestamp?;
        return (tB ?? Timestamp.now()).compareTo(tA ?? Timestamp.now());
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indentLevel > 0 ? 32.0 * indentLevel : 0),
          child: _buildCommentTile(comment, commentId: commentId),
        ),
        ...replies.map((reply) =>
            _buildCommentWithReplies(reply, allComments, indentLevel: indentLevel + 1))
      ],
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> commentData, {required String commentId}) {
    final String profilePic = commentData['profilePic'] ?? "";
    final String username = commentData['username'] ?? "Anon";
    final String text = commentData['text'] ?? "";
    final Timestamp? timestamp = commentData['timestamp'];
    final String timeAgo = timestamp != null ? _formatTimestampRelative(timestamp) : "";
    final String? replyingTo = commentData['replyToUsername'];

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: profilePic.isNotEmpty
                ? MemoryImage(base64Decode(profilePic))
                : AssetImage("assets/user_profile.png") as ImageProvider,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Text(timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                if (replyingTo != null)
                  Text("Replying to @$replyingTo", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(text),
                SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _replyToCommentId = commentId;
                        _replyToUsername = username;
                      });
                      FocusScope.of(context).requestFocus(FocusNode());
                    },
                    child: Text("Reply", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    // Decide whether to show loading indicator or profile pic
    Widget avatarWidget;
    if (_isLoadingUserData) {
      avatarWidget = CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[300],
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.grey[600]),
        ),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[300],
        backgroundImage: _userProfilePic != null && _userProfilePic!.isNotEmpty
            ? MemoryImage(base64Decode(_userProfilePic!))
            : AssetImage("assets/user_profile.png") as ImageProvider?,
        child: (_userProfilePic == null || _userProfilePic!.isEmpty)
            ? Icon(
          Icons.person, size: 18, color: Colors.white,) // Placeholder icon
            : null,
      );
    }

    // Disable input/button if user data isn't ready or not logged in
    bool canComment = !_isLoadingUserData && _currentUser != null &&
        _username != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyToUsername != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(child: Text("Replying to @$_replyToUsername",
                    style: TextStyle(color: Colors.grey))),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _replyToUsername = null;
                      _replyToCommentId = null;
                    });
                  },
                ),
              ],
            ),
          ),
        Container(
          padding: EdgeInsets.only(
            left: 12.0,
            right: 8.0,
            top: 8.0,
            bottom: MediaQuery
                .of(context)
                .padding
                .bottom + 8.0,
          ),
          decoration: BoxDecoration(
            color: Theme
                .of(context)
                .cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, -2),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatarWidget,
              SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  enabled: canComment,
                  decoration: InputDecoration(
                    hintText: canComment
                        ? "Add a comment..."
                        : "Loading user...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme
                        .of(context)
                        .brightness == Brightness.light
                        ? Colors.grey[200]
                        : Colors.grey[800],
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: canComment ? (_) => _postComment() : null,
                  maxLines: 5,
                  minLines: 1,
                ),
              ),
              SizedBox(width: 4),
              IconButton(
                icon: _isSending
                    ? SizedBox(width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.send, color: canComment ? Theme
                    .of(context)
                    .colorScheme
                    .primary : Colors.grey),
                onPressed: (_isSending || !canComment) ? null : _postComment,
                tooltip: canComment
                    ? "Send Comment"
                    : "Cannot comment right now",
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Move this here — outside of any widget or function
  String _formatTimestampRelative(Timestamp timestamp) {
    try {
      DateTime dateTime = timestamp.toDate();
      Duration diff = DateTime.now().difference(dateTime);

      if (diff.inSeconds < 5) {
        return "now";
      } else if (diff.inSeconds < 60) {
        return "${diff.inSeconds}s";
      } else if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m";
      } else if (diff.inHours < 24) {
        return "${diff.inHours}h";
      } else if (diff.inDays < 7) {
        return "${diff.inDays}d";
      } else {
        return DateFormat('dd MMM').format(dateTime);
      }
    } catch (e) {
      print("Error formatting timestamp: $e");
      return "";
    }
  }
}