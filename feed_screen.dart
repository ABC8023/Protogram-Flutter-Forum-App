import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_app_asm/CreateStartupScreen.dart';
import 'package:mobile_app_asm/create_forum_post_screen.dart';
import 'package:mobile_app_asm/reported_posts_screen.dart';
import 'package:mobile_app_asm/saved_posts_screen.dart';
import 'package:mobile_app_asm/app_settings_screen.dart';
import 'package:mobile_app_asm/startup_screen.dart';
import 'CreatePostScreen.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:mobile_app_asm/feed_screen.dart';
import 'package:mobile_app_asm/forum_screen.dart';
import 'account_settings_screen.dart';
import 'comment_screen.dart';

class FeedScreen extends StatefulWidget {
  final String? postId; // ✅ New parameter to filter a single post
  FeedScreen({this.postId}); // ✅ Allow optional postId
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<QueryDocumentSnapshot> _cachedPosts = []; // ✅ Cache posts to prevent flickering
  bool _isLoading = true;
  bool _showMenu = false;
  String? _profilePicUrl;
  final user = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _filteredPosts = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadPosts(); // ✅ Initial load of posts
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPosts = _cachedPosts.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final topic = data['topic']?.toString().toLowerCase() ?? '';
        final description = data['description']?.toString().toLowerCase() ?? '';
        final username = data['username']?.toString().toLowerCase() ?? '';

