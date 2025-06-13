// discussion.dart
import 'dart:async';
import 'dart:convert'; // For base64Decode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart'; // Using Get for potential dialogs/navigation if needed

// --- Helper Functions (Ideally in a utils file) ---
String _formatTimestamp(dynamic timestamp) {
  if (timestamp is Timestamp) {
    DateTime dateTime = timestamp.toDate();
    Duration diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}"; // Fallback date format
  }
  return "Unknown Date";
}

void _showCustomDialog(BuildContext context, IconData icon, String message, {bool success = true}) {
  showDialog(
    context: context,
    barrierDismissible: false, // User must tap button (or let timer expire)
    builder: (context) {
      Timer(Duration(seconds: 2), () {
        // Check if the dialog is still mounted/visible before popping
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 50, color: success ? Colors.green : Colors.orangeAccent),
            SizedBox(height: 15),
            Text(message, style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
            SizedBox(height: 5),
          ],
        ),
        contentPadding: EdgeInsets.fromLTRB(20, 25, 20, 15), // Adjust padding
      );
    },
  );
}
// --- End Helper Functions ---


// =======================================================================
// Image Carousel Widget (Copied from forum_screen.dart)
// =======================================================================
class _ImageCarousel extends StatefulWidget {
  final List<String> images;
  _ImageCarousel({required this.images});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return SizedBox.shrink(); // Don't show anything if no images
    }

    final bool hasMultiple = widget.images.length > 1;
    double aspectRatio = 16 / 9; // Default aspect ratio

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              if (mounted) { setState(() => _currentPage = index); }
            },
            itemBuilder: (context, index) {
              try {
                // Assuming images are base64 encoded strings
                final imageBytes = base64Decode(widget.images[index]);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(4.0), // Optional: slightly rounded corners
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.cover, // Cover the aspect ratio box
                    gaplessPlayback: true, // Helps reduce flicker during rebuilds
                    errorBuilder: (context, error, stackTrace) {
                      print("Error loading image in carousel (index $index): $error");
                      return Container(
                          color: Colors.grey[200],
                          child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[500], size: 40))
                      );
                    },
                  ),
                );
              } catch (e) {
                print("Error decoding base64 image (index $index): $e");
                return Container(
                    color: Colors.grey[200],
                    child: Center(child: Icon(Icons.error_outline, color: Colors.red[300], size: 40))
                );
              }
            },
          ),

          // Top-right image counter
          if (hasMultiple)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration( color: Colors.black54, borderRadius: BorderRadius.circular(12), ),
                child: Text( '${_currentPage + 1}/${widget.images.length}', style: TextStyle(color: Colors.white, fontSize: 12), ),
              ),
            ),

          // Bottom center dot indicator
          if (hasMultiple)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (idx) {
                  return Container(
                    width: 7, height: 7, // Slightly smaller dots
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == idx ? Theme.of(context).colorScheme.primary : Colors.grey[400]?.withOpacity(0.8),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
// =======================================================================
// End Image Carousel Widget
// =======================================================================


// --- Data Models ---
// Represents raw Firestore data for a comment/reply
class DiscussionItemData {
  final String id;
  final String content;
  final String userId;
  final String username;
  final String profilePic;
  final Timestamp timestamp;
  final String? parentId;
  // --- NEW Fields for Likes/Dislikes ---
  final int likeCount;
  final int dislikeCount;
  final List<String> likedBy;
  final List<String> dislikedBy;
  // --- End NEW Fields ---

  DiscussionItemData({
    required this.id,
    required this.content,
    required this.userId,
    required this.username,
    required this.profilePic,
    required this.timestamp,
    this.parentId,
    // --- NEW Fields ---
    required this.likeCount,
    required this.dislikeCount,
    required this.likedBy,
    required this.dislikedBy,
  });

  factory DiscussionItemData.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return DiscussionItemData(
      id: doc.id,
      content: data['content'] ?? '',
      userId: data['userId'] ?? '',
      username: data['name'] ?? 'Unknown User',
      profilePic: data['profilePic'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      parentId: data['parentId'] as String?,
      // --- NEW Fields (with defaults for backward compatibility) ---
      likeCount: data['likeCount'] as int? ?? 0,
      dislikeCount: data['dislikeCount'] as int? ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      dislikedBy: List<String>.from(data['dislikedBy'] ?? []),
    );
  }
}

// Represents a comment/reply in the UI tree structure
class DiscussionItemNode {
  final DiscussionItemData data;
  final List<DiscussionItemNode> children;
  final int depth;

  DiscussionItemNode({
    required this.data,
    required this.children,
    required this.depth,
  });
}
// --- End Data Models ---

// --- Reply Input Area Widget (Stateful) ---
class _ReplyInputArea extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isPosting;
  final String? replyingToUsername;
  final VoidCallback onPost; // Callback for posting
  final VoidCallback onCancel; // Callback for cancelling reply state

  const _ReplyInputArea({
    required this.controller,
    required this.focusNode,
    required this.isPosting,
    required this.replyingToUsername,
    required this.onPost,
    required this.onCancel,
    Key? key,
  }) : super(key: key);

  @override
  __ReplyInputAreaState createState() => __ReplyInputAreaState();
}

class __ReplyInputAreaState extends State<_ReplyInputArea> {
  bool _canPost = false; // Internal state to control button

  @override
  void initState() {
    super.initState();
    _canPost = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateButtonState);
    super.dispose();
  }

  void _updateButtonState() {
    if (!mounted) return;
    final canPostNow = widget.controller.text.trim().isNotEmpty;
    if (_canPost != canPostNow) {
      setState(() { _canPost = canPostNow; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          left: 12.0, right: 12.0, top: 8.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12.0
      ),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow( color: Colors.black.withOpacity(0.08), blurRadius: 5, offset: Offset(0, -2)),
          ],
          border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5))
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingToUsername != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Replying to @${widget.replyingToUsername}",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: widget.onCancel,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close, size: 18, color: Colors.grey[700]),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: widget.replyingToUsername == null ? "Add a reply..." : "Write your reply...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[100] : Colors.grey[800],
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: widget.isPosting
                    ? SizedBox( width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                  icon: Icon(Icons.send),
                  iconSize: 24,
                  color: Theme.of(context).colorScheme.primary,
                  tooltip: 'Post Reply',
                  onPressed: _canPost ? widget.onPost : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// --- End Reply Input Area Widget ---


// --- Main Screen Widget ---
class DiscussionScreen extends StatefulWidget {
  final String forumId;
  final Map<String, dynamic> initialPostData;
  final int initialCommentCount;

  DiscussionScreen({
    required this.forumId,
    required this.initialPostData,
    required this.initialCommentCount,
    Key? key,
  }) : super(key: key);

  @override
  _DiscussionScreenState createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  User? _currentUser;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _discussionSubscription;

  String? _currentUserProfilePic;
  String? _currentUsername;

  List<DiscussionItemData> _flatReplies = [];
  List<DiscussionItemNode> _threadedReplies = [];

  bool _isLoadingReplies = true;
  bool _isPostingReply = false;
  String? _replyingToCommentId;
  String? _replyingToUsername;

  // --- NEW: State Maps for Reply Likes/Dislikes ---
  Map<String, bool> _userLikesReply = {};      // replyId -> true if current user liked
  Map<String, bool> _userDislikesReply = {};   // replyId -> true if current user disliked
  Map<String, int> _replyLikeCounts = {};     // replyId -> like count
  Map<String, int> _replyDislikeCounts = {};  // replyId -> dislike count
  // --- END NEW ---

  static const double _indentationWidth = 20.0;
  static const double _lineWidth = 1.0;
  static final Color _lineColor = Colors.grey[300]!;


  @override
  void initState() {
    super.initState();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        final bool userChanged = _currentUser?.uid != user?.uid;
        setState(() { _currentUser = user; });
        if (user != null) {
          _loadLoggedInUserProfile(user.uid);
          // Re-evaluate existing replies if user logs in/changes
          if(userChanged) _updateUserInteractionState();
        } else {
          _clearUserInfoAndReplyState();
          // Clear like/dislike state if user logs out
          if(userChanged) _updateUserInteractionState();
        }
      }
    });

    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _loadLoggedInUserProfile(_currentUser!.uid);
    }

    _loadDiscussion();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    _scrollController.dispose();
    _authSubscription?.cancel();
    _discussionSubscription?.cancel();
    super.dispose();
  }

  void _clearUserInfoAndReplyState() {
    if(mounted) {
      setState(() {
        _currentUserProfilePic = null;
        _currentUsername = null;
        _replyingToCommentId = null;
        _replyingToUsername = null;
        // Clear user-specific interactions
        _userLikesReply.clear();
        _userDislikesReply.clear();
      });
    }
  }

  Future<void> _loadLoggedInUserProfile(String userId) async {
    if (_currentUsername != null && _currentUser?.uid == userId) return;

    print("Loading logged-in user profile for discussion: $userId");
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (mounted && userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (_currentUser?.uid == userId) {
          setState(() {
            _currentUserProfilePic = data?['profilePic'];
            _currentUsername = data?['name'] ?? 'Unknown User';
            print("Logged-in user profile loaded: Username=$_currentUsername");
            // Update interaction state based on newly loaded user
            _updateUserInteractionState();
          });
        }
      } else if (mounted && _currentUser?.uid == userId) {
        print("Logged-in user document not found for ID: $userId");
        setState(() {
          _currentUsername = "User-${userId.substring(0, 5)}";
          _currentUserProfilePic = "";
          _updateUserInteractionState(); // Update based on defaults
        });
      }
    } catch (e) {
      print("Error loading logged-in user profile for discussion: $e");
      if (mounted && _currentUser?.uid == userId) {
        setState(() {
          _currentUsername = "Error Loading Profile";
          _currentUserProfilePic = "";
          _updateUserInteractionState(); // Update based on error state
        });
      }
    }
  }

  // --- Discussion Loading & State Update ---
  void _loadDiscussion() {
    if (!mounted) return;
    setState(() { _isLoadingReplies = true; });

    _discussionSubscription?.cancel();

    final discussionRef = FirebaseFirestore.instance
        .collection('forumPosts')
        .doc(widget.forumId)
        .collection('discussionItems')
        .orderBy('timestamp', descending: false);

    _discussionSubscription = discussionRef.snapshots().listen((snapshot) {
      if (!mounted) return;
      print("Received discussion snapshot: ${snapshot.docs.length} items for post ${widget.forumId}");

      // --- Update Flat List and Counts/Interactions ---
      List<DiscussionItemData> newFlatReplies = [];
      Map<String, int> newLikeCounts = {};
      Map<String, int> newDislikeCounts = {};
      Map<String, bool> newUserLikes = {};
      Map<String, bool> newUserDislikes = {};
      String? currentUserId = _currentUser?.uid;

      for (var doc in snapshot.docs) {
        final itemData = DiscussionItemData.fromFirestore(doc);
        newFlatReplies.add(itemData);
        newLikeCounts[itemData.id] = itemData.likeCount;
        newDislikeCounts[itemData.id] = itemData.dislikeCount;
        if (currentUserId != null) {
          newUserLikes[itemData.id] = itemData.likedBy.contains(currentUserId);
          newUserDislikes[itemData.id] = itemData.dislikedBy.contains(currentUserId);
        } else {
          newUserLikes[itemData.id] = false;
          newUserDislikes[itemData.id] = false;
        }
      }

      // Build the hierarchy from the new flat list
      List<DiscussionItemNode> newThreadedReplies = _buildThread(newFlatReplies, null, 0);

      // Update UI state
      setState(() {
        _flatReplies = newFlatReplies;
        _threadedReplies = newThreadedReplies;
        _replyLikeCounts = newLikeCounts;
        _replyDislikeCounts = newDislikeCounts;
        _userLikesReply = newUserLikes;
        _userDislikesReply = newUserDislikes;
        _isLoadingReplies = false;
      });

    }, onError: (error) {
      print("Error loading discussion for post ${widget.forumId}: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading discussion.")));
        setState(() {
          _isLoadingReplies = false;
          _flatReplies = [];
          _threadedReplies = [];
          _replyLikeCounts.clear(); // Clear state on error
          _replyDislikeCounts.clear();
          _userLikesReply.clear();
          _userDislikesReply.clear();
        });
      }
    });
  }

  // Helper to re-evaluate user interactions without full reload
  void _updateUserInteractionState() {
    if (!mounted) return;
    Map<String, bool> newUserLikes = {};
    Map<String, bool> newUserDislikes = {};
    String? currentUserId = _currentUser?.uid;

    for (var itemData in _flatReplies) { // Use existing flat list
      if (currentUserId != null) {
        newUserLikes[itemData.id] = itemData.likedBy.contains(currentUserId);
        newUserDislikes[itemData.id] = itemData.dislikedBy.contains(currentUserId);
      } else {
        newUserLikes[itemData.id] = false;
        newUserDislikes[itemData.id] = false;
      }
    }
    setState(() {
      _userLikesReply = newUserLikes;
      _userDislikesReply = newUserDislikes;
    });
    print("User interaction state updated. Liked: ${_userLikesReply.values.where((v) => v).length}, Disliked: ${_userDislikesReply.values.where((v) => v).length}");
  }

  // Recursive function to build the nested thread structure
  List<DiscussionItemNode> _buildThread(List<DiscussionItemData> allItems, String? parentId, int depth) {
    List<DiscussionItemNode> nodes = [];
    List<DiscussionItemData> childrenData = allItems.where((item) => item.parentId == parentId).toList();
    // Sorting is already handled by Firestore query ('timestamp', ascending)

    for (var itemData in childrenData) {
      List<DiscussionItemNode> grandchildren = _buildThread(allItems, itemData.id, depth + 1);
      nodes.add(DiscussionItemNode(
        data: itemData,
        children: grandchildren,
        depth: depth,
      ));
    }
    return nodes;
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    final String postUsername = widget.initialPostData['username'] ?? "Unknown User";
    final String postProfilePicBase64 = widget.initialPostData['profilePic'] ?? "";
    final String postContent = widget.initialPostData['content'] ?? "";
    final dynamic postTimestamp = widget.initialPostData['timestamp'];
    final List<String> postImages = widget.initialPostData['images'] != null ? List<String>.from(widget.initialPostData['images']) : [];
    final int displayCommentCount = _flatReplies.length;
    final bool canReply = _currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text("Discussion"),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async { _loadDiscussion(); },
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // --- Original Post Display ---
                  SliverToBoxAdapter(
                    child: Material(
                      elevation: 0.5,
                      shape: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: postProfilePicBase64.isNotEmpty
                                      ? MemoryImage(base64Decode(postProfilePicBase64), scale: 1.0) as ImageProvider
                                      : AssetImage("assets/user_profile.png") as ImageProvider,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(postUsername, style: TextStyle(fontWeight: FontWeight.bold)),
                                      Text(_formatTimestamp(postTimestamp), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            if (postContent.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Text(postContent, style: TextStyle(fontSize: 16)),
                              ),
                            if (postImages.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: _ImageCarousel(images: postImages),
                              ),
                            SizedBox(height: 8),
                            Text(
                                "${displayCommentCount} ${displayCommentCount == 1 ? 'Reply' : 'Replies'}",
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])
                            ),
                            SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- Loading Indicator or Empty State for Replies ---
                  SliverToBoxAdapter(
                    child: (_isLoadingReplies && _threadedReplies.isEmpty)
                        ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: CircularProgressIndicator()))
                        : (!_isLoadingReplies && _threadedReplies.isEmpty)
                        ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40.0), child: Text("Be the first to reply!", style: TextStyle(fontSize: 15, color: Colors.grey[600]))))
                        : SizedBox.shrink(),
                  ),

                  // --- Threaded Replies ---
                  if (!_isLoadingReplies)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          return _buildReplyNodeWidget(_threadedReplies[index]);
                        },
                        childCount: _threadedReplies.length,
                      ),
                    ),

                  SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              ),
            ),
          ),

          // --- Reply Input Area ---
          if (canReply)
            _ReplyInputArea(
              controller: _replyController,
              focusNode: _replyFocusNode,
              isPosting: _isPostingReply,
              replyingToUsername: _replyingToUsername,
              onPost: _postReply,
              onCancel: _cancelReply,
            )
          else
            Container(
              padding: const EdgeInsets.all(16.0),
              width: double.infinity,
              color: Theme.of(context).cardColor.withOpacity(0.8),
              child: Text("Log in to join the discussion.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            ),
        ],
      ),
    );
  }

  /// Builds the vertical line indicating the current reply depth connection.
  Widget _buildVerticalLines(int depth) {
    if (depth == 0) {
      return SizedBox.shrink();
    }
    final double lineLeftPosition = (depth - 1) * _indentationWidth + (_indentationWidth / 2) - (_lineWidth / 2);
    const double avatarRadius = 16.0;
    const double avatarTopPadding = 2.0;
    const double verticalLineStopOffset = avatarTopPadding + avatarRadius;

    return SizedBox(
      width: depth * _indentationWidth,
      child: Stack(
        children: [
          Positioned(
            left: lineLeftPosition, top: 0, bottom: null,
            height: verticalLineStopOffset + 2,
            child: Container( width: _lineWidth, color: _lineColor),
          ),
          Positioned(
            left: lineLeftPosition, top: verticalLineStopOffset,
            child: Container( width: _indentationWidth / 2 + (_lineWidth/2), height: _lineWidth, color: _lineColor),
          ),
        ],
      ),
    );
  }

  // Widget to build a single node (comment/reply) and its children recursively
  Widget _buildReplyNodeWidget(DiscussionItemNode node) {
    final itemData = node.data;
    final String itemId = itemData.id; // ID for state lookup
    const double baseHorizontalPadding = 12.0;

    // --- Get state for this specific item ---
    final bool isLoggedIn = _currentUser != null;
    final bool isLiked = _userLikesReply[itemId] ?? false;
    final bool isDisliked = _userDislikesReply[itemId] ?? false;
    final int likeCount = _replyLikeCounts[itemId] ?? 0;
    final int dislikeCount = _replyDislikeCounts[itemId] ?? 0;
    // ---

    return Padding(
      padding: EdgeInsets.only(
        top: node.depth == 0 ? 12.0 : 8.0,
        left: baseHorizontalPadding,
        right: baseHorizontalPadding,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Vertical Lines Area ---
            _buildVerticalLines(node.depth),

            // --- Content Area ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row for Avatar, Name, Timestamp, Content
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: itemData.profilePic.isNotEmpty
                              ? MemoryImage(base64Decode(itemData.profilePic), scale: 1.0) as ImageProvider
                              : AssetImage("assets/user_profile.png") as ImageProvider,
                        ),
                      ),
                      SizedBox(width: 8),
                      // Content Column (Name, Time, Text)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Username and Timestamp Row
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6.0, runSpacing: 2.0,
                              children: [
                                Text(itemData.username, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(_formatTimestamp(itemData.timestamp), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                              ],
                            ),
                            SizedBox(height: 3),
                            // Comment Content
                            Text(itemData.content, style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ), // End Avatar/Content Row

                  // --- NEW: Action Row (Reply, Like, Dislike) ---
                  Padding(
                    padding: const EdgeInsets.only(left: 16 + 8, top: 4.0), // Indent under avatar + space
                    child: Row(
                      children: [
                        // Reply Button
                        if (isLoggedIn) // Only show if logged in
                          InkWell(
                            onTap: () => _setReplyingTo(itemData),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                              child: Text("Reply", style: TextStyle(color: Theme.of(context).colorScheme.primary.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500)),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        if (isLoggedIn) SizedBox(width: 15), // Space after Reply

                        // Like Button
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            color: isLoggedIn ? (isLiked ? Theme.of(context).colorScheme.primary : Colors.grey[600]) : Colors.grey[400],
                          ),
                          iconSize: 18,
                          tooltip: isLoggedIn ? (isLiked ? 'Unlike' : 'Like') : 'Log in to like',
                          onPressed: isLoggedIn ? () => _toggleLikeReply(itemId) : null,
                          padding: EdgeInsets.all(4), constraints: BoxConstraints(), visualDensity: VisualDensity.compact,
                        ),
                        SizedBox(width: 2),
                        Text(likeCount.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                        SizedBox(width: 12), // Spacing

                        // Dislike Button
                        IconButton(
                          icon: Icon(
                            isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                            color: isLoggedIn ? (isDisliked ? Colors.redAccent : Colors.grey[600]) : Colors.grey[400],
                          ),
                          iconSize: 18,
                          tooltip: isLoggedIn ? (isDisliked ? 'Remove Dislike' : 'Dislike') : 'Log in to dislike',
                          onPressed: isLoggedIn ? () => _toggleDislikeReply(itemId) : null,
                          padding: EdgeInsets.all(4), constraints: BoxConstraints(), visualDensity: VisualDensity.compact,
                        ),
                        SizedBox(width: 2),
                        Text(dislikeCount.toString(), style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                  // --- END NEW Action Row ---

                  // Spacing before children/divider
                  SizedBox(height: 8.0),

                  // --- Recursively build children nodes ---
                  ...node.children.map((childNode) => _buildReplyNodeWidget(childNode)),

                  // --- Divider Logic ---
                  if (node.depth == 0 )
                    Padding(
                      padding: EdgeInsets.only(top: node.children.isNotEmpty ? 8.0 : 0.0),
                      child: Divider(height: 1, thickness: 0.5, color: _lineColor),
                    )
                  else if (node.children.isEmpty)
                    SizedBox(height: 4),

                ],
              ),
            ), // End Expanded Content Area
          ],
        ), // End IntrinsicHeight Row
      ),
    );
  }


  // --- Action Handlers ---

  void _setReplyingTo(DiscussionItemData item) {
    if (!mounted) return;
    setState(() {
      _replyingToCommentId = item.id;
      _replyingToUsername = item.username;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _replyFocusNode.requestFocus();
    });
    print("Set replying to: ${_replyingToUsername} (ID: ${_replyingToCommentId})");
  }

  void _cancelReply() {
    if (!mounted) return;
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
      _replyController.clear(); // Also clear text when explicitly cancelling
    });
    _replyFocusNode.unfocus();
    print("Cancelled reply.");
  }

  Future<void> _postReply() async {
    if (_currentUser == null) {
      _showCustomDialog(context, Icons.error_outline, "Please log in to reply.", success: false);
      return;
    }
    final content = _replyController.text.trim();
    if (content.isEmpty || _isPostingReply) {
      print("Cannot post reply: Empty content or already posting.");
      return;
    }

    if (_currentUsername == null || _currentUsername == "Error Loading Profile") {
      _showCustomDialog(context, Icons.warning_amber_rounded, "Your profile is still loading. Please wait and try again.", success: false);
      if (_currentUser != null && _currentUsername == null) {
        _loadLoggedInUserProfile(_currentUser!.uid);
      }
      return;
    }

    setState(() { _isPostingReply = true; });

    final user = _currentUser!;
    final forumId = widget.forumId;
    final parentId = _replyingToCommentId;

    final forumPostRef = FirebaseFirestore.instance.collection('forumPosts').doc(forumId);
    final newReplyRef = forumPostRef.collection('discussionItems').doc();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot postSnapshot = await transaction.get(forumPostRef);
        if (!postSnapshot.exists) {
          throw Exception("Original post not found. Cannot add reply.");
        }

        transaction.set(newReplyRef, {
          'content': content,
          'userId': user.uid,
          'name': _currentUsername,
          'profilePic': _currentUserProfilePic ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          'parentId': parentId,
          // --- NEW: Initialize like/dislike fields ---
          'likeCount': 0,
          'dislikeCount': 0,
          'likedBy': [],
          'dislikedBy': [],
          // --- END NEW ---
        });

        transaction.update(forumPostRef, {'commentCount': FieldValue.increment(1)});
      });

      print("Reply posted successfully to post $forumId!");
      // No need to clear controller here, _cancelReply does it
      _cancelReply(); // Reset reply state and clear text

      Future.delayed(Duration(milliseconds: 300), () => _scrollToBottom());

    } catch (e) {
      print("Error posting reply to post $forumId: $e");
      if (mounted) {
        _showCustomDialog(context, Icons.error, "Failed to post reply. Please try again.", success: false);
      }
    } finally {
      if (mounted) {
        setState(() { _isPostingReply = false; });
      }
    }
  }

  // --- NEW: Like/Dislike Toggle Functions for Replies ---

  /// **Toggle Like Status for a Reply**
  void _toggleLikeReply(String replyId) async {
    if (_currentUser == null) { _showCustomDialog(context, Icons.error_outline, "Please log in to like replies.", success: false); return; }
    final replyRef = FirebaseFirestore.instance.collection('forumPosts').doc(widget.forumId)
        .collection('discussionItems').doc(replyId);
    final String userId = _currentUser!.uid;

    print("Toggling like for reply: $replyId by user: $userId");

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(replyRef);
        if (!snapshot.exists) throw Exception("Reply does not exist!");
        Map<String, dynamic> data = snapshot.data()! as Map<String, dynamic>;

        // Use defaults if fields are missing
        int newLikeCount = data['likeCount'] as int? ?? 0;
        int newDislikeCount = data['dislikeCount'] as int? ?? 0;
        List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
        List<String> dislikedBy = List<String>.from(data['dislikedBy'] ?? []);

        bool currentlyLiked = likedBy.contains(userId);
        bool currentlyDisliked = dislikedBy.contains(userId);

        if (currentlyLiked) { // Unlike
          newLikeCount--;
          likedBy.remove(userId);
        } else { // Like
          newLikeCount++;
          likedBy.add(userId);
          if (currentlyDisliked) { // Remove dislike if liking
            newDislikeCount--;
            dislikedBy.remove(userId);
          }
        }

        transaction.update(replyRef, {
          'likeCount': newLikeCount.clamp(0, double.infinity).toInt(),
          'dislikeCount': newDislikeCount.clamp(0, double.infinity).toInt(),
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
        });
      });
      print("Like transaction success for reply $replyId!");
      // UI update will be handled by the stream listener (_loadDiscussion)
    } catch (e) {
      print("Like transaction failed for reply $replyId: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update like: $e"))); }
      // State will automatically correct via the listener on error or success
    }
  }

  /// **Toggle Dislike Status for a Reply**
  void _toggleDislikeReply(String replyId) async {
    if (_currentUser == null) { _showCustomDialog(context, Icons.error_outline, "Please log in to dislike replies.", success: false); return; }
    final replyRef = FirebaseFirestore.instance.collection('forumPosts').doc(widget.forumId)
        .collection('discussionItems').doc(replyId);
    final String userId = _currentUser!.uid;

    print("Toggling dislike for reply: $replyId by user: $userId");

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(replyRef);
        if (!snapshot.exists) throw Exception("Reply does not exist!");
        Map<String, dynamic> data = snapshot.data()! as Map<String, dynamic>;

        // Use defaults if fields are missing
        int newLikeCount = data['likeCount'] as int? ?? 0;
        int newDislikeCount = data['dislikeCount'] as int? ?? 0;
        List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
        List<String> dislikedBy = List<String>.from(data['dislikedBy'] ?? []);

        bool currentlyLiked = likedBy.contains(userId);
        bool currentlyDisliked = dislikedBy.contains(userId);

        if (currentlyDisliked) { // Remove dislike
          newDislikeCount--;
          dislikedBy.remove(userId);
        } else { // Dislike
          newDislikeCount++;
          dislikedBy.add(userId);
          if (currentlyLiked) { // Remove like if disliking
            newLikeCount--;
            likedBy.remove(userId);
          }
        }

        transaction.update(replyRef, {
          'likeCount': newLikeCount.clamp(0, double.infinity).toInt(),
          'dislikeCount': newDislikeCount.clamp(0, double.infinity).toInt(),
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
        });
      });
      print("Dislike transaction success for reply $replyId!");
      // UI update will be handled by the stream listener (_loadDiscussion)
    } catch (e) {
      print("Dislike transaction failed for reply $replyId: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update dislike: $e"))); }
      // State will automatically correct via the listener
    }
  }
  // --- END NEW Like/Dislike Toggles ---


  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }
} // End of _DiscussionScreenState class