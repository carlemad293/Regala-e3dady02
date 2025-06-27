import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models/app_drawer.dart';
import 'dart:convert';
import 'login_page.dart';

class PointsHistory {
  final int points;
  final DateTime timestamp;

  PointsHistory({
    required this.points,
    required this.timestamp,
  });
}

class AccountScreen extends StatefulWidget {
  final User user;

  const AccountScreen({Key? key, required this.user}) : super(key: key);

  @override
  _AccountScreenPageState createState() => _AccountScreenPageState();
}

class _AccountScreenPageState extends State<AccountScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  int _points = 0;
  List<PointsHistory> _pointsHistory = [];
  late DocumentReference _userDoc;
  String? _imageUrl;
  bool _isLoadingImage = false;
  bool _newPointsIndicator = false;
  late SharedPreferences _prefs;
  late AnimationController _snackBarController;
  String _message = '';
  bool _isMessageError = false;
  bool _isMessageWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userDoc =
        FirebaseFirestore.instance.collection('users').doc(widget.user.email);
    _loadPreferences();
    _loadUserData();
    _snackBarController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData(); // Refresh data when dependencies change
  }

  @override
  void dispose() {
    _snackBarController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _newPointsIndicator = _prefs.getBool('newPointsIndicator') ?? false;
  }

  Future<void> _savePreferences() async {
    await _prefs.setBool('newPointsIndicator', _newPointsIndicator);
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _userDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          if (_nameController.text.isEmpty) {
            _nameController.text = data['name'] as String? ?? '';
          }
          _points = data['points'] as int? ?? 0;
          _imageUrl = data['image_url'] as String?;

          // Load points history
          final historyData = data['points_history'] as List<dynamic>? ?? [];
          _pointsHistory = historyData.map((item) {
            final map = item as Map<String, dynamic>;
            return PointsHistory(
              points: map['points'] as int,
              timestamp: (map['timestamp'] as Timestamp).toDate(),
            );
          }).toList();

          // Only modify history if it exists but doesn't start with zero
          if (_pointsHistory.isNotEmpty && _pointsHistory.first.points > 0) {
            // If first entry is not zero, add a zero entry before it
            final firstEntryDate = _pointsHistory.first.timestamp;
            final startDate = firstEntryDate.subtract(Duration(days: 1));
            _pointsHistory.insert(
                0,
                PointsHistory(
                  points: 0,
                  timestamp: startDate,
                ));
          }
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        _showMessage('Failed to load user data', isError: true);
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

  Future<void> _saveUserData() async {
    try {
      await _userDoc.set({
        'name': _nameController.text,
        'points': _points,
        'image_url': _imageUrl,
      }, SetOptions(merge: true));
      _showMessage('Profile updated successfully!');
    } catch (e) {
      _showMessage('Failed to update profile. Please check your connection.',
          isError: true);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(bytes);
        _uploadWebImage(base64Image, pickedFile.name);
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        _showMessage('Failed to pick image. Please try again.', isError: true);
      }
    }
  }

  Future<void> _uploadWebImage(String base64Image, String fileName) async {
    final email = widget.user.email;
    if (email == null) {
      print('User email is null');
      return;
    }

    try {
      setState(() {
        _isLoadingImage = true;
      });

      final storageRef = FirebaseStorage.instance.ref();
      final profileImagesRef = storageRef.child('profile_images/$email.png');

      // Convert base64 to Uint8List
      final imageBytes = base64Decode(base64Image);

      // Upload the file
      final uploadTask = await profileImagesRef.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      // Get download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() {
        _imageUrl = downloadUrl;
        _isLoadingImage = false;
      });

      await _saveUserData();
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isLoadingImage = false;
      });
      if (mounted) {
        _showMessage('Failed to upload image. Please try again.',
            isError: true);
      }
    }
  }

  Future<void> _removeProfileImage() async {
    final email = widget.user.email;
    if (email == null) {
      print('User email is null');
      return;
    }

    try {
      setState(() {
        _isLoadingImage = true;
      });

      // Delete image from Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$email.png');

      await storageRef.delete().catchError((e) {
        // Ignore error if file doesn't exist
        print('Error deleting file: $e');
      });

      // Update user document in Firestore to remove image_url
      await _userDoc.update({'image_url': FieldValue.delete()});

      setState(() {
        _imageUrl = null;
        _isLoadingImage = false;
      });

      _showMessage('Profile picture removed successfully');
    } catch (e) {
      print('Error removing profile image: $e');
      setState(() {
        _isLoadingImage = false;
      });
      if (mounted) {
        _showMessage('Failed to remove profile picture. Please try again.',
            isError: true);
      }
    }
  }

  Future<void> _showFullScreenImage(String imageUrl) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        insetPadding: EdgeInsets.all(0),
        child: Stack(
          children: [
            Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(Icons.error, color: Colors.red, size: 50),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to show options in a bottom sheet
  void _showImageOptions() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Color(0xFF303030) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profile Picture',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.blueAccent),
              title: Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            if (_imageUrl != null) Divider(),
            if (_imageUrl != null)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.redAccent),
                title: Text('Remove current picture'),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfileImage();
                },
              ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : theme.primaryColor,
        ),
      ),
      drawer: AppDrawer(user: widget.user),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Section
                  Card(
                    elevation: 6,
                    color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          AnimatedContainer(
                            duration: Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.15),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                        offset: Offset(0, 8),
                                      ),
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                        offset: Offset(0, 4),
                                      ),
                                      BoxShadow(
                                        color: Colors.blueAccent
                                            .withValues(alpha: 0.2),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                        offset: Offset(0, 0),
                                      ),
                                    ],
                                    border: Border.all(
                                        color: Colors.blueAccent, width: 3),
                                  ),
                                  child: FutureBuilder<void>(
                                    future: _loadUserData(),
                                    builder: (context, snapshot) {
                                      if (_isLoadingImage) {
                                        return CircleAvatar(
                                          radius: 70,
                                          backgroundColor: isDark
                                              ? Color(0xFF3A3A3A)
                                              : Colors.white,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.blueAccent),
                                          ),
                                        );
                                      } else {
                                        return GestureDetector(
                                          onTap: () {
                                            if (_imageUrl != null &&
                                                _imageUrl!.isNotEmpty) {
                                              _showFullScreenImage(_imageUrl!);
                                            }
                                          },
                                          child: CircleAvatar(
                                            radius: 70,
                                            backgroundColor: isDark
                                                ? Color(0xFF3A3A3A)
                                                : Colors.white,
                                            backgroundImage: _imageUrl != null
                                                ? NetworkImage(_imageUrl!)
                                                : AssetImage('assets/img.png')
                                                    as ImageProvider,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _showImageOptions,
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 300),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent
                                            .withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.blueAccent
                                                .withValues(alpha: 0.2),
                                            blurRadius: 8,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: EdgeInsets.all(10),
                                      child: Icon(Icons.edit,
                                          color: Colors.white, size: 22),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 28),
                          TextField(
                            controller: _nameController,
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Name',
                              labelStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black87),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon: Icon(Icons.person_outline,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.blue[300]!
                                        : Colors.blue),
                              ),
                            ),
                          ),
                          SizedBox(height: 14),
                          Text(
                            widget.user.email ?? 'No email',
                            style: TextStyle(
                              fontSize: 15,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.save_alt),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.symmetric(vertical: 14),
                                textStyle: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                await _saveUserData();
                                _loadUserData();
                              },
                              label: Text('Save'),
                            ),
                          ),
                          SizedBox(height: 36),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _newPointsIndicator = false;
                                _savePreferences();
                              });
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: Duration(milliseconds: 300),
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.red[300] : Colors.red,
                                    letterSpacing: 1.1,
                                  ),
                                  child: Text('Points: $_points 🪙'),
                                ),
                                if (_newPointsIndicator)
                                  Positioned(
                                    right: -20,
                                    top: -20,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(milliseconds: 500),
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green
                                                  .withValues(alpha: 0.3),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green
                                                      .withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.arrow_upward,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '$_points',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Add Points Progress Card
                  PointsProgressCard(
                    pointsHistory: _pointsHistory,
                  ),
                ],
              ),
            ),
          ),
          if (_message.isNotEmpty)
            Positioned(
              top: 0,
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
                            ? Colors.red[900]!.withValues(alpha: 0.9)
                            : Colors.red.shade50)
                        : _isMessageWarning
                            ? (isDark
                                ? Colors.amber[900]!.withValues(alpha: 0.9)
                                : Colors.amber.shade50)
                            : (isDark
                                ? Colors.green[900]!.withValues(alpha: 0.9)
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
                        color: Colors.black.withValues(alpha: 0.1),
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
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMessageError
                              ? Icons.error_outline
                              : _isMessageWarning
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                          color: _isMessageError
                              ? (isDark ? Colors.red[300] : Colors.red)
                              : _isMessageWarning
                                  ? (isDark ? Colors.amber[300] : Colors.amber)
                                  : (isDark ? Colors.green[300] : Colors.green),
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _message,
                          style: TextStyle(
                            color: _isMessageError
                                ? (isDark ? Colors.red[300] : Colors.red)
                                : _isMessageWarning
                                    ? (isDark
                                        ? Colors.amber[300]
                                        : Colors.amber.shade900)
                                    : (isDark
                                        ? Colors.green[300]
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(Icons.logout),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.red[900] : Colors.red[200],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.symmetric(vertical: 14),
              textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              try {
                // Clear saved credentials
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                // Sign out from Firebase
                await FirebaseAuth.instance.signOut();

                if (mounted) {
                  // Navigate to login screen
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => SignInScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                print('Logout error: $e');
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => SignInScreen()),
                    (route) => false,
                  );
                }
              }
            },
            label: Text('Log Out'),
          ),
        ),
      ),
    );
  }
}

