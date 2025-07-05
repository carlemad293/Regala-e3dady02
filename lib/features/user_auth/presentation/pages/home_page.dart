import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // Add Timer import
import 'dart:ui'; // Add ImageFilter import
import 'dart:convert'; // Add jsonEncode import
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'account_page.dart';
import 'help_page.dart';
import 'points_page.dart' show PointScreen;
import 'models/activity.dart';
import 'models/app_drawer.dart';
import 'dawra_organizer_screen.dart';
import 'admin_tools_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final int points;

  HomeScreen({
    required this.user,
    required this.points,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  bool _isLoading = true;
  double psalmFontSize = 17.0; // Add font size state

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.email)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userName = data['name'] as String? ?? '';
            _isLoading = false;
            psalmFontSize = data['psalmFontSize'] as double? ?? 17.0;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveFontSize(double fontSize) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.email)
          .update({
        'psalmFontSize': fontSize,
      });
    } catch (e) {
      print('Error saving psalm font size: $e');
    }
  }

  void _copyPsalmContent(String title, String content) {
    final fullText = '$title\n\n$content';
    Clipboard.setData(ClipboardData(text: fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Psalm content copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: isDark ? Colors.white : Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline,
                color: isDark ? Colors.white : Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                _createFadeTransitionRoute(AccountScreen(user: widget.user)),
              );
            },
          ),
        ],
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.white),
      ),
      drawer: AppDrawer(user: widget.user),
      body: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/crosses_bg.png'),
                  fit: BoxFit.cover,
                  opacity: isDark ? 0.15 : 0.25,
                ),
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.35),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        AnimatedOpacity(
                          duration: Duration(milliseconds: 300),
                          opacity: _isLoading ? 0.0 : 1.0,
                          child: Text(
                            'Hello, $_userName',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: 200,
                    height: 2,
                    color: isDark
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.3),
                  ),
                  SizedBox(height: 8),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    padding: EdgeInsets.all(16),
                    child: InkWell(
                      onTap: () {
                        _showAnnouncementsDialog(context);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blue[900]!.withOpacity(0.3)
                              : Colors.blue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications,
                              color:
                                  isDark ? Colors.blue[200] : Colors.blue[700],
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'View Announcements',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('announcements')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return SizedBox();

                                final allAnnouncements = snapshot.data!.docs;
                                final readAnnouncements =
                                    allAnnouncements.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final readBy =
                                      data['readBy'] as List<dynamic>? ?? [];
                                  return readBy.contains(widget.user.email);
                                }).toList();

                                final int unreadCount =
                                    allAnnouncements.length -
                                        readAnnouncements.length;

                                if (unreadCount > 0) {
                                  return Container(
                                    margin: EdgeInsets.only(left: 8),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$unreadCount New',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }

                                return SizedBox();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: isDark
                        ? Color(0xFF2A2A2A).withOpacity(0.2)
                        : Colors.white.withOpacity(0.2),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: isDark ? Colors.white : Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Today\'s Date',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy')
                                .format(DateTime.now()),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          CopticDateWidget(),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  TodayEventsCard(),
                  SizedBox(height: 8),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: isDark
                        ? Color(0xFF2A2A2A).withOpacity(0.2)
                        : Colors.white.withOpacity(0.2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(Icons.drive_file_move,
                                  color: isDark ? Colors.white : Colors.white,
                                  size: 28),
                              onPressed: () async {
                                String googleDriveLink =
                                    await _getGoogleDriveLink();
                                if (await canLaunch(googleDriveLink)) {
                                  await launch(googleDriveLink);
                                } else {
                                  print('Could not launch $googleDriveLink');
                                }
                              },
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.5),
                            ),
                            IconButton(
                              icon: Icon(Icons.stars,
                                  color: isDark ? Colors.white : Colors.white,
                                  size: 28),
                              onPressed: () async {
                                bool isAdmin = await _checkIfAdmin(
                                    widget.user.email ?? '');
                                Navigator.push(
                                  context,
                                  _createFadeTransitionRoute(
                                      PointScreen(isAdmin: isAdmin)),
                                );
                              },
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.5),
                            ),
                            IconButton(
                              icon: Icon(Icons.sports_esports,
                                  color: isDark ? Colors.white : Colors.white,
                                  size: 28),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  _createFadeTransitionRoute(
                                      DawraOrganizerScreen()),
                                );
                              },
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.5),
                            ),
                            IconButton(
                              icon: Icon(Icons.sports_soccer,
                                  color: isDark ? Colors.white : Colors.white,
                                  size: 28),
                              onPressed: () {
                                _showPsalmDialog(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Admin Tools Button
          if (widget.user.email != null)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('admins')
                      .doc(widget.user.email)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox.shrink();
                    }
                    if (snapshot.hasData &&
                        snapshot.data != null &&
                        snapshot.data!.exists) {
                      return FloatingActionButton(
                        heroTag: 'adminFAB',
                        backgroundColor: isDark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.black.withOpacity(0.4),
                        child: Icon(Icons.admin_panel_settings,
                            color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            _createFadeTransitionRoute(AdminToolsScreen()),
                          );
                        },
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              ),
            ),
          // Help Button
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FloatingActionButton(
                heroTag: 'helpFAB',
                backgroundColor: isDark
                    ? Colors.black.withOpacity(0.5)
                    : Colors.black.withOpacity(0.4),
                child: Icon(Icons.help_outline, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    _createFadeTransitionRoute(HelpScreen()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonCard({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark
          ? Color(0xFF2A2A2A).withOpacity(0.2)
          : Colors.white.withOpacity(0.2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 200,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isDark ? Colors.white : Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom transition function for fade animation
  Route _createFadeTransitionRoute(Widget page) {
    return MaterialPageRoute(
      builder: (context) => page,
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
      print('Error checking admin status: $e');
      return false;
    }
  }

  Future<String> _getGoogleDriveLink() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('resources')
          .doc('google_drive_link')
          .get();

      if (doc.exists) {
        return doc['link'];
      } else {
        return 'https://drive.google.com/drive/';
      }
    } catch (e) {
      print('Error fetching Google Drive link: $e');
      return 'https://drive.google.com/drive/';
    }
  }

  void _showAnnouncementsDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              EdgeInsets.symmetric(horizontal: 20, vertical: 24), // 90% width
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.90,
                constraints: BoxConstraints(
                  maxWidth: 600,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.18)
                        : Colors.black.withOpacity(0.08),
                    width: 1.5,
                  ),
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.95),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.4)
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 32,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue[900]!.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.notifications,
                                  color: isDark
                                      ? Colors.blue[200]
                                      : Colors.blue[700],
                                  size: 24,
                                ),
                                onPressed: null, // Decorative, no action
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                disabledColor: isDark
                                    ? Colors.blue[200]
                                    : Colors.blue[700],
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Announcements',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                color:
                                    isDark ? Colors.white70 : Colors.black54),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                    // Content (no Flexible)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('announcements')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                              child: Text(
                            'Error loading announcements',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_off,
                                      size: 48,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black38),
                                  SizedBox(height: 16),
                                  Text(
                                    'No announcements yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          padding:
                              EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final doc = snapshot.data!.docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final timestamp =
                                (data['timestamp'] as Timestamp).toDate();
                            final List<dynamic> readBy = data['readBy'] ?? [];
                            final bool isUnread =
                                !readBy.contains(widget.user.email);

                            // Mark as read if unread
                            if (isUnread) {
                              FirebaseFirestore.instance
                                  .collection('announcements')
                                  .doc(doc.id)
                                  .update({
                                'readBy':
                                    FieldValue.arrayUnion([widget.user.email])
                              });
                            }

                            return Container(
                              width: double.infinity,
                              margin: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Card(
                                elevation: 10,
                                color: isDark
                                    ? Colors.white.withOpacity(0.10)
                                    : Colors.white.withOpacity(0.85),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.13)
                                        : Colors.black.withOpacity(0.07),
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(20, 20, 20, 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  data['title'] ?? '',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                  ),
                                                  textAlign: _isArabicText(
                                                          data['title'] ?? '')
                                                      ? TextAlign.right
                                                      : TextAlign.left,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            data['content'] ?? '',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              height: 1.5,
                                            ),
                                            textAlign: _isArabicText(
                                                    data['content'] ?? '')
                                                ? TextAlign.right
                                                : TextAlign.justify,
                                          ),
                                          SizedBox(height: 14),
                                          Text(
                                            DateFormat('MMM d, yyyy • h:mm a')
                                                .format(timestamp),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black54,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isUnread)
                                      Positioned(
                                        top: 14,
                                        right: 14,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    Colors.red.withOpacity(0.3),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            'New',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Function to detect if text contains Arabic characters
  bool _isArabicText(String text) {
    return RegExp(
            r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]')
        .hasMatch(text);
  }

  void _showPsalmDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('mazmour_el_kora')
              .doc('content')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AlertDialog(
                title: Text('Error'),
                content: Text('Failed to load psalm content'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('OK'),
                  ),
                ],
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                content: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snapshot.data?.data() as Map<String, dynamic>?;
            final title = data?['title'] as String? ?? '';
            final content = data?['content'] as String? ?? '';

            // Check if there's no content
            final hasContent =
                (title.isNotEmpty == true || content.isNotEmpty == true);

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.90,
                        constraints: BoxConstraints(
                          maxWidth: 600,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.18)
                                : Colors.black.withOpacity(0.08),
                            width: 1.5,
                          ),
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.white.withOpacity(0.95),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withOpacity(0.4)
                                  : Colors.black.withOpacity(0.08),
                              blurRadius: 32,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 18),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.green[900]!.withOpacity(0.18)
                                    : Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.sports_soccer,
                                        color: isDark
                                            ? Colors.green[300]
                                            : Colors.green[700],
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Psalm',
                                        style: GoogleFonts.poppins(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            ),
                            // Content
                            Flexible(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(24),
                                child: hasContent
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Title
                                          SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              title,
                                              style: GoogleFonts.poppins(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: _isArabicText(title)
                                                  ? TextAlign.right
                                                  : TextAlign.left,
                                            ),
                                          ),
                                          SizedBox(height: 20),
                                          // Separator
                                          Container(
                                            height: 1,
                                            color: isDark
                                                ? Colors.white.withOpacity(0.2)
                                                : Colors.black.withOpacity(0.1),
                                          ),
                                          SizedBox(height: 24),
                                          // Content
                                          Text(
                                            content,
                                            style: GoogleFonts.poppins(
                                              fontSize: psalmFontSize,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                              height: 1.8,
                                              letterSpacing: 0.3,
                                            ),
                                            textAlign: _isArabicText(content)
                                                ? TextAlign.right
                                                : TextAlign.justify,
                                          ),
                                        ],
                                      )
                                    : Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.book_outlined,
                                              size: 64,
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black38,
                                            ),
                                            SizedBox(height: 16),
                                            Text(
                                              'No psalm yet',
                                              style: GoogleFonts.poppins(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black54,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Check back later for updates',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                            // Fixed Control Bar
                            if (hasContent)
                              Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.green[900]!.withOpacity(0.18)
                                      : Colors.green.withOpacity(0.12),
                                  borderRadius: BorderRadius.vertical(
                                      bottom: Radius.circular(24)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Font Size Controls
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.remove,
                                            color: isDark
                                                ? Colors.blue[300]
                                                : Colors.blue[600],
                                            size: 20,
                                          ),
                                          onPressed: () async {
                                            if (psalmFontSize > 12) {
                                              setState(() {
                                                psalmFontSize--;
                                              });
                                              setDialogState(() {});
                                              await _saveFontSize(
                                                  psalmFontSize);
                                            }
                                          },
                                          style: IconButton.styleFrom(
                                            backgroundColor: isDark
                                                ? Colors.blue.withOpacity(0.1)
                                                : Colors.blue.withOpacity(0.05),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.grey[800]
                                                : Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${psalmFontSize.round()}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(
                                            Icons.add,
                                            color: isDark
                                                ? Colors.blue[300]
                                                : Colors.blue[600],
                                            size: 20,
                                          ),
                                          onPressed: () async {
                                            if (psalmFontSize < 32) {
                                              setState(() {
                                                psalmFontSize++;
                                              });
                                              setDialogState(() {});
                                              await _saveFontSize(
                                                  psalmFontSize);
                                            }
                                          },
                                          style: IconButton.styleFrom(
                                            backgroundColor: isDark
                                                ? Colors.blue.withOpacity(0.1)
                                                : Colors.blue.withOpacity(0.05),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Copy Button
                                    IconButton(
                                      icon: Icon(
                                        Icons.copy,
                                        color: isDark
                                            ? Colors.green[300]
                                            : Colors.green[600],
                                        size: 24,
                                      ),
                                      onPressed: () =>
                                          _copyPsalmContent(title, content),
                                      style: IconButton.styleFrom(
                                        backgroundColor: isDark
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.green.withOpacity(0.05),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
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
}

class CopticDateWidget extends StatefulWidget {
  @override
  _CopticDateWidgetState createState() => _CopticDateWidgetState();
}

class _CopticDateWidgetState extends State<CopticDateWidget> {
  String _copticDate = '';
  Timer? _updateTimer; // Add timer variable

  @override
  void initState() {
    super.initState();
    _updateDates();
    _updateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        // Check if widget is still mounted
        _updateDates();
      } else {
        timer.cancel(); // Cancel timer if widget is disposed
      }
    });
  }

  void _updateDates() {
    final now = DateTime.now();
    final copticDate = _convertToCopticDate(now);
    if (mounted) {
      // Check if widget is still mounted before setState
      setState(() {
        _copticDate = copticDate;
      });
    }
  }

  String _convertToCopticDate(DateTime date) {
    // Constants for Coptic calendar
    final COPTIC_EPOCH = 1824665; // Julian day number for 1 Thout 1 AM
    final COPTIC_MONTHS = [
      'Toot',
      'Baba',
      'Hatoor',
      'Kiahk',
      'Tooba',
      'Amshir',
      'Baramhat',
      'Baramouda',
      'Bashans',
      'Baouna',
      'Abeeb',
      'Mesra'
    ];

    // Convert Gregorian to Julian Day Number
    int a = ((14 - date.month) / 12).floor();
    int y = date.year + 4800 - a;
    int m = date.month + 12 * a - 3;
    int jdn = date.day +
        ((153 * m + 2) / 5).floor() +
        365 * y +
        (y / 4).floor() -
        (y / 100).floor() +
        (y / 400).floor() -
        32045;

    // Convert Julian Day Number to Coptic date
    int copticJdn = jdn - COPTIC_EPOCH;
    int copticYear = (copticJdn / 365.25).floor();
    int copticDayOfYear = copticJdn - (copticYear * 365.25).floor();
    int copticMonth = (copticDayOfYear / 30).floor() + 1;
    int copticDay = copticDayOfYear - (copticMonth - 1) * 30 + 1;

    // Handle the 13th month (Nasie)
    if (copticMonth == 13) {
      copticMonth = 12;
      copticDay += 5;
    }

    // Get the Coptic month name
    String copticMonthName = COPTIC_MONTHS[copticMonth - 1];

    // Format the date
    return '${copticDay} $copticMonthName $copticYear';
  }

  @override
  void dispose() {
    _updateTimer?.cancel(); // Cancel timer in dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Text(
      _copticDate,
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: isDark ? Colors.white : Colors.white,
      ),
    );
  }
}

