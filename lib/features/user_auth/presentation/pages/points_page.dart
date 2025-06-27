import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

import 'admin_page.dart';
import 'models/activity.dart';
import 'models/app_drawer.dart';
import 'account_page.dart' show AccountScreen;

class PointScreen extends StatefulWidget {
  final bool isAdmin;

  const PointScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  _PointScreenState createState() => _PointScreenState();
}

class _PointScreenState extends State<PointScreen> {
  final List<Activity> activities = [
    Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userEmail: '',
        name: 'قداس',
        points: 3,
        timestamp: DateTime.now(),
        userName: ''),
    Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userEmail: '',
        name: 'اعتراف',
        points: 5,
        timestamp: DateTime.now(),
        userName: ''),
    Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userEmail: '',
        name: 'اجتماع',
        points: 2,
        timestamp: DateTime.now(),
        userName: ''),
    Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userEmail: '',
        name: 'مزمور الكورة',
        points: 3,
        timestamp: DateTime.now(),
        userName: ''),
    Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userEmail: '',
        name: 'عشية',
        points: 2,
        timestamp: DateTime.now(),
        userName: ''),
    Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userEmail: '',
        name: 'صلاة باكر',
        points: 1,
        timestamp: DateTime.now(),
        userName: ''),
    Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userEmail: '',
        name: 'صلاة نوم',
        points: 1,
        timestamp: DateTime.now(),
        userName: ''),
    Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userEmail: '',
        name: 'إصحاح من الإنجيل',
        points: 1,
        timestamp: DateTime.now(),
        userName: ''),
    Activity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userEmail: '',
        name: 'مهرجان',
        points: 10,
        timestamp: DateTime.now(),
        userName: ''),
  ];

  Activity? selectedActivity;
  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  bool _showCustomFields = false;
  String _userName = '';
  String _message = '';
  bool _isMessageError = false;
  bool _isMessageWarning = false;
  bool _isPending = false;
  Timer? _pendingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isUserBlocked = false;
  StreamSubscription<DocumentSnapshot>? _userStatusSubscription;
  Stream<bool> get _podiumVisibilityStream => FirebaseFirestore.instance
      .collection('settings')
      .doc('podium')
      .snapshots()
      .map((doc) => doc.data()?['showPodiumPoints'] ?? true);

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _setupConnectivityListener();
    _setupUserStatusListener();
  }

  @override
  void dispose() {
    _userStatusSubscription?.cancel();
    _activityController.dispose();
    _pointsController.dispose();
    _pendingTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty &&
          !results.contains(ConnectivityResult.none) &&
          _isPending) {
        _retryPendingRequest();
      }
    });
  }

  void _setupUserStatusListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userStatusSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.email)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          setState(() {
            _isUserBlocked = snapshot.data()?['blocked'] ?? false;
          });
        }
      });
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      // Return true if we have any type of connection
      return connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  Future<void> _retryPendingRequest() async {
    if (_isPending) {
      try {
        final hasInternet = await _checkConnectivity();
        if (!hasInternet) {
          return; // Don't retry if still no internet
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final points = int.tryParse(_pointsController.text) ?? 0;
          final activity = Activity(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userEmail: user.email ?? '',
            name: selectedActivity != null
                ? selectedActivity!.name
                : _activityController.text,
            points:
                selectedActivity != null ? selectedActivity!.points : points,
            timestamp: DateTime.now(),
            isApproved: false,
            userName: _userName,
          );

          await sendRequestToAdmin(activity);
          setState(() {
            _isPending = false;
            _pendingTimer?.cancel();
            _message = 'Request sent successfully';
            _isMessageError = false;
            _isMessageWarning = false;
          });

          // Clear success message after 3 seconds
          Future.delayed(Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _message = '';
              });
            }
          });
        }
      } catch (e) {
        print('Error in retry: $e');
        setState(() {
          _isPending = false;
        });
        _showMessage('Failed to send request', isError: true);
      }
    }
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _userName = userData['userName'] ?? '';
          });
        }
      } catch (e) {
        print('Error loading user name: $e');
      }
    }
  }

  Future<void> _showMessage(String message,
      {bool isError = false, bool isWarning = false}) async {
    if (!mounted) return;

    setState(() {
      _message = message;
      _isMessageError = isError;
      _isMessageWarning = isWarning;
    });

    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _message = '';
        });
      }
    });
  }

  void _toggleCustomFields() {
    setState(() {
      _showCustomFields = !_showCustomFields;
      if (_showCustomFields) {
        selectedActivity = null;
        _activityController.clear();
        _pointsController.clear();
      } else {
        _activityController.clear();
        _pointsController.clear();
      }
    });
  }

  void _validateCustomFields() {
    if (_showCustomFields) {
      if (_activityController.text.trim().isEmpty) {
        _showMessage('Please enter an activity name', isError: true);
        return;
      }
      if (_pointsController.text.trim().isEmpty) {
        _showMessage('Please enter points', isError: true);
        return;
      }
      final points = int.tryParse(_pointsController.text);
      if (points == null || points <= 0) {
        _showMessage('Please enter a valid number of points', isError: true);
        return;
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (_showCustomFields) {
      _validateCustomFields();
      if (_isMessageError) return;
    }

    final points = int.tryParse(_pointsController.text) ?? 0;
    if (selectedActivity != null ||
        (_activityController.text.isNotEmpty && points > 0)) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final activity = Activity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userEmail: user.email ?? '',
          name: selectedActivity != null
              ? selectedActivity!.name
              : _activityController.text,
          points: selectedActivity != null ? selectedActivity!.points : points,
          timestamp: DateTime.now(),
          isApproved: false,
          userName: _userName,
        );

        await sendRequestToAdmin(activity);
        _showMessage('Submitted successfully');
        HapticFeedback.vibrate();

        // Clear fields after successful submission
        setState(() {
          selectedActivity = null;
          _activityController.clear();
          _pointsController.clear();
          _showCustomFields = false;
        });
      } else {
        _showMessage('User not logged in', isError: true);
      }
    } else {
      _showMessage('Please choose an activity or type one with points',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon:
                Icon(Icons.menu, color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.person_outline,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AccountScreen(user: user)),
                );
              }
            },
          ),
        ],
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      drawer: user != null ? AppDrawer(user: user) : null,
      body: Stack(
        children: [
          // Background Image with low opacity
          Opacity(
            opacity: 0.4,
            child: Image.asset(
              'assets/crosses_bg.png',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Theme-aware overlay for better contrast
          Container(
            color: isDark
                ? Colors.black.withOpacity(0.7)
                : Colors.white.withOpacity(0.7),
          ),
          // Main Content
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 100), // Add space for app bar
                // Top Users Card
                widget.isAdmin
                    ? Dismissible(
                        key: ValueKey('podium_card'),
                        direction: DismissDirection.startToEnd,
                        confirmDismiss: (direction) async {
                          final currentVisibility =
                              await _podiumVisibilityStream.first;
                          await FirebaseFirestore.instance
                              .collection('settings')
                              .doc('podium')
                              .set({
                            'showPodiumPoints': !currentVisibility,
                          }, SetOptions(merge: true));
                          return false; // Don't actually dismiss the card
                        },
                        background: StreamBuilder<bool>(
                          stream: _podiumVisibilityStream,
                          builder: (context, snapshot) {
                            final showPoints = snapshot.data ?? true;
                            return Container(
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.only(left: 20.0),
                              color: Colors.blue.withOpacity(0.2),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      isDark ? Color(0xFF2A2A2A) : Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      spreadRadius: 1,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  showPoints
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.blue,
                                  size: 32,
                                ),
                              ),
                            );
                          },
                        ),
                        child: StreamBuilder<bool>(
                          stream: _podiumVisibilityStream,
                          builder: (context, snapshot) {
                            final showPoints = snapshot.data ?? true;
                            return _buildPodiumCard(
                                context, isDark, showPoints);
                          },
                        ),
                      )
                    : StreamBuilder<bool>(
                        stream: _podiumVisibilityStream,
                        builder: (context, snapshot) {
                          final showPoints = snapshot.data ?? true;
                          return _buildPodiumCard(context, isDark, showPoints);
                        },
                      ),
                SizedBox(height: 20),
                // Existing Card
                Center(
                  child: Card(
                    elevation: 6,
                    color: _isUserBlocked
                        ? (isDark ? Color(0xFF3A1A1A) : Color(0xFFFFEBEE))
                        : (isDark ? Color(0xFF2A2A2A) : Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: _isUserBlocked
                          ? BorderSide(
                              color:
                                  isDark ? Colors.red[700]! : Colors.red[300]!,
                              width: 2,
                            )
                          : BorderSide.none,
                    ),
                    child: Stack(
                      children: [
                        if (_isUserBlocked)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.red[900] : Colors.red,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(24),
                                  bottomLeft: Radius.circular(24),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.block,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'BLOCKED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isUserBlocked) ...[
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.red[900]
                                        : Colors.red[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.red[700]!
                                          : Colors.red[200]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.block,
                                        color: isDark
                                            ? Colors.red[300]
                                            : Colors.red,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Your account has been blocked. Please contact an administrator for assistance.',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.red[300]
                                                : Colors.red[900],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8.0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                          color: isDark
                                              ? Colors.grey[700]!
                                              : Colors.grey),
                                    ),
                                    child: DropdownButton<Activity>(
                                      hint: Text('Select Activity',
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black)),
                                      value: selectedActivity,
                                      onChanged: _isUserBlocked
                                          ? null
                                          : (Activity? newValue) {
                                              setState(() {
                                                selectedActivity = newValue;
                                                _showCustomFields = false;
                                              });
                                            },
                                      items:
                                          activities.map((Activity activity) {
                                        return DropdownMenuItem<Activity>(
                                          value: activity,
                                          child: Text(
                                            '${activity.name} (${activity.points} points)',
                                            style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black),
                                          ),
                                        );
                                      }).toList(),
                                      underline: SizedBox(),
                                      borderRadius: BorderRadius.circular(12.0),
                                      dropdownColor: isDark
                                          ? Color(0xFF2A2A2A)
                                          : Colors.white,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                        _showCustomFields
                                            ? Icons.remove_circle_outline
                                            : Icons.add_circle_outline,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    onPressed: _isUserBlocked
                                        ? null
                                        : _toggleCustomFields,
                                  ),
                                ],
                              ),
                              if (_showCustomFields) ...[
                                SizedBox(height: 20),
                                Container(
                                  width: 250,
                                  child: TextField(
                                    controller: _activityController,
                                    enabled: !_isUserBlocked,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black),
                                    decoration: InputDecoration(
                                      labelText: 'Type your activity',
                                      labelStyle: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.grey[700]!
                                                : Colors.grey),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.grey[700]!
                                                : Colors.grey),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.blue[300]!
                                                : Colors.blue),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide:
                                            BorderSide(color: Colors.red),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide:
                                            BorderSide(color: Colors.red),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        if (_isMessageError) {
                                          _message = '';
                                          _isMessageError = false;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(height: 20),
                                Container(
                                  width: 250,
                                  child: TextField(
                                    controller: _pointsController,
                                    enabled: !_isUserBlocked,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Points',
                                      labelStyle: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.grey[700]!
                                                : Colors.grey),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.grey[700]!
                                                : Colors.grey),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.blue[300]!
                                                : Colors.blue),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide:
                                            BorderSide(color: Colors.red),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        borderSide:
                                            BorderSide(color: Colors.red),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        if (_isMessageError) {
                                          _message = '';
                                          _isMessageError = false;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                              SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.send),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isUserBlocked
                                        ? (isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[300])
                                        : (isDark
                                            ? Colors.blue[700]
                                            : Colors.blueAccent),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    textStyle: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed:
                                      _isUserBlocked ? null : _handleSubmit,
                                  label: Text('Submit'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Add extra padding at the bottom to account for the fixed admin button
                if (widget.isAdmin) SizedBox(height: 80),
              ],
            ),
          ),
          // Fixed Admin Panel Button
          if (widget.isAdmin)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      isDark
                          ? Colors.black.withOpacity(0.8)
                          : Colors.white.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      _showPinEntryDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.admin_panel_settings),
                        SizedBox(width: 8),
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_message.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isMessageError
                        ? (isDark
                            ? Colors.red[900]!.withOpacity(0.9)
                            : Colors.red.shade50)
                        : _isMessageWarning
                            ? (isDark
                                ? Colors.amber[900]!.withOpacity(0.9)
                                : Colors.amber.shade50)
                            : (isDark
                                ? Colors.green[900]!.withOpacity(0.9)
                                : Colors.green.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isMessageError
                          ? (isDark ? Colors.red[700]! : Colors.red.shade200)
                          : _isMessageWarning
                              ? (isDark
                                  ? Colors.amber[700]!
                                  : Colors.amber.shade200)
                              : (isDark
                                  ? Colors.green[700]!
                                  : Colors.green.shade200),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMessageError
                              ? Icons.error_outline
                              : _isMessageWarning
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                          color: _isMessageError
                              ? (isDark ? Colors.red[300]! : Colors.red)
                              : _isMessageWarning
                                  ? (isDark ? Colors.amber[300]! : Colors.amber)
                                  : (isDark
                                      ? Colors.green[300]!
                                      : Colors.green),
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _message,
                          style: TextStyle(
                            color: _isMessageError
                                ? (isDark ? Colors.red[300]! : Colors.red)
                                : _isMessageWarning
                                    ? (isDark
                                        ? Colors.amber[300]!
                                        : Colors.amber.shade900)
                                    : (isDark
                                        ? Colors.green[300]!
                                        : Colors.green.shade900),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(BuildContext context, bool isDark,
      [bool showPoints = true]) {
    return Card(
      elevation: 6,
      color: isDark ? Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  '🎖️',
                  style: TextStyle(
                    fontSize: 24,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('points', descending: true)
                  .limit(3)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data?.docs ?? [];
                if (users.isEmpty) {
                  return Text(
                    'No users found',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  );
                }

                // Check if all users have 0 points
                bool allZeroPoints = users.every((user) =>
                    (user.data() as Map<String, dynamic>?)?['points'] == 0 ||
                    (user.data() as Map<String, dynamic>?)?['points'] == null);

                if (allZeroPoints) {
                  return Center(
                    child: Container(
                      height: 180,
                      constraints: BoxConstraints(maxWidth: 300),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '🏆',
                            style: TextStyle(
                              fontSize: 48,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No Points Yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start earning points by completing activities!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  height: 220,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Podium base
                      Container(
                        height: 30,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      // Podium steps
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Second Place
                          if (users.length > 1) ...[
                            Container(
                              width: 80,
                              height: 140,
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: isDark
                                      ? [Color(0xFF2C3E50), Color(0xFF34495E)]
                                      : [Color(0xFF3498DB), Color(0xFF2980B9)],
                                ),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(8)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.workspace_premium,
                                    color: Colors.blue[300],
                                    size: 24,
                                  ),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[600]
                                          : Colors.grey[400],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '2',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    (users[1].data() as Map<String, dynamic>?)?[
                                            'name'] ??
                                        'Unknown',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  (showPoints)
                                      ? Text(
                                          '${(users[1].data() as Map<String, dynamic>?)?['points'] ?? 0} pts',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                            fontSize: 12,
                                          ),
                                        )
                                      : SizedBox.shrink(),
                                ],
                              ),
                            ),
                          ],
                          // First Place
                          Container(
                            width: 100,
                            height: 180,
                            margin: EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isDark
                                    ? [Color(0xFFF1C40F), Color(0xFFF39C12)]
                                    : [Color(0xFFF9E79F), Color(0xFFF1C40F)],
                              ),
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(8)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber[300],
                                  size: 32,
                                ),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.amber[800]
                                        : Colors.amber[200],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '1',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  (users[0].data()
                                          as Map<String, dynamic>?)?['name'] ??
                                      'Unknown',
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                (showPoints)
                                    ? Text(
                                        '${(users[0].data() as Map<String, dynamic>?)?['points'] ?? 0} pts',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                          fontSize: 12,
                                        ),
                                      )
                                    : SizedBox.shrink(),
                              ],
                            ),
                          ),
                          // Third Place
                          if (users.length > 2) ...[
                            Container(
                              width: 80,
                              height: 110,
                              margin: EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: isDark
                                      ? [Color(0xFF7F8C8D), Color(0xFF95A5A6)]
                                      : [Color(0xFFBDC3C7), Color(0xFF95A5A6)],
                                ),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(8)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stars,
                                    color: Colors.grey[400],
                                    size: 24,
                                  ),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[600]
                                          : Colors.grey[400],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '3',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    (users[2].data() as Map<String, dynamic>?)?[
                                            'name'] ??
                                        'Unknown',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  (showPoints)
                                      ? Text(
                                          '${(users[2].data() as Map<String, dynamic>?)?['points'] ?? 0} pts',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                            fontSize: 12,
                                          ),
                                        )
                                      : SizedBox.shrink(),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> sendRequestToAdmin(Activity activity) async {
    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        await firestore.collection('requests').add({
          'userEmail': user.email,
          'userName': activity.userName,
          'name': activity.name,
          'points': activity.points,
          'timestamp': activity.timestamp,
          'isApproved': activity.isApproved,
        });
        print(
            'Request sent to admin: ${activity.name}, ${activity.points} points, ${activity.timestamp}');
      } catch (e) {
        print('Error sending request: $e');
      }
    }
  }

  void _showPinEntryDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminUniversalPointsScreen(),
      ),
    );
  }
}
