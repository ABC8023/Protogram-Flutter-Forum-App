import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_app_asm/CreatePostScreen.dart';
import 'package:mobile_app_asm/create_forum_post_screen.dart';
import 'package:mobile_app_asm/discussion.dart';
import 'package:mobile_app_asm/account_settings_screen.dart';
import 'package:mobile_app_asm/app_settings_screen.dart';
import 'package:mobile_app_asm/feed_screen.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_app_asm/startup_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'CreateStartupScreen.dart';

void _showLogoutConfirmation(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Confirm Logout"),
      content: const Text("Are you sure you want to log out?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'isOnline': false,
                'lastSeen': FieldValue.serverTimestamp(),
              });
              await FirebaseAuth.instance.signOut();
              Get.offAllNamed('/');
            }
          },
          child: const Text("Logout", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

void _showCustomDialog(BuildContext context, IconData icon, String message, {bool success = true}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      Timer(const Duration(seconds: 2), () {
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
            const SizedBox(height: 15),
            Text(message, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 5),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
      );
    },
  );
}

String _formatTimestamp(dynamic timestamp) {
  if (timestamp is Timestamp) {
    DateTime dateTime = timestamp.toDate();
    Duration diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }
  return "Unknown Date";
}

class ForumScreen extends StatefulWidget {
  final String? forumId;
  ForumScreen({this.forumId});
  @override
  _ForumScreenState createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<QueryDocumentSnapshot> _cachedForumPosts = [];
  bool _isLoading = true;
  String? _profilePicUrl;
  User? _currentUser;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _filteredForumPosts = [];
  StreamSubscription? _forumPostsSubscription;
  StreamSubscription<User?>? _authSubscription;
  bool _showMenu = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          if (user == null) {
            _profilePicUrl = null;
          } else {
            _loadUserProfile();
          }
          if (user == null) _showMenu = false;
        });
      }
    });
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _loadUserProfile();
    }
    _loadForumPosts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _forumPostsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredForumPosts = _cachedForumPosts;
      } else {
        _filteredForumPosts = _cachedForumPosts.where((doc) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final content = data['content']?.toString().toLowerCase() ?? '';
          final username = data['username']?.toString().toLowerCase() ?? '';
          return content.contains(query) || username.contains(query);
        }).toList();
      }
    });
  }

  void _loadUserProfile() async {
    if (_currentUser == null) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data() as Map<String, dynamic>?;
        setState(() {
          _profilePicUrl = data?['profilePic'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profilePicUrl = null;
        });
      }
    }
  }

  void _loadForumPosts() {
    Query query = FirebaseFirestore.instance.collection('forumPosts').where('status', isEqualTo: "Approved");
    if (widget.forumId != null && widget.forumId!.isNotEmpty) {
      query = query.where(FieldPath.documentId, isEqualTo: widget.forumId);
    } else {
      query = query.orderBy('timestamp', descending: true);
    }
    _forumPostsSubscription?.cancel();
    _forumPostsSubscription = query.snapshots().listen((snapshot) {
      if (mounted) {
        setState(() {
          _cachedForumPosts = snapshot.docs;
          _onSearchChanged();
          _isLoading = false;
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _cachedForumPosts = [];
          _filteredForumPosts = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading forum posts: $error')));
      }
    });
  }

  void _toggleMenu() {
    if (_currentUser == null) {
      _showCustomDialog(context, Icons.error_outline, "Please log in to create content.", success: false);
      return;
    }
    setState(() {
      _showMenu = !_showMenu;
    });
  }

  void _navigateToCreatePost() {
    setState(() {
      _showMenu = false;
    });
    if (_currentUser == null) return;
    Get.to(() => CreatePostScreen());
  }

  void _navigateToCreateForum() {
    setState(() {
      _showMenu = false;
    });
    if (_currentUser == null) return;
    Get.to(() => CreateForumPostScreen());
  }

  void _navigateToCreateStartup() {
    if (mounted) {
      setState(() {
        _showMenu = false;
      });
    }
    Get.to(() => CreateStartupScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            if (_scrollController.hasClients && _scrollController.position.pixels > 0) {
              _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            }
          },
          child: const Text("Forums", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        actions: [
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: GestureDetector(
                onTap: () {
                  showMenu(
                    context: context,
                    position: const RelativeRect.fromLTRB(1000, 80, 0, 0),
                    items: [
                      PopupMenuItem(
                        value: "account_settings",
                        child: const Text("Account Settings"),
                        onTap: () => Future.delayed(Duration.zero, () => Get.to(() => AccountSettingsScreen())),
                      ),
                      PopupMenuItem(
                        value: "logout",
                        child: const Text("Logout"),
                        onTap: () => Future.delayed(Duration.zero, () => _showLogoutConfirmation(context)),
                      ),
                    ],
                  );
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _profilePicUrl != null && _profilePicUrl!.isNotEmpty ? MemoryImage(base64Decode(_profilePicUrl!)) : const AssetImage("assets/user_profile.png") as ImageProvider?,
                  child: _profilePicUrl == null || _profilePicUrl!.isEmpty ? Icon(Icons.account_circle, size: 40, color: Colors.grey[600]) : null,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: IconButton(
                icon: const Icon(Icons.login),
                tooltip: "Login / Register",
                onPressed: () => Get.offAllNamed('/'),
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
                      hintText: "Search content or username",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.light ? Colors.grey[200] : Colors.grey[800],
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: () {
                          _searchController.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredForumPosts.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        _searchController.text.isEmpty ? "No forum posts available yet.\nTap the '+' button to start a discussion!" : "No forum posts match your search.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ),
                  )
                      : _buildForumPostList(),
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
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _menuItem(Icons.post_add, "Create a Post", "Share campaign details", _navigateToCreatePost, context),
                        _menuItem(Icons.forum, "Create a Forum", "Discuss topics with members", _navigateToCreateForum, context),
                        _menuItem(Icons.attach_money, "New Startup", "Introduce your new startup", _navigateToCreateStartup, context),
                        const SizedBox(height: 10),
                        IconButton(icon: Icon(Icons.close, size: 30, color: Theme.of(context).iconTheme.color), onPressed: _toggleMenu),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
              : const SizedBox(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(tooltip: "Feed", icon: const Icon(Icons.dynamic_feed_outlined), onPressed: () => Get.offAll(() => FeedScreen())),
              IconButton(tooltip: "Forums", icon: Icon(Icons.forum, color: Theme.of(context).colorScheme.primary), onPressed: () {}),
              const SizedBox(width: 40),
              IconButton(tooltip: "Startup", icon: const Icon(Icons.business_center), onPressed: () => Get.offAll(() => StartupsScreen())),
              IconButton(tooltip: "App Settings", icon: const Icon(Icons.settings_outlined), onPressed: () => Get.to(() => AppSettingsScreen())),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleMenu,
        child: const Icon(Icons.add),
        tooltip: 'Create...',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _menuItem(IconData icon, String title, String subtitle, VoidCallback onTap, BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
      onTap: onTap,
    );
  }

  Widget _buildForumPostList() {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredForumPosts.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        return ForumPostCard(forumPostData: _filteredForumPosts[index]);
      },
    );
  }
}

class ForumPostCard extends StatefulWidget {
  final QueryDocumentSnapshot forumPostData;
  ForumPostCard({required this.forumPostData});
  @override
  _ForumPostCardState createState() => _ForumPostCardState();
}

class _ForumPostCardState extends State<ForumPostCard> {
  bool _isLiked = false;
  bool _isDisliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  int _commentCount = 0;
  bool _isLoadingAuthStatus = true;
  User? _currentUser;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<DocumentSnapshot>? _postChangesSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        final bool userChanged = _currentUser?.uid != user?.uid;
        setState(() {
          _currentUser = user;
          _isLoadingAuthStatus = false;
        });
        _initializeOrClearPostState(_postChangesSubscription == null || userChanged);
      }
    });
    _currentUser = FirebaseAuth.instance.currentUser;
    _initializeOrClearPostState(true);
  }

  void _initializeOrClearPostState(bool forceInitialization) {
    final postDataMap = widget.forumPostData.data() as Map<String, dynamic>? ?? {};
    if (_currentUser != null) {
      if (forceInitialization || _postChangesSubscription == null) {
        _postChangesSubscription?.cancel();
        _postChangesSubscription = FirebaseFirestore.instance.collection('forumPosts').doc(widget.forumPostData.id).snapshots().listen((snapshot) {
          if (mounted && snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>? ?? {};
            final List<dynamic> likedBy = data['likedBy'] as List<dynamic>? ?? [];
            final List<dynamic> dislikedBy = data['dislikedBy'] as List<dynamic>? ?? [];
            setState(() {
              _isLiked = likedBy.contains(_currentUser!.uid);
              _isDisliked = dislikedBy.contains(_currentUser!.uid);
              _likeCount = data['likeCount'] as int? ?? 0;
              _dislikeCount = data['dislikeCount'] as int? ?? 0;
              _commentCount = data['commentCount'] as int? ?? 0;
            });
          } else if (mounted && !snapshot.exists) {
            _postChangesSubscription?.cancel();
            _postChangesSubscription = null;
            setState(() {
              _likeCount = 0;
              _dislikeCount = 0;
              _commentCount = 0;
              _isLiked = false;
              _isDisliked = false;
            });
          }
        }, onError: (error) {
          print("Error listening to post changes for ${widget.forumPostData.id}: $error");
        });
      }
    } else {
      _postChangesSubscription?.cancel();
      _postChangesSubscription = null;
      setState(() {
        _isLiked = false;
        _isDisliked = false;
        _likeCount = postDataMap['likeCount'] as int? ?? 0;
        _dislikeCount = postDataMap['dislikeCount'] as int? ?? 0;
        _commentCount = postDataMap['commentCount'] as int? ?? 0;
      });
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _postChangesSubscription?.cancel();
    super.dispose();
  }

  void _toggleLikeForum() async {
    if (_currentUser == null) {
      _showCustomDialog(context, Icons.error_outline, "Please log in to like posts.", success: false);
      return;
    }
    final postRef = FirebaseFirestore.instance.collection('forumPosts').doc(widget.forumPostData.id);
    final String userId = _currentUser!.uid;
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(postRef);
        if (!snapshot.exists) throw Exception("Forum post does not exist!");
        Map<String, dynamic> data = snapshot.data()! as Map<String, dynamic>;
        int newLikeCount = data['likeCount'] ?? 0;
        int newDislikeCount = data['dislikeCount'] ?? 0;
        List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
        List<String> dislikedBy = List<String>.from(data['dislikedBy'] ?? []);
        bool currentlyLiked = likedBy.contains(userId);
        bool currentlyDisliked = dislikedBy.contains(userId);
        if (currentlyLiked) {
          newLikeCount--; likedBy.remove(userId);
        } else {
          newLikeCount++; likedBy.add(userId);
          if (currentlyDisliked) {
            newDislikeCount--; dislikedBy.remove(userId);
          }
        }
        transaction.update(postRef, {
          'likeCount': newLikeCount.clamp(0, double.infinity),
          'dislikeCount': newDislikeCount.clamp(0, double.infinity),
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update like: $e")));
      }
    }
  }

  void _toggleDislikeForum() async {
    if (_currentUser == null) {
      _showCustomDialog(context, Icons.error_outline, "Please log in to dislike posts.", success: false);
      return;
    }
    final postRef = FirebaseFirestore.instance.collection('forumPosts').doc(widget.forumPostData.id);
    final String userId = _currentUser!.uid;
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(postRef);
        if (!snapshot.exists) throw Exception("Forum post does not exist!");
        Map<String, dynamic> data = snapshot.data()! as Map<String, dynamic>;
        int newLikeCount = data['likeCount'] ?? 0;
        int newDislikeCount = data['dislikeCount'] ?? 0;
        List<String> likedBy = List<String>.from(data['likedBy'] ?? []);
        List<String> dislikedBy = List<String>.from(data['dislikedBy'] ?? []);
        bool currentlyLiked = likedBy.contains(userId);
        bool currentlyDisliked = dislikedBy.contains(userId);
        if (currentlyDisliked) {
          newDislikeCount--; dislikedBy.remove(userId);
        } else {
          newDislikeCount++; dislikedBy.add(userId);
          if (currentlyLiked) {
            newLikeCount--; likedBy.remove(userId);
          }
        }
        transaction.update(postRef, {
          'likeCount': newLikeCount.clamp(0, double.infinity),
          'dislikeCount': newDislikeCount.clamp(0, double.infinity),
          'likedBy': likedBy,
          'dislikedBy': dislikedBy,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update dislike: $e")));
      }
    }
  }

  void _navigateToDiscussionScreen() {
    final postDataMap = widget.forumPostData.data() as Map<String, dynamic>? ?? {};
    if (postDataMap.isNotEmpty) {
      Get.to(() => DiscussionScreen(forumId: widget.forumPostData.id, initialPostData: postDataMap, initialCommentCount: _commentCount));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not load post data to view discussion.")));
    }
  }

  void _shareForumPost() async {
    final postData = widget.forumPostData.data() as Map<String, dynamic>? ?? {};
    final String content = postData['content'] as String? ?? "Check out this forum post!";
    final String username = postData['username'] as String? ?? "A user";
    final String shareText = '"${content.substring(0, content.length > 100 ? 100 : content.length)}${content.length > 100 ? "..." : ""}"\n- $username on Protogram Forums';
    try {
      await Share.share(shareText, subject: 'Forum Post from Protogram');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not share post.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialData = widget.forumPostData.data() as Map<String, dynamic>? ?? {};
    final String username = initialData['username'] ?? "Unknown User";
    final String profilePicBase64 = initialData['profilePic'] ?? "";
    final String content = initialData['content'] ?? "";
    final dynamic timestamp = initialData['timestamp'];
    final List<String> images = initialData['images'] != null ? List<String>.from(initialData['images']) : [];
    final bool isLoggedIn = _currentUser != null;
    final bool actionsEnabled = isLoggedIn;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: profilePicBase64.isNotEmpty ? MemoryImage(base64Decode(profilePicBase64)) as ImageProvider : const AssetImage("assets/user_profile.png") as ImageProvider,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(_formatTimestamp(timestamp), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (content.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10.0), child: Text(content, style: const TextStyle(fontSize: 15))),
            if (images.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10.0), child: _ImageCarousel(images: images)),
            const Divider(height: 10, thickness: 0.5, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.only(top: 0.0, bottom: 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(_isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, color: actionsEnabled ? (_isLiked ? Theme.of(context).colorScheme.primary : Colors.grey[600]) : Colors.grey[400]),
                        iconSize: 20,
                        tooltip: actionsEnabled ? (_isLiked ? 'Unlike' : 'Like') : 'Log in to like',
                        onPressed: actionsEnabled ? _toggleLikeForum : null,
                        padding: EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 2),
                      Text(_likeCount.toString(), style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(_isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined, color: actionsEnabled ? (_isDisliked ? Colors.redAccent : Colors.grey[600]) : Colors.grey[400]),
                        iconSize: 20,
                        tooltip: actionsEnabled ? (_isDisliked ? 'Remove Dislike' : 'Dislike') : 'Log in to dislike',
                        onPressed: actionsEnabled ? _toggleDislikeForum : null,
                        padding: EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 2),
                      Text(_dislikeCount.toString(), style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(Icons.mode_comment_outlined, color: Colors.grey[600], size: 20),
                        tooltip: 'View Discussion',
                        onPressed: _navigateToDiscussionScreen,
                        padding: EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 2),
                      Text(_commentCount.toString(), style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    iconSize: 20,
                    color: Colors.grey[600],
                    tooltip: 'Share Post',
                    onPressed: _shareForumPost,
                    padding: EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      return const SizedBox.shrink();
    }
    final bool hasMultiple = widget.images.length > 1;
    double aspectRatio = 16 / 9;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              if (mounted) {
                setState(() => _currentPage = index);
              }
            },
            itemBuilder: (context, index) {
              try {
                final imageBytes = base64Decode(widget.images[index]);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey[500], size: 40)),
                      );
                    },
                  ),
                );
              } catch (e) {
                return Container(
                  color: Colors.grey[200],
                  child: Center(child: Icon(Icons.error_outline, color: Colors.red[300], size: 40)),
                );
              }
            },
          ),
          if (hasMultiple)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                child: Text('${_currentPage + 1}/${widget.images.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
          if (hasMultiple)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (idx) {
                  return Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _currentPage == idx ? Theme.of(context).colorScheme.primary : Colors.grey[400]?.withOpacity(0.8)),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