class PointsProgressCard extends StatelessWidget {
  final List<PointsHistory> pointsHistory;

  const PointsProgressCard({
    Key? key,
    required this.pointsHistory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (pointsHistory.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDark ? Color(0xFF2A2A2A) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No points history available',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ),
      );
    }

    final currentPoints = pointsHistory.last.points;
    final previousPoints = pointsHistory.length > 1
        ? pointsHistory[pointsHistory.length - 2].points
        : 0;
    final pointsDifference = currentPoints - previousPoints;
    final isPositiveChange = pointsDifference >= 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark ? Color(0xFF2A2A2A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Points Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPositiveChange
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pointsDifference >= 0 ? '+' : ''}$pointsDifference',
                    style: TextStyle(
                      color: isPositiveChange ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Container(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: isDark ? Colors.white12 : Colors.black12,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= pointsHistory.length)
                            return const Text('');

                          // Only show date if points changed
                          if (index > 0) {
                            final currentPoints = pointsHistory[index].points;
                            final previousPoints =
                                pointsHistory[index - 1].points;
                            if (currentPoints == previousPoints)
                              return const Text('');
                          }

                          final date = pointsHistory[index].timestamp;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    ...pointsHistory
                        .asMap()
                        .entries
                        .map((entry) {
                          if (entry.key == 0) return null;

                          final currentPoint = entry.value.points.toDouble();
                          final previousPoint =
                              pointsHistory[entry.key - 1].points.toDouble();
                          final isIncreasing = currentPoint >= previousPoint;

                          return LineChartBarData(
                            spots: [
                              FlSpot((entry.key - 1).toDouble(), previousPoint),
                              FlSpot(entry.key.toDouble(), currentPoint),
                            ],
                            isCurved: true,
                            curveSmoothness: 0.7,
                            color: isIncreasing ? Colors.green : Colors.red,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color:
                                      isIncreasing ? Colors.green : Colors.red,
                                  strokeWidth: 2,
                                  strokeColor:
                                      isDark ? Colors.white : Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: (isIncreasing ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.1),
                            ),
                          );
                        })
                        .whereType<LineChartBarData>()
                        .toList(),
                  ],
                  minY: 0,
                  maxY: pointsHistory
                          .map((e) => e.points.toDouble())
                          .reduce((a, b) => a > b ? a : b) *
                      1.1,
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Starting Points',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      pointsHistory.first.points.toString(),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Current Points',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          currentPoints.toString(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (pointsDifference != 0)
                          Text(
                            ' (${pointsDifference >= 0 ? '+' : ''}$pointsDifference)',
                            style: TextStyle(
                              color:
                                  isPositiveChange ? Colors.green : Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
