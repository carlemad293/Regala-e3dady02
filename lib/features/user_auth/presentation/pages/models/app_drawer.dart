import 'dart:async';
import 'dart:ui'; // For BackdropFilter

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:regala_e3dady/features/app/theme/theme_provider.dart';
import '../account_page.dart';
import '../help_page.dart';
import '../home_page.dart';
import '../points_page.dart' show PointScreen;
import '../dawra_organizer_screen.dart';

class AppDrawer extends StatefulWidget {
  final User user;

  const AppDrawer({Key? key, required this.user}) : super(key: key);

  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? imageUrl;
  bool isLoading = true;
  StreamSubscription<DocumentSnapshot>? _imageSubscription;

  @override
  void initState() {
    super.initState();
    _listenForDrawerImageChanges();
  }

  @override
  void dispose() {
    _imageSubscription?.cancel();
    super.dispose();
  }

  void _listenForDrawerImageChanges() async {
    final prefs = await SharedPreferences.getInstance();
    _imageSubscription = FirebaseFirestore.instance
        .collection('resources')
        .doc('drawer_header')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final newUrl = snapshot['imageUrl'] ?? '';
        final cachedUrl = prefs.getString('drawer_image_url');

        if (newUrl.isNotEmpty && newUrl != cachedUrl) {
          setState(() => imageUrl = newUrl);
          prefs.setString('drawer_image_url', newUrl);
        } else if (cachedUrl != null) {
          setState(() => imageUrl = cachedUrl);
        }
      } else {
        setState(() => imageUrl = null);
      }
      setState(() => isLoading = false);
    }, onError: (error) {
      print('Error fetching image: $error');
      setState(() {
        imageUrl = null;
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topRight: Radius.circular(16.r),
        bottomRight: Radius.circular(16.r),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Drawer(
          backgroundColor: isDark
              ? Colors.black.withOpacity(0.3)
              : Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(16.r),
              bottomRight: Radius.circular(16.r),
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 250.h,
                child: DrawerHeader(
                  decoration: BoxDecoration(
                    image: imageUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(imageUrl!),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.3),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                    color: imageUrl == null ? Colors.blue.shade900 : null,
                  ),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.zero,
                  margin: EdgeInsets.zero,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      'Regala E3dady',
                      style: TextStyle(
                        fontSize: 25.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(2.w, 2.h),
                            blurRadius: 25.r,
                            color: Colors.white,
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildEmojiTile(
                      emoji: '🏠',
                      title: 'Home',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                HomeScreen(user: widget.user, points: 0),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                    const Divider(),
                    _buildEmojiTile(
                      emoji: '👤',
                      title: 'Account',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AccountScreen(user: widget.user),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    _buildEmojiTile(
                      emoji: '❓',
                      title: 'Help',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => HelpScreen()),
                        );
                      },
                    ),
                    const Divider(),
                    _buildEmojiTile(
                      emoji: '💰',
                      title: 'Points',
                      onTap: () async {
                        Navigator.pop(context);
                        bool isAdmin =
                            await _checkIfAdmin(widget.user.email ?? '');
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PointScreen(isAdmin: isAdmin),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    _buildEmojiTile(
                      emoji: '📁',
                      title: 'Resources',
                      onTap: () async {
                        Navigator.pop(context);
                        final url = await _getGoogleDriveLink();
                        if (await canLaunch(url)) {
                          await launch(url);
                        } else {
                          print('Could not launch $url');
                        }
                      },
                    ),
                    const Divider(),
                    _buildEmojiTile(
                      emoji: '🎮',
                      title: 'Organizer',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => DawraOrganizerScreen()),
                        );
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text(
                        'Dark Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      secondary: Icon(
                        themeProvider.themeMode == ThemeMode.dark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        size: 24,
                        color: Colors.white70,
                      ),
                      value: themeProvider.themeMode == ThemeMode.dark,
                      onChanged: (bool value) {
                        themeProvider.toggleTheme();
                      },
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiTile({
    required String emoji,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Text(
        emoji,
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Future<bool> _checkIfAdmin(String? email) async {
    if (email == null) return false;
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(email)
          .get();
      return adminDoc.exists;
    } catch (e) {
      print('Admin check failed: $e');
      return false;
    }
  }

  Future<String> _getGoogleDriveLink() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('resources')
          .doc('google_drive_link')
          .get();
      return doc.exists ? doc['link'] : 'https://drive.google.com/';
    } catch (e) {
      print('Google Drive link fetch error: $e');
      return 'https://drive.google.com/';
    }
  }
}