class TodayEventsCard extends StatefulWidget {
  @override
  _TodayEventsCardState createState() => _TodayEventsCardState();
}

class _TodayEventsCardState extends State<TodayEventsCard> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolledToBottom = false;
  bool _allEventsVisible = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadEventsForDate(_selectedDate);
    _scrollController.addListener(_checkScrollPosition);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScrollPosition() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      setState(() {
        _isScrolledToBottom = true;
      });
    } else {
      setState(() {
        _isScrolledToBottom = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: isDark ? Colors.blue[700]! : Colors.blue,
              onPrimary: Colors.white,
              surface: isDark ? Color(0xFF2A2A2A) : Colors.white,
              onSurface: isDark ? Colors.white : Colors.black87,
            ),
            dialogTheme: DialogThemeData(
                backgroundColor: isDark ? Color(0xFF2A2A2A) : Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      _loadEventsForDate(_selectedDate);
    }
  }

  Future<void> _loadEventsForDate(DateTime date) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final startTimestamp = Timestamp.fromDate(startOfDay);
      final endTimestamp = Timestamp.fromDate(endOfDay);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThan: endTimestamp)
          .orderBy('date')
          .get();

      if (mounted) {
        setState(() {
          _events = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] as String? ?? 'Unnamed Event',
              'time': (data['date'] as Timestamp).toDate(),
              'description': data['description'] as String? ?? '',
              'endTime': data['endTime'] != null
                  ? (data['endTime'] as Timestamp).toDate()
                  : null,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading events: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _events = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark
          ? Color(0xFF2A2A2A).withOpacity(0.2)
          : Colors.white.withOpacity(0.2),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      color: isDark ? Colors.white : Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Events',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: Icon(
                    Icons.calendar_today,
                    color: isDark ? Colors.white : Colors.white,
                    size: 16,
                  ),
                  label: Text(
                    DateFormat('MMM d, yyyy').format(_selectedDate),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () => _selectDate(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? Colors.white : Colors.white,
                      ),
                    ),
                  )
                : _events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              color: isDark ? Colors.white54 : Colors.white54,
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No events for ${DateFormat('MMMM d').format(_selectedDate)}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: isDark ? Colors.white54 : Colors.white54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Container(
                        constraints: BoxConstraints(
                          maxHeight: 200,
                        ),
                        child: Stack(
                          children: [
                            NotificationListener<ScrollNotification>(
                              onNotification: (scrollNotification) {
                                if (scrollNotification
                                    is ScrollEndNotification) {
                                  setState(() {
                                    _allEventsVisible = _events.length <= 3 ||
                                        _isScrolledToBottom;
                                  });
                                }
                                return false;
                              },
                              child: Scrollbar(
                                controller: _scrollController,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  itemCount: _events.length,
                                  shrinkWrap: true,
                                  padding: EdgeInsets.only(bottom: 24),
                                  itemBuilder: (context, index) {
                                    return InkWell(
                                      onTap: () {
                                        // Refresh events when tapped
                                        _loadEventsForDate(_selectedDate);
                                      },
                                      child: Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 4),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          color: index % 2 == 0
                                              ? (isDark
                                                  ? Colors.white
                                                      .withOpacity(0.05)
                                                  : Colors.black
                                                      .withOpacity(0.05))
                                              : Colors.transparent,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      DateFormat('h:mm a')
                                                          .format(_events[index]
                                                              ['time']),
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    if (_events[index]
                                                            ['endTime'] !=
                                                        null)
                                                      Text(
                                                        'to ${DateFormat('h:mm a').format(_events[index]['endTime'])}',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          color: Colors.white70,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _events[index]['name'],
                                                      style:
                                                          GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    if (_events[index]
                                                            ['description']
                                                        .isNotEmpty)
                                                      Text(
                                                        _events[index]
                                                            ['description'],
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          color: Colors.white70,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            if (!_allEventsVisible && _events.length > 3)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        isDark
                                            ? Color(0xFF2A2A2A).withOpacity(0.8)
                                            : Colors.white.withOpacity(0.8),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.white54,
                                    ),
                                  ),
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
}

void sendRequestToAdmin(Activity activity) async {
  final url = Uri.parse('https://your-api-endpoint.com/request-points');
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode(activity.toJson()),
  );

  if (response.statusCode == 200) {
    print('Request sent successfully');
  } else {
    print('Failed to send request');
  }
}
