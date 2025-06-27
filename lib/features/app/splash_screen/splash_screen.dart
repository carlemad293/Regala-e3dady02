import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:regala_e3dady/features/user_auth/presentation/pages/login_page.dart';
import 'package:regala_e3dady/features/user_auth/presentation/pages/home_page.dart';
import 'package:regala_e3dady/features/app/version_check_service.dart';
import 'package:regala_e3dady/features/app/version_update_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String? imageUrl;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Ensure Firebase is fully initialized before proceeding
      await _ensureFirebaseInitialized();

      await _fetchImageUrl();
      await _checkAuthAndNavigate();
    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        hasError = true;
        errorMessage = 'Failed to initialize app: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _ensureFirebaseInitialized() async {
    int attempts = 0;
    const maxAttempts = 5;

    while (attempts < maxAttempts) {
      try {
        // Check if Firebase is initialized
        Firebase.app();
        print('Firebase is initialized successfully');
        return;
      } catch (e) {
        attempts++;
        print('Firebase initialization attempt $attempts failed: $e');

        if (attempts >= maxAttempts) {
          print('Max attempts reached, proceeding without Firebase');
          return;
        }

        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 1000 * attempts));
      }
    }
  }

  Future<void> _checkAppVersion() async {
    try {
      while (mounted) {
        Map<String, dynamic> versionInfo =
            await VersionCheckService.checkVersion();

        if (versionInfo['needsUpdate'] == true) {
          // Show version update dialog
          if (mounted) {
            bool shouldUpdate = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => VersionUpdateDialog(
                    currentVersion: versionInfo['currentVersion'] ?? '2.0.0',
                    requiredVersion: versionInfo['requiredVersion'] ?? '2.0.0',
                    updateLink: versionInfo['updateLink'] ?? '',
                  ),
                ) ??
                false;

            // If user clicked Update Now, check again after a short delay
            if (shouldUpdate) {
              await Future.delayed(Duration(seconds: 2));
              continue; // Check again
            }
          }
        } else {
          // No update needed, break the loop
          break;
        }
      }
    } catch (e) {
      print('Error checking app version: $e');
      // Continue with app initialization even if version check fails
    }
  }

  Future<void> _checkAuthAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      final secureStorage = FlutterSecureStorage();
      final email = await secureStorage.read(key: 'email');
      final password = await secureStorage.read(key: 'password');

      if (email != null && password != null) {
        try {
          // Check if Firebase is available before trying to use it
          try {
            Firebase.app();
          } catch (e) {
            print('Firebase not available, proceeding to login screen: $e');
            await _navigateToLogin();
            return;
          }

          final userCredential =
              await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          if (userCredential.user != null) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user!.email)
                .get();

            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              final points = userData['points'] ?? 0;

              // Optimized: Reduced from 5 seconds to 2.5 seconds
              await Future.delayed(const Duration(milliseconds: 2500));

              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(
                      user: userCredential.user!,
                      points: points,
                    ),
                  ),
                );
                return;
              }
            }
          }
        } catch (e) {
          print('Auto-login failed: $e');
          await secureStorage.deleteAll();
          await prefs.setBool('isLoggedIn', false);
        }
      }
    }

    await _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    // Optimized: Reduced from 5 seconds to 2.5 seconds
    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInScreen()),
      );
    }
  }

  Future<void> _fetchImageUrl() async {
    try {
      // Check if Firebase is available before trying to use it
      try {
        Firebase.app();
      } catch (e) {
        print('Firebase not available, skipping image fetch: $e');
        setState(() {
          imageUrl = null;
          isLoading = false;
        });
        return;
      }

      if (kIsWeb) {
        print('Fetching fresh image from Firebase for web...');
        final doc = await FirebaseFirestore.instance
            .collection('resources')
            .doc('splash_screen')
            .get();

        if (doc.exists && doc.data()?['imageUrl'] != null) {
          final newUrl = doc.data()!['imageUrl'];
          print('New image URL from Firebase: $newUrl');
          setState(() {
            imageUrl = newUrl;
          });
        } else {
          print('No image URL found in Firebase');
          setState(() {
            imageUrl = null;
          });
        }
      } else {
        // For Android, implement caching
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? cachedUrl = prefs.getString('splash_image_url');
        String? cachedVersion = prefs.getString('splash_image_version');

        try {
          final doc = await FirebaseFirestore.instance
              .collection('resources')
              .doc('splash_screen')
              .get();

          if (doc.exists && doc.data()?['imageUrl'] != null) {
            String newUrl = doc.data()!['imageUrl'];
            String newVersion = doc.data()?['version'] ?? '';

            if (newUrl != cachedUrl || newVersion != cachedVersion) {
              setState(() {
                imageUrl = newUrl;
              });
              prefs.setString('splash_image_url', newUrl);
              prefs.setString('splash_image_version', newVersion);
            } else {
              setState(() {
                imageUrl = cachedUrl;
              });
            }
          }
        } catch (e) {
          print('Error fetching from Firebase, using cached image: $e');
          // If there's an error (no connection), use cached image
          if (cachedUrl != null) {
            setState(() {
              imageUrl = cachedUrl;
            });
          } else {
            setState(() {
              imageUrl = null;
            });
          }
        }
      }
    } catch (e) {
      print('Error in _fetchImageUrl: $e');
      setState(() {
        imageUrl = null;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF121212) : Colors.white,
      body: Stack(
        children: [
          Opacity(
            opacity: isDark ? 0.15 : 0.2,
            child: Image.asset(
              'assets/crosses_bg.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _animation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error: $errorMessage',
                        style: TextStyle(
                            color: isDark ? Colors.red.shade300 : Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Container(
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: MediaQuery.of(context).size.height * 0.6,
                      constraints: const BoxConstraints(
                        maxWidth: 500,
                        maxHeight: 600,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? Colors.white70 : Colors.black,
                          width: 4.0,
                        ),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: imageUrl != null
                            ? (kIsWeb
                                ? Image.network(
                                    imageUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Image loading error: $error');
                                      return Image.asset(
                                        'assets/img_1.png',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      );
                                    },
                                  )
                                : CachedNetworkImage(
                                    imageUrl: imageUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorWidget: (context, url, error) {
                                      print('Image loading error: $error');
                                      return Image.asset(
                                        'assets/img_1.png',
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      );
                                    },
                                  ))
                            : Image.asset(
                                'assets/img_1.png',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
