import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'CreatePostScreen.dart';
import 'CreateStartupScreen.dart';
import 'account_settings_screen.dart';
import 'create_forum_post_screen.dart';
import 'feed_screen.dart';
import 'forum_screen.dart';
import 'startup_detail_screen.dart';

class StartupsScreen extends StatefulWidget {
  const StartupsScreen({Key? key}) : super(key: key);

  @override
  State<StartupsScreen> createState() => _StartupsScreenState();
}

class _StartupsScreenState extends State<StartupsScreen> {
  /* ───────────────────────────── state ───────────────────────────── */
  final _auth = FirebaseAuth.instance;
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  User? get _user => _auth.currentUser;

  String? _profilePicBase64;
  String _query = '';
  bool _showMenu = false;
  bool _onlyMine = false;                 //  <-- NEW (tab state)

  /* ───────────────────────────── firestore ───────────────────────── */
  Stream<QuerySnapshot<Map<String, dynamic>>> _baseStream() =>
      FirebaseFirestore.instance
          .collection('startups')
          .where('status', isEqualTo: 'Approved')
          .snapshots();

  /* ───────────────────────── lifecycle ──────────────────────────── */
  @override
  void initState() {
    super.initState();
    if (_user != null) _loadUserProfile();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    if (!mounted) return;
    setState(() => _profilePicBase64 =
    (snap.data()?['profilePic'] ?? '') as String?);
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

  /* ───────────────────────── helpers ────────────────────────────── */
  void _toggleMenu() => setState(() => _showMenu = !_showMenu);

  void _handleMenuSelection(Widget page) {
    _toggleMenu();
    Get.to(() => page);
  }

  /* ───────────────────────── UI widgets ─────────────────────────── */

  ///  flat two‑button row
  Widget _filterTabs() {
    final theme = Theme.of(context); // Get theme once
    final colorScheme = theme.colorScheme; // Get colorScheme

    // Active color: Use primary from ColorScheme for better theme consistency
    final activeClr = colorScheme.primary;

    // Inactive color: Use onSurface from ColorScheme, which adapts to light/dark theme
    // onSurface is usually white in dark theme and black in light theme.
    final inactiveClr = colorScheme.onSurface.withOpacity(0.6); // Maintain some dimming

    Widget tab(String label, bool active, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4), // Optional: for ripple effect
        child: Container(
          height: 42, // Or 48 for Material default tap target size
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: active ? activeClr : Colors.transparent, width: 2.5), // Slightly thinner border
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: active ? FontWeight.bold : FontWeight.w500, // Use w500 for normal for better readability
              color: active ? activeClr : inactiveClr,
              fontSize: 15, // Slightly larger font size
            ),
          ),
        ),
      ),
    );

    return Container( // Optional: Add a subtle background or border to the Row
      // decoration: BoxDecoration(
      //   border: Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      // ),
      child: Row(
        children: [
          tab('All Startups', !_onlyMine, () => setState(() => _onlyMine = false)),
          tab('My Startups', _onlyMine, () => setState(() => _onlyMine = true)),
        ],
      ),
    );
  }


  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Search startups…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _searchCtrl.clear();
            setState(() => _query = '');
            FocusScope.of(context).unfocus();
          },
        )
            : null,
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(240),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
      ),
    ),
  );

  /* ───────────────────────── image builder (unchanged) ──────────── */
  Widget _buildStartupImage(Map<String, dynamic> data) {
    final imageUrl = data['imageUrl'] as String?;
    final images = data['images'] as List?;
    Widget child;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      child = Image.network(imageUrl, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image)));
    } else if (images != null && images.isNotEmpty && images.first is String) {
      try {
        child = Image.memory(base64Decode(images.first), fit: BoxFit.cover);
      } catch (_) {
        child = const Center(child: Icon(Icons.broken_image));
      }
    } else {
      child = const Center(child: Icon(Icons.image_not_supported));
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      child: AspectRatio(aspectRatio: 16 / 12.7, child: child),
    );
  }

  /* ───────────────────────── build ─────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Startups', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: (_profilePicBase64?.isNotEmpty ?? false)
                  ? MemoryImage(base64Decode(_profilePicBase64!))
                  : const AssetImage('assets/user_profile.png') as ImageProvider,
            ),
            onSelected: (v) {
              if (v == 'account_settings') {
                Get.to(() => AccountSettingsScreen());
              } else if (v == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'account_settings', child: Text('Account Settings')),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),

      body: Stack(
        children: [
          Column(
            children: [
              _filterTabs(),   // <── NEW ROW
              _searchBar(),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _baseStream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return const Center(child: Text('Error fetching startups'));
                    }

                    var docs = snap.data?.docs ?? [];

                    // filter by mine
                    if (_onlyMine && _user != null) {
                      docs = docs
                          .where((d) => (d.data()['userId'] ?? '') == _user!.uid)  // <-- use userId
                          .toList();
                    }

                    // filter by search
                    if (_query.isNotEmpty) {
                      docs = docs.where((d) {
                        final m = d.data();
                        final n = (m['name'] ?? '').toString().toLowerCase();
                        final desc = (m['description'] ?? '').toString().toLowerCase();
                        return n.contains(_query) || desc.contains(_query);
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return Center(
                          child: Text(_query.isEmpty
                              ? 'No startups found'
                              : 'No startups found for "$_query"'));
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: GridView.builder(
                        controller: _scroll,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final data = doc.data();
                          final name = data['name'] ?? 'Unnamed';
                          return InkWell(
                            onTap: () =>
                                Get.to(() => StartupDetailScreen(startupId: doc.id)),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 3,
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildStartupImage(data),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          name,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: (data['donationGoal'] ?? 0) > 0
                                              ? (data['donationProgress'] ?? 0) / (data['donationGoal'] ?? 1)
                                              : 0,
                                          backgroundColor: Colors.grey.shade300,
                                          color: Colors.green,
                                          minHeight: 6,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'RM ${(data['donationProgress'] ?? 0).round()} / RM ${(data['donationGoal'] ?? 0).round()}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
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
              : const SizedBox.shrink(),
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

  /* ───────────────── bottom bar / dialogs (unchanged) ─────────── */
  Widget _bottomBar(BuildContext ctx) => BottomAppBar(
    shape: const CircularNotchedRectangle(),
    notchMargin: 8,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _navItem(ctx, Icons.dynamic_feed, FeedScreen()),
        _navItem(ctx, Icons.forum_outlined, ForumScreen()),
        const SizedBox(width: 48),
        _navItem(ctx, Icons.business_center, null, isCurrent: true),
        _navItem(ctx, Icons.settings_outlined, AccountSettingsScreen()),
      ],
    ),
  );

  Widget _navItem(BuildContext ctx, IconData icon, Widget? target,
      {bool isCurrent = false}) {
    final c = isCurrent ? Theme.of(ctx).primaryColor : Colors.grey[600];
    return IconButton(
      icon: Icon(icon, color: c),
      onPressed: target == null ? null : () => Get.to(() => target),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              await _auth.signOut();
              Get.offAllNamed('/');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
}