        return topic.contains(query) ||
            description.contains(query) ||
            username.contains(query);
      }).toList();
    });
  }

  /// **Load User Profile Picture**
  void _loadUserProfile() async {
    if (user != null) {
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _profilePicUrl = userDoc['profilePic'];
        });
      }
    }
  }

  /// **Fetch Posts Without UI Flickering**
  void _loadPosts() {
    var query = FirebaseFirestore.instance.collection('posts').where('status', isEqualTo: "Approved");

    if (widget.postId != null) {
      query = query.where(FieldPath.documentId, isEqualTo: widget.postId);
    } else {
      query = query.orderBy('timestamp', descending: true);
    }

    print(" Firestore Query: ${query.parameters}"); // Debug: See the query details

    query.snapshots().listen((snapshot) {
      print(" Firestore Snapshot Received: ${snapshot.docs.length} documents"); // Debug: See if snapshot arrives
      if (mounted) {
        // Use a simpler check initially to ensure loading stops
        if (_isLoading || _cachedPosts.length != snapshot.docs.length || !_listEquals(_cachedPosts, snapshot.docs) ) { // Added check or simplified logic might be needed
          print(" Updating State: Found ${snapshot.docs.length} posts."); // Debug: Confirm state update attempt
          setState(() {
            _cachedPosts = snapshot.docs;
            _filteredPosts = snapshot.docs; // Update filtered list too
            _isLoading = false; // Make SURE this is set
          });
        } else {
          print(" State Not Updated: Data appears unchanged.");
        }
      }
    }, onError: (error) { // <-- ADD THIS
      print(" Firestore Stream Error: $error"); // Debug: Log the error
      if (mounted) {
        setState(() {
          _isLoading = false; // Stop loading even on error
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading posts: $error'))
        );
      }
    });
  }

  /// **Helper Function to Compare Lists**
  bool _listEquals(List<QueryDocumentSnapshot> list1, List<QueryDocumentSnapshot> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id || list1[i].data() != list2[i].data()) return false;
    }
    return true;
  }

  void _toggleMenu() {
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  void _navigateToCreatePost() {
    setState(() {
      _showMenu = false;
    });
    Get.to(() => CreatePostScreen());
  }

  // Modified Function (Using Named Route)
  void _navigateToCreateForum() {
    // 1. Hide the menu (assuming this is still needed in the widget's context)
    if (mounted) { // Good practice: Check if the widget is still in the tree
      setState(() {
        _showMenu = false;
      });
    }
    // 2. Navigate using the defined named route
    Get.to(() => CreateForumPostScreen()); // Use the route name you defined
  }

  void _navigateToCreateStartup() {
    // 1. Hide the menu (assuming this is still needed in the widget's context)
    if (mounted) { // Good practice: Check if the widget is still in the tree
      setState(() {
        _showMenu = false;
      });
    }
    // 2. Navigate using the defined named route
    Get.to(() => CreateStartupScreen()); // Use the route name you defined
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            _scrollController.animateTo(
              0.0,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: Text(
            "Protogram",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(1000, 80, 0, 0),
                items: [
                  PopupMenuItem(
                    child: Text("Account Settings"),
                    value: "account_settings",
                    onTap: () {
                      Future.delayed(Duration.zero, () {
                        Get.to(() => AccountSettingsScreen()); // 👈 You will need to create this screen
                      });
                    },
                  ),
                  PopupMenuItem(
                    child: Text("Logout"),
                    value: "logout",
                    onTap: () {
                      Future.delayed(Duration.zero, () {
                        _showLogoutConfirmation(context);
                      });
                    },
                  ),
                ],
              );
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              backgroundImage: _profilePicUrl != null && _profilePicUrl!.isNotEmpty
                  ? MemoryImage(base64Decode(_profilePicUrl!))
                  : const AssetImage("assets/user_profile.png") as ImageProvider?,
              child: _profilePicUrl == null || _profilePicUrl!.isEmpty
                  ? Icon(Icons.account_circle, size: 40, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search topic, description, or username",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus(); // Dismiss keyboard
                        },
                      )
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _filteredPosts.isEmpty
                      ? Center(child: Text("No posts match your search."))
                      : _buildPostList(),
                ),
              ],
            ),
          ),
          _showMenu
              ? GestureDetector(
            onTap: _toggleMenu,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _menuItem(
                          Icons.post_add,
                          "Create a Post",
                          "Share innovative ideas",
                          _navigateToCreatePost,
                          context,
                        ),
                        _menuItem(
                          Icons.forum,
                          "Create a Forum",
                          "Discuss topics with members",
                          _navigateToCreateForum,
                          context,
                        ),
                        _menuItem(
                          Icons.attach_money,
                          "Showcase your startup",
                          "Promote your startup",
                          _navigateToCreateStartup,
                          context,
                        ),
                        SizedBox(height: 10),
                        IconButton(
                          icon: Icon(Icons.close, size: 30, color: Theme.of(context).iconTheme.color),
                          onPressed: _toggleMenu,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
              : SizedBox(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: Icon(Icons.home, size: 30), onPressed: () {}),
              IconButton(icon: Icon(Icons.forum), onPressed: () {Get.to(() => ForumScreen());} ),
              SizedBox(width: 40), // Space for the floating action button
              IconButton(icon: Icon(Icons.business_center), onPressed: () {Get.to(() => StartupsScreen());}),
              IconButton(icon: Icon(Icons.settings), onPressed: () => Get.toNamed('/settings')),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleMenu,
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _menuItem(
      IconData icon,
      String title,
      String subtitle,
      VoidCallback onTap,
      BuildContext context,
      ) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
      ),
      onTap: onTap,
    );
  }

  Widget _buildPostList() {
    return ListView(
      controller: _scrollController,
      children: _filteredPosts.map((doc) => PostCard(postData: doc)).toList(),
    );
  }
}
void _showLogoutConfirmation(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Confirm Logout"),
      content: Text("Are you sure you want to log out?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // ❌ Cancel
          child: Text("Cancel"),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context); // Close dialog first
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'isOnline': false,
                'lastSeen': FieldValue.serverTimestamp(), // Optional
              });

              await FirebaseAuth.instance.signOut();
              Get.offAllNamed('/'); // 👈 Navigate to login_register.dart
            }
          },
          child: Text(
            "Logout",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}

class PostCard extends StatefulWidget {
  final QueryDocumentSnapshot postData;
  PostCard({required this.postData});

  @override
  _PostCardState createState() => _PostCardState();
}

class _ImageCarousel extends StatefulWidget {
  final List<String> images;

  _ImageCarousel({required this.images});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final bool hasMultiple = widget.images.length > 1;

    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(widget.images[index]),
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),

        // ✅ Top-right image counter
        if (hasMultiple)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}/${widget.images.length}',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

        // ✅ Bottom center dot indicator
        if (hasMultiple)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (index) {
                  return Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.blueAccent
                          : Colors.grey[400],
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }
}

class _PostCardState extends State<PostCard> {
  bool _isSaved = false;
  bool _isReported = false;

