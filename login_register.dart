import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'adminApproved.dart';
import 'signup.dart';
import 'wrapper.dart';
import 'editprofile.dart';
import 'login.dart';
import 'package:get/get.dart';
import 'adminlogin.dart';
import 'adminhome.dart';
import 'adminsetting.dart';
import 'adminUsercontrol.dart';
import 'post_status_screen.dart';
import 'theme_controller.dart';
import 'app_settings_screen.dart';  // Make sure this import is correct
import 'CreatePostScreen.dart';
import 'adminAprovementPending.dart';
import 'adminPending.dart';
import 'adminReport.dart';
import 'package:mobile_app_asm/forum_screen.dart';
import 'package:mobile_app_asm/create_forum_post_screen.dart';
import 'adminRejected.dart';


import 'feed_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  await GetStorage.init(); // Ensure GetStorage is initialized
  await Get.putAsync<ThemeController>(() async {
    await GetStorage.init();
    return ThemeController();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ThemeController>(
      builder: (themeController) {
        return GetMaterialApp(
          title: 'Flutter Demo',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeController.themeMode,
          initialRoute: '/',
          getPages: [
            GetPage(name: '/', page: () => const HomePage()),
            GetPage(name: '/wrapper', page: () => const Wrapper()),
            GetPage(name: '/login', page: () => const Login()),
            GetPage(name: '/register', page: () => const Signup()),
            GetPage(name: '/mainpage', page: () => const EditProfile()),
            GetPage(name: '/feed', page: () => FeedScreen()),
            GetPage(name: '/forum', page: () => ForumScreen()),
            GetPage(name: '/createForumPost', page: () => CreateForumPostScreen()),
            GetPage(name: '/editprofile', page: () => EditProfile()),
            GetPage(name: '/poststatus', page: () => PostStatusScreen()),
            GetPage(name: '/settings', page: () => AppSettingsScreen()),
            GetPage(name: '/adminlogin', page: () => const AdminLogin()),
            GetPage(name: '/adminhome', page: () => const AdminHome()),
            GetPage(name: '/adminsetting', page: () => const AdminSetting()),
            GetPage(name: '/adminUsercontrol', page: () => const AdminUserControl()),
            GetPage(name: '/postaprovement', page: () => const AdminPostApproval()),
            GetPage(name: "/adminPending", page: () => const AdminPending()),
            GetPage(name: "/adminApproved", page: () => const AdminApproved()),
            GetPage(name: "/reportedContent", page: () => const AdminReported()),
            GetPage(name: "/adminRejected", page: () => const AdminRejected()),
          ],
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late Animation<double> _buttonOpacityAnimation;
  late Animation<double> _iconRotationAnimation;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _heightAnimation = Tween<double>(begin: 90.0, end: 50.0)
        .animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _buttonOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.3, curve: Curves.easeInOut),
    ));

    _iconRotationAnimation = Tween<double>(begin: 0.0, end: 0.5)
        .animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleContainer() {
    setState(() {
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/Images/wallpaper1.jpg',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                onTap: () {
                  Get.toNamed('/adminlogin');
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 10, right: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.manage_accounts,
                    size: 24,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset(
                      'assets/Images/logoYYY.png',
                      height: 40,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Protogram',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _toggleContainer,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _isExpanded ? 0.5 : 1.0,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.95,
                              height: _heightAnimation.value,
                              margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          Positioned(
                            child: Column(
                              children: [
                                if (_isExpanded)
                                  FadeTransition(
                                    opacity: _buttonOpacityAnimation,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () => Get.to(() => const Login(), transition: Transition.fade),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                side: const BorderSide(color: Colors.black, width: 2),
                                              ),
                                              child: const Text(
                                                'LOG IN',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => Get.to(() => const Signup(), transition: Transition.fade),
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                backgroundColor: Colors.black,
                                              ),
                                              child: const Text(
                                                'REGISTER',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                RotationTransition(
                                  turns: _iconRotationAnimation,
                                  child: const Icon(Icons.expand_more, color: Colors.black, size: 22),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