  // --- NEW STATE VARIABLES ---
  bool _isLiked = false;
  bool _isDisliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  int _commentCount = 0;
  String? _currentUserId;
  // --- END NEW STATE VARIABLES ---


  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initializePostState(); // Combined initialization
    _checkIfSaved();
    _checkIfReported();
  }

  /// **Initialize counts and user interaction status**
  void _initializePostState() {
    if (_currentUserId != null) {
      final postDataMap = widget.postData.data() as Map<String, dynamic>? ?? {};
      final List<dynamic> likedBy = postDataMap['likedBy'] as List<dynamic>? ?? [];
      final List<dynamic> dislikedBy = postDataMap['dislikedBy'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _isLiked = likedBy.contains(_currentUserId);
          _isDisliked = dislikedBy.contains(_currentUserId);
          _likeCount = postDataMap['likeCount'] as int? ?? 0;
          _dislikeCount = postDataMap['dislikeCount'] as int? ?? 0;
          _commentCount = postDataMap['commentCount'] as int? ?? 0; // Get comment count
        });
      }
    } else {
      // Handle case where user is not logged in (optional)
      final postDataMap = widget.postData.data() as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          _likeCount = postDataMap['likeCount'] as int? ?? 0;
          _dislikeCount = postDataMap['dislikeCount'] as int? ?? 0;
          _commentCount = postDataMap['commentCount'] as int? ?? 0;
        });
      }
    }
  }


  /// **Check if the post is already reported**
  void _checkIfReported() async {
    var currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      var query = await FirebaseFirestore.instance
          .collection('reportedPosts')
          .where('userId', isEqualTo: currentUser.uid)
          .where('postId', isEqualTo: widget.postData.id)
          .limit(1) // More efficient
          .get();

      if (mounted) {
        setState(() {
          _isReported = query.docs.isNotEmpty;
        });
      }
    }
  }

  /// **Report or Unreport a post**
  void _toggleReportUnreport() async {
    if (_currentUserId == null) return; // Must be logged in

    if (_isReported) {
      // Unreport
      var query = await FirebaseFirestore.instance
          .collection('reportedPosts')
          .where('userId', isEqualTo: _currentUserId)
          .where('postId', isEqualTo: widget.postData.id)
          .get();
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
      if (mounted) setState(() => _isReported = false);
      _showCustomDialog(context, Icons.info_outline, "Report Removed", success: false);

    } else {
      // Report
      var postDetails = widget.postData.data() as Map<String, dynamic>;
      await FirebaseFirestore.instance.collection('reportedPosts').add({
        'userId': _currentUserId,
        'postId': widget.postData.id,
        'username': postDetails['username'],
        'profilePic': postDetails['profilePic'],
        'topic': postDetails['topic'],
        'description': postDetails['description'],
        'images': postDetails['images'],
        'timestamp': postDetails['timestamp'], // Use original post timestamp
        'reportedAt': FieldValue.serverTimestamp(), // Add when it was reported
      });

      if (mounted) setState(() => _isReported = true);
      _showCustomDialog(context, Icons.check_circle, "Post Reported!");
    }
  }

  /// **Check if the post is already saved**
  void _checkIfSaved() async {
    if (_currentUserId == null) return;
    var query = await FirebaseFirestore.instance
        .collection('savedPosts')
        .where('userId', isEqualTo: _currentUserId)
        .where('postId', isEqualTo: widget.postData.id)
        .limit(1) // More efficient
        .get();

    if (mounted) {
      setState(() {
        _isSaved = query.docs.isNotEmpty;
      });
    }
  }

  /// **Save or Unsave a post**
  void _toggleSaveUnsave() async {
    if (_currentUserId == null) return; // Must be logged in

    if (_isSaved) {
      // Unsave
      var query = await FirebaseFirestore.instance
          .collection('savedPosts')
          .where('userId', isEqualTo: _currentUserId)
          .where('postId', isEqualTo: widget.postData.id)
          .get();
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
      if (mounted) setState(() => _isSaved = false);
      _showCustomDialog(context, Icons.bookmark_remove, "Post Unsaved", success: false);

    } else {
      // Save
      var postDetails = widget.postData.data() as Map<String, dynamic>;
      await FirebaseFirestore.instance.collection('savedPosts').add({
        'userId': _currentUserId,
        'postId': widget.postData.id,
        'username': postDetails['username'],
        'profilePic': postDetails['profilePic'],
        'topic': postDetails['topic'],
        'description': postDetails['description'],
        'images': postDetails['images'],
        'timestamp': postDetails['timestamp'], // Original post timestamp
        'savedAt': FieldValue.serverTimestamp(), // When it was saved
      });

      if (mounted) setState(() => _isSaved = true);
      _showCustomDialog(context, Icons.bookmark_added, "Post Saved!");
    }
  }

  // --- NEW LIKE/DISLIKE/COMMENT FUNCTIONS ---

  /// **Toggle Like Status**
  void _toggleLike() async {
    if (_currentUserId == null) return; // Must be logged in

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postData.id);
    final String userId = _currentUserId!;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(postRef);
        if (!snapshot.exists) {
          throw Exception("Post does not exist!");
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        int newLikeCount = data['likeCount'] as int? ?? 0;
        int newDislikeCount = data['dislikeCount'] as int? ?? 0;
        List<String> likedBy = List<String>.from(data['likedBy'] as List<dynamic>? ?? []);
        List<String> dislikedBy = List<String>.from(data['dislikedBy'] as List<dynamic>? ?? []);

        bool currentlyLiked = likedBy.contains(userId);
        bool currentlyDisliked = dislikedBy.contains(userId);

        if (currentlyLiked) {
          // User wants to unlike
          newLikeCount--;
          likedBy.remove(userId);
        } else {
          // User wants to like
          newLikeCount++;
          likedBy.add(userId);
          // If user previously disliked, remove dislike
          if (currentlyDisliked) {
            newDislikeCount--;
            dislikedBy.remove(userId);
          }
        }

        transaction.update(postRef, {
          'likeCount': newLikeCount,
          'dislikeCount': newDislikeCount,
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
        });

        // Update local state optimistically AFTER transaction logic
        if (mounted) {
          setState(() {
            _isLiked = !currentlyLiked; // Toggle state
            _isDisliked = false; // Cannot be disliked if liked
            _likeCount = newLikeCount;
            _dislikeCount = newDislikeCount;
          });
        }

      });
      print("Transaction success!");
    } catch (e) {
      print("Transaction failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update like status: $e")),
      );
      // Optional: Revert optimistic UI update or refetch state here
      _initializePostState(); // Re-fetch state on error
    }
  }


  /// **Toggle Dislike Status**
  void _toggleDislike() async {
    if (_currentUserId == null) return; // Must be logged in

    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postData.id);
    final String userId = _currentUserId!;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(postRef);
        if (!snapshot.exists) {
          throw Exception("Post does not exist!");
        }

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        int newLikeCount = data['likeCount'] as int? ?? 0;
        int newDislikeCount = data['dislikeCount'] as int? ?? 0;
        List<String> likedBy = List<String>.from(data['likedBy'] as List<dynamic>? ?? []);
        List<String> dislikedBy = List<String>.from(data['dislikedBy'] as List<dynamic>? ?? []);

        bool currentlyLiked = likedBy.contains(userId);
        bool currentlyDisliked = dislikedBy.contains(userId);

        if (currentlyDisliked) {
          // User wants to un-dislike
          newDislikeCount--;
          dislikedBy.remove(userId);
        } else {
          // User wants to dislike
          newDislikeCount++;
          dislikedBy.add(userId);
          // If user previously liked, remove like
          if (currentlyLiked) {
            newLikeCount--;
            likedBy.remove(userId);
          }
        }

        transaction.update(postRef, {
          'likeCount': newLikeCount,
          'dislikeCount': newDislikeCount,
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
        });

        // Update local state optimistically AFTER transaction logic
        if (mounted) {
          setState(() {
            _isDisliked = !currentlyDisliked; // Toggle state
            _isLiked = false; // Cannot be liked if disliked
            _likeCount = newLikeCount;
            _dislikeCount = newDislikeCount;
          });
        }
      });
      print("Transaction success!");
    } catch (e) {
      print("Transaction failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update dislike status: $e")),
      );
      // Optional: Revert optimistic UI update or refetch state here
      _initializePostState(); // Re-fetch state on error
    }
  }

  /// **Navigate to Comment Screen**
  void _navigateToCommentScreen() {
    Get.to(() => CommentScreen(postId: widget.postData.id));
  }

  // --- END NEW FUNCTIONS ---


  @override
  Widget build(BuildContext context) {
    final postData = widget.postData.data() as Map<String, dynamic>? ?? {}; // Handle null data
    final String postId = widget.postData.id; // Get post ID

    // Safely access fields with defaults
    final String username = postData['username'] as String? ?? "Unknown User";
    final String profilePic = postData['profilePic'] as String? ?? "";
    final dynamic timestamp = postData['timestamp']; // Keep dynamic for _formatTimestamp
    final String topic = postData['topic'] as String? ?? "No Topic";
    final String description = postData['description'] as String? ?? "No Description";
    final List<String> images = List<String>.from(postData['images'] as List<dynamic>? ?? []);


    return Card(
      margin: EdgeInsets.all(8),
      elevation: 3, // Add some elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounded corners
      child: Padding(
        padding: const EdgeInsets.all(12), // Slightly more padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20, // Consistent size
                  backgroundColor: Colors.grey[300], // Placeholder color
                  backgroundImage: profilePic.isNotEmpty
                      ? MemoryImage(base64Decode(profilePic))
                      : AssetImage("assets/user_profile.png") as ImageProvider,
                ),
                SizedBox(width: 10),
                Expanded( // Allow username to take space
                  child: Text(
                    username,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis, // Prevent overflow
                  ),
                ),
                // Spacer(), // Removed spacer to let username expand
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]), // Standard icon
                  onSelected: (value) {
                    if (value == "save") {
                      _toggleSaveUnsave();
                    } else if (value == "report") {
                      _toggleReportUnreport();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: "save",
                      child: Row( // Add icons to menu items
                        children: [
                          Icon(_isSaved ? Icons.bookmark_remove : Icons.bookmark_add_outlined, size: 20),
                          SizedBox(width: 8),
                          Text(_isSaved ? "Unsave Post" : "Save Post"),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: "report",
                      child: Row(
                        children: [
                          Icon(_isReported ? Icons.flag : Icons.flag_outlined, size: 20, color: _isReported ? Colors.orange : null,),
                          SizedBox(width: 8),
                          Text(_isReported ? "Unreport Post" : "Report Post"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
                topic,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)
            ),
            SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[300]
                    : Colors.grey[800],
              ),
            ),
            SizedBox(height: 10),

            // Display Images if Available
            if (images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0), // Add vertical padding
                child: _ImageCarousel(images: images),
              ),
            Divider(height: 20, thickness: 1), // Separator before actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- LIKE BUTTON ---
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                        color: _isLiked ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                        size: 22, // Slightly smaller icon
                      ),
                      onPressed: _toggleLike,
                      tooltip: _isLiked ? 'Unlike' : 'Like', // Tooltip
                      padding: EdgeInsets.zero, // Remove default padding
                      constraints: BoxConstraints(), // Remove default constraints
                    ),
                    SizedBox(width: 4),
                    Text("$_likeCount", style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                    SizedBox(width: 16), // Spacing between like/dislike

                    // --- DISLIKE BUTTON ---
                    IconButton(
                      icon: Icon(
                        _isDisliked ? Icons.thumb_down_alt : Icons.thumb_down_alt_outlined,
                        color: _isDisliked ? Colors.redAccent : Colors.grey[600],
                        size: 22,
                      ),
                      onPressed: _toggleDislike,
                      tooltip: _isDisliked ? 'Remove Dislike' : 'Dislike',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    SizedBox(width: 4),
                    Text("$_dislikeCount", style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  ],
                ),

                // --- COMMENT BUTTON ---
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.mode_comment_outlined, color: Colors.grey[600], size: 22,),
                      onPressed: _navigateToCommentScreen, // Navigate to comments
                      tooltip: 'View Comments',
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    SizedBox(width: 4),
                    Text("$_commentCount", style: TextStyle(fontSize: 14, color: Colors.grey[700])), // Display comment count
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  /// **Custom Dialog Function** (Modified for better visual feedback)
  void _showCustomDialog(BuildContext context, IconData icon, String message, {bool success = true}) {
    showDialog(
        context: context,
        barrierDismissible: false, // User must tap button to close
        builder: (context) {
          // Auto close after a short duration
          Timer(Duration(seconds: 2), () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    icon,
                    size: 50,
                    color: success ? Colors.green : Colors.orangeAccent // Green for success, Orange for info/removal
                ),
                SizedBox(height: 15),
                Text(message, style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
                SizedBox(height: 5), // Reduced space
                // No button needed, auto-closes
              ],
            ),
            contentPadding: EdgeInsets.fromLTRB(20, 25, 20, 15), // Adjust padding
          );
        }
    );
  }


  /// **Format Timestamp**
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      Duration diff = DateTime.now().difference(dateTime);

      if (diff.inSeconds < 60) {
        return "${diff.inSeconds}s ago";
      } else if (diff.inMinutes < 60) {
        return "${diff.inMinutes}m ago";
      } else if (diff.inHours < 24) {
        return "${diff.inHours}h ago";
      } else if (diff.inDays < 7) {
        return "${diff.inDays}d ago";
      } else {
        // Fallback to date format if older than a week
        return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
      }
    }
    return "Unknown Date";
  }

// --- Keep _savePost and _reportPost if you need them for other purposes ---
// --- but the main logic is now in _toggleSaveUnsave and _toggleReportUnreport ---

// Removed redundant _savePost and _reportPost methods as their logic
// is now integrated into the toggle functions (_toggleSaveUnsave, _toggleReportUnreport)

} // End of _PostCardState}