import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/activity.dart';

class AdminUniversalPointsScreen extends StatefulWidget {
  @override
  _AdminUniversalPointsScreenState createState() =>
      _AdminUniversalPointsScreenState();
}

class _AdminUniversalPointsScreenState
    extends State<AdminUniversalPointsScreen> {
  List<Activity> _pendingRequests = [];
  TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  String _sortOption = 'Name';
  final Map<String, String?> _imageCache = {};
  bool _isDark = false;
  final ImagePicker _picker = ImagePicker();
  String? errorText;
  bool isLoading = false;

  // Add new user role options
  final List<String> _userRoles = ['User', 'Admin'];
  String _selectedRole = 'User';
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDark = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateUserPoints(Activity activity) async {
    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(activity.userEmail);
      final doc = await userDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final currentPoints = data['points'] as int? ?? 0;
        final newPoints = currentPoints + activity.points;

        // Create points history entry
        final historyEntry = {
          'points': newPoints,
          'timestamp': Timestamp.fromDate(DateTime.now()),
        };

        await userDoc.set({
          'points': newPoints,
          'points_history': FieldValue.arrayUnion([historyEntry]),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Failed to update points: $e');
    }
  }

  Future<void> _confirmActivity(Activity activity) async {
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(activity.id)
          .update({
        'isApproved': true,
      });

      await _updateUserPoints(activity);

      setState(() {
        _pendingRequests.remove(activity);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Points successfully added for activity: ${activity.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve activity: $e')),
      );
    }
  }

  Future<void> _denyActivity(Activity activity) async {
    try {
      await FirebaseFirestore.instance
          .collection('requests')
          .doc(activity.id)
          .delete();

      setState(() {
        _pendingRequests.remove(activity);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity denied: ${activity.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to deny activity: $e')),
      );
    }
  }

  void _showEditDialog(
      BuildContext context, String email, String name, int points) {
    TextEditingController _pointsController =
        TextEditingController(text: points.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDark ? Color(0xFF2A2A2A) : Colors.white,
          title: Text('Edit Points for $name',
              style: TextStyle(color: _isDark ? Colors.white : Colors.black)),
          content: TextField(
            controller: _pointsController,
            style: TextStyle(color: _isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'Points',
              labelStyle:
                  TextStyle(color: _isDark ? Colors.white70 : Colors.black87),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: _isDark ? Colors.white30 : Colors.black26),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: _isDark ? Colors.blue[300]! : Colors.blue),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      color: _isDark ? Colors.white70 : Colors.black87)),
            ),
            TextButton(
              onPressed: () async {
                bool confirmed = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor:
                            _isDark ? Color(0xFF2A2A2A) : Colors.white,
                        title: Text(
                          'Confirm Update',
                          style: TextStyle(
                              color: _isDark ? Colors.white : Colors.black),
                        ),
                        content: Container(
                          width: double.maxFinite,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Are you sure you want to update points for $name?',
                                style: TextStyle(
                                    color: _isDark
                                        ? Colors.white70
                                        : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                  color: _isDark
                                      ? Colors.white70
                                      : Colors.black87),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              'Confirm',
                              style: TextStyle(
                                  color:
                                      _isDark ? Colors.blue[300] : Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (confirmed) {
                  try {
                    int newPoints =
                        int.tryParse(_pointsController.text) ?? points;

                    // Create points history entry
                    final historyEntry = {
                      'points': newPoints,
                      'timestamp': Timestamp.fromDate(DateTime.now()),
                    };

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(email)
                        .update({
                      'points': newPoints,
                      'points_history': FieldValue.arrayUnion([historyEntry]),
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Points updated successfully')),
                    );
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update points: $e')),
                    );
                  }
                }
              },
              child: Text('Update',
                  style: TextStyle(
                      color: _isDark ? Colors.blue[300] : Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadProfileImage(String userId) async {
    try {
      // Pick image from gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
        ),
      );

      try {
        // Upload image to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('$userId.png');

        if (kIsWeb) {
          // Web platform
          final bytes = await image.readAsBytes();
          await storageRef.putData(bytes);
        } else {
          // Mobile platform
          final file = File(image.path);
          await storageRef.putFile(file);
        }

        // Get download URL
        final downloadUrl = await storageRef.getDownloadURL();

        // Update user document in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'image_url': downloadUrl});

        // Clear image cache for this user
        _imageCache.remove(userId);

        // Close loading indicator
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // Close loading indicator
        Navigator.pop(context);
        rethrow;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeProfileImage(String userId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          ),
        ),
      );

      try {
        // Delete image from Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('$userId.png');

        await storageRef.delete().catchError((e) {
          // Ignore error if file doesn't exist
          print('Error deleting file: $e');
        });

        // Update user document in Firestore to remove image_url
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'image_url': FieldValue.delete()});

        // Clear image cache for this user
        _imageCache.remove(userId);

        // Close loading indicator
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile picture removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // Close loading indicator
        Navigator.pop(context);
        rethrow;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          color: _isDark ? Colors.blue[300] : Colors.blue,
          size: 20,
        ),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  void _showOptionsDialog(
      BuildContext context, String email, String name, bool isBlocked) {
    TextEditingController _nameController = TextEditingController(text: name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDark ? Color(0xFF2A2A2A) : Colors.white,
          title: Row(
            children: [
              Icon(
                Icons.person_outline,
                color: _isDark ? Colors.blue[300] : Colors.blue,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'User Management',
                  style: TextStyle(
                    color: _isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Header Section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isDark ? Color(0xFF1A1A1A) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Profile Picture
                        FutureBuilder<String?>(
                          future: _getProfileImageUrl(email),
                          builder: (context, snapshot) {
                            return CircleAvatar(
                              radius: 45,
                              backgroundColor:
                                  _isDark ? Colors.blue[900] : Colors.blue[100],
                              backgroundImage:
                                  snapshot.hasData && snapshot.data != null
                                      ? NetworkImage(snapshot.data!)
                                      : null,
                              child: snapshot.hasData && snapshot.data == null
                                  ? Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: _isDark
                                            ? Colors.white
                                            : Colors.blueAccent,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                        SizedBox(height: 12),
                        // User Name
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _isDark ? Colors.white : Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        // User Email
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                _isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // Status Badge
                        if (isBlocked) ...[
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isDark ? Colors.red[900] : Colors.red,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.block,
                                    color: Colors.white, size: 16),
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
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Profile Picture Management Section
                  _buildSectionHeader('Profile Picture', Icons.photo_camera),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.photo_camera, size: 18),
                          label: Text('Change Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isDark ? Colors.blue[900] : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _uploadProfileImage(email);
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: FutureBuilder<String?>(
                          future: _getProfileImageUrl(email),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              return ElevatedButton.icon(
                                icon: Icon(Icons.delete_outline, size: 18),
                                label: Text('Remove'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor:
                                      _isDark ? Colors.red[300] : Colors.red,
                                  side: BorderSide(
                                    color:
                                        _isDark ? Colors.red[300]! : Colors.red,
                                    width: 1,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _removeProfileImage(email);
                                },
                              );
                            }
                            return Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: _isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'No Photo',
                                  style: TextStyle(
                                    color: _isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Name Edit Section
                  _buildSectionHeader('Edit Name', Icons.edit),
                  SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    style:
                        TextStyle(color: _isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      labelText: 'User Name',
                      labelStyle: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black87,
                      ),
                      filled: true,
                      fillColor: _isDark ? Color(0xFF1A1A1A) : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color:
                              _isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color:
                              _isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _isDark ? Colors.teal[300]! : Colors.teal,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // User Actions Section
                  _buildSectionHeader(
                      'User Actions', Icons.admin_panel_settings),
                  SizedBox(height: 12),

                  // Remove Admin Authority Button (if user is admin)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('admins')
                        .doc(email)
                        .snapshots(),
                    builder: (context, adminSnapshot) {
                      if (adminSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return SizedBox.shrink();
                      }
                      if (adminSnapshot.hasData &&
                          adminSnapshot.data != null &&
                          adminSnapshot.data!.exists) {
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.remove_moderator,
                                    color: _isDark
                                        ? Colors.orange[300]
                                        : Colors.orange),
                                label: Text('Remove Admin Authority',
                                    style: TextStyle(
                                        color: _isDark
                                            ? Colors.orange[300]
                                            : Colors.orange)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: _isDark
                                          ? Colors.orange[300]!
                                          : Colors.orange,
                                      width: 2),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                                onPressed: () async {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('admins')
                                        .doc(email)
                                        .delete();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Admin authority removed.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    Navigator.pop(context);
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Error removing admin authority: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            SizedBox(height: 12),
                          ],
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),

                  // Block/Unblock Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                      label: Text(isBlocked ? 'Unblock User' : 'Block User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBlocked
                            ? (_isDark ? Colors.green[900] : Colors.green)
                            : (_isDark ? Colors.red[900] : Colors.red),
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(email)
                              .update({'blocked': !isBlocked});

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isBlocked
                                    ? 'User has been unblocked'
                                    : 'User has been blocked',
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor:
                                  isBlocked ? Colors.green : Colors.red,
                              duration: Duration(seconds: 2),
                            ),
                          );

                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating user status: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  SizedBox(height: 12),

                  // Delete User Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.delete_forever),
                      label: Text('Delete User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: _isDark ? Colors.red[300] : Colors.red,
                        side: BorderSide(
                          color: _isDark ? Colors.red[300]! : Colors.red,
                          width: 2,
                        ),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        bool confirmDelete = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor:
                                    _isDark ? Color(0xFF2A2A2A) : Colors.white,
                                title: Text('Confirm Delete',
                                    style: TextStyle(
                                        color: _isDark
                                            ? Colors.white
                                            : Colors.black)),
                                content: Text(
                                  'Are you sure you want to delete this user? This action cannot be undone.',
                                  style: TextStyle(
                                      color: _isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text('Cancel',
                                        style: TextStyle(
                                            color: _isDark
                                                ? Colors.white70
                                                : Colors.black87)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (confirmDelete) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(email)
                                .delete();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('User has been deleted'),
                                backgroundColor: Colors.green,
                              ),
                            );

                            Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting user: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(
                      color: _isDark ? Colors.white70 : Colors.black87)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(email)
                      .update({'name': _nameController.text});

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Name updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating name: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Save Name',
                  style: TextStyle(
                      color: _isDark ? Colors.blue[300] : Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActivityTile(
      Activity activity, void Function(Activity) onRemove) {
    final formattedDate =
        DateFormat('dd/MM/yyyy – hh:mm a').format(activity.timestamp);

    return Dismissible(
      key: Key(activity.id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          await _denyActivity(activity);
          onRemove(activity);
          return true;
        } else if (direction == DismissDirection.startToEnd) {
          await _confirmActivity(activity);
          onRemove(activity);
          return true;
        }
        return false;
      },
      background: Container(
        color: _isDark ? Colors.green[900] : Colors.green,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            Icon(
              Icons.check,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Text(
              'Accept',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: _isDark ? Colors.red[900] : Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Deny',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.close,
              color: Colors.white,
            ),
          ],
        ),
      ),
      child: Card(
        elevation: 8,
        color: _isDark ? Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: ListTile(
          contentPadding: EdgeInsets.all(15),
          title: Text(
            '${activity.name} (${activity.points} points)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: _isDark ? Colors.white : Colors.black,
            ),
          ),
          subtitle: Text(
            'Submitted by: ${activity.userName}\nSubmitted at: $formattedDate',
            style: TextStyle(
                color: _isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.check,
                    color: _isDark ? Colors.green[300] : Colors.greenAccent),
                onPressed: () async {
                  await _confirmActivity(activity);
                  onRemove(activity);
                },
              ),
              IconButton(
                icon: Icon(Icons.close,
                    color: _isDark ? Colors.red[300] : Colors.redAccent),
                onPressed: () async {
                  await _denyActivity(activity);
                  onRemove(activity);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _highlightText(String text, String query, {bool isName = false}) {
    final theme = Theme.of(context);

    if (query.isEmpty) {
      return Text(
        text,
        style: isName
            ? TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : TextStyle(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black),
      );
    }
    final matches = query.toLowerCase().allMatches(text.toLowerCase());
    if (matches.isEmpty) {
      return Text(
        text,
        style: isName
            ? TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : TextStyle(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black),
      );
    }
    final spans = <TextSpan>[];
    int start = 0;
    for (final match in matches) {
      if (match.start != start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: theme.brightness == Brightness.dark
              ? Colors.amber[900]
              : Colors.yellow,
          color:
              theme.brightness == Brightness.dark ? Colors.white : Colors.black,
        ),
      ));
      start = match.end;
    }
    if (start != text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : Colors.black),
      ));
    }
    return RichText(
      text: TextSpan(
        style: isName
            ? TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : TextStyle(
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black),
        children: spans,
      ),
    );
  }

  Future<String?> _getProfileImageUrl(String userId) async {
    // Check cache first
    if (_imageCache.containsKey(userId)) {
      return _imageCache[userId];
    }

    try {
      // Try to get the image URL from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final imageUrl = userData['image_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _imageCache[userId] = imageUrl;
          return imageUrl;
        }
      }

      // If no image URL in Firestore, try Firebase Storage
      final ref =
          FirebaseStorage.instance.ref().child('profile_images/$userId.png');
      try {
        final url = await ref.getDownloadURL();
        _imageCache[userId] = url;
        return url;
      } catch (e) {
        print('Error getting download URL for user $userId: $e');
        _imageCache[userId] = null;
        return null;
      }
    } catch (e) {
      print('Error accessing storage for user $userId: $e');
      _imageCache[userId] = null;
      return null;
    }
  }

  Widget _buildProfileImage(String email, String name) {
    return FutureBuilder<String?>(
      future: _getProfileImageUrl(email),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.blueAccent),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return CircleAvatar(
            backgroundColor: Colors.blue[100],
            backgroundImage: NetworkImage(snapshot.data!),
            onBackgroundImageError: (exception, stackTrace) {
              print('Error loading image for $email: $exception');
              // Remove from cache on error
              _imageCache.remove(email);
            },
          );
        }

        // Default: first letter
        return CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: Colors.blueAccent)),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getSortedAndFilteredUserList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
      String sortOption,
      String searchText) async {
    List<Map<String, dynamic>> userList = users.map((user) {
      final userData = user.data();
      return {
        'id': user.id,
        'name': userData['name'] ?? 'Unknown',
        'points': userData['points'] ?? 0,
        'blocked': userData['blocked'] ?? false,
        'data': userData,
      };
    }).toList();

    if (searchText.isNotEmpty) {
      final lowerCaseSearchText = searchText.toLowerCase();
      userList = userList.where((user) {
        final name = user['name'].toLowerCase();
        return name.contains(lowerCaseSearchText);
      }).toList();
    }

    if (sortOption == 'Pending Requests') {
      final pendingRequestsSnapshot = await FirebaseFirestore.instance
          .collection('requests')
          .where('isApproved', isEqualTo: false)
          .get();

      final pendingRequestsCount = <String, int>{};
      for (var doc in pendingRequestsSnapshot.docs) {
        final userEmail = doc['userEmail'];
        pendingRequestsCount[userEmail] =
            (pendingRequestsCount[userEmail] ?? 0) + 1;
      }

      userList.sort((a, b) {
        final aCount = pendingRequestsCount[a['id']] ?? 0;
        final bCount = pendingRequestsCount[b['id']] ?? 0;
        return bCount.compareTo(aCount);
      });
    } else {
      switch (sortOption) {
        case 'Newest':
          userList.sort((a, b) {
            final aTimestamp = a['data']['timestamp'] as Timestamp?;
            final bTimestamp = b['data']['timestamp'] as Timestamp?;
            if (aTimestamp == null && bTimestamp == null) return 0;
            if (aTimestamp == null) return 1;
            if (bTimestamp == null) return -1;
            return bTimestamp.compareTo(aTimestamp);
          });
          break;
        case 'Highest Points':
          userList.sort((a, b) {
            final aPoints = a['points'] as int? ?? 0;
            final bPoints = b['points'] as int? ?? 0;
            return bPoints.compareTo(aPoints);
          });
          break;
        case 'Name':
        default:
          userList.sort((a, b) {
            final aName = (a['name'] as String? ?? '').toLowerCase();
            final bName = (b['name'] as String? ?? '').toLowerCase();
            return aName.compareTo(bName);
          });
          break;
      }
    }
    return userList;
  }

  Future<void> _resetAllPoints() async {
    try {
      // Show confirmation dialog
      bool confirmed = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _isDark ? Color(0xFF2A2A2A) : Colors.white,
          title: Text('Reset All Points',
              style: TextStyle(color: _isDark ? Colors.white : Colors.black)),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Are you sure you want to:',
                    style: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Reset all users\' points to 0\n• Clear all points history\n• Delete all pending requests',
                    style: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This action cannot be undone!',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: _isDark ? Colors.white70 : Colors.black87)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Reset All', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
        );

        try {
          // Get all users and pending requests in parallel
          final futures = await Future.wait([
            FirebaseFirestore.instance.collection('users').get(),
            FirebaseFirestore.instance
                .collection('requests')
                .where('isApproved', isEqualTo: false)
                .get(),
          ]);

          final usersSnapshot = futures[0] as QuerySnapshot;
          final requestsSnapshot = futures[1] as QuerySnapshot;

          // Create batches for users and requests
          final userBatch = FirebaseFirestore.instance.batch();
          final requestBatch = FirebaseFirestore.instance.batch();

          // Add user updates to batch
          for (var userDoc in usersSnapshot.docs) {
            userBatch.update(userDoc.reference, {
              'points': 0,
              'points_history': [],
            });
          }

          // Add request deletions to batch
          for (var requestDoc in requestsSnapshot.docs) {
            requestBatch.delete(requestDoc.reference);
          }

          // Commit both batches in parallel
          await Future.wait([
            userBatch.commit(),
            requestBatch.commit(),
          ]);

          // Close loading indicator
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'All users\' points have been reset and pending requests cleared'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          // Close loading indicator if there's an error
          Navigator.pop(context);
          rethrow;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset points: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _blockAllUsers() async {
    try {
      // Check current block status of users
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final adminsSnapshot =
          await FirebaseFirestore.instance.collection('admins').get();
      final adminEmails = adminsSnapshot.docs.map((doc) => doc.id).toSet();

      // Count blocked and unblocked non-admin users
      int blockedCount = 0;
      int totalNonAdminUsers = 0;

      for (var userDoc in usersSnapshot.docs) {
        if (!adminEmails.contains(userDoc.id)) {
          totalNonAdminUsers++;
          if (userDoc.data()['blocked'] == true) {
            blockedCount++;
          }
        }
      }

      // Determine if we should block or unblock based on majority
      final shouldBlock = blockedCount < (totalNonAdminUsers / 2);

      // Show confirmation dialog
      bool confirmed = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _isDark ? Color(0xFF2A2A2A) : Colors.white,
          title: Text(
            shouldBlock ? 'Block All Users' : 'Unblock All Users',
            style: TextStyle(
              color: _isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    shouldBlock ? Icons.block : Icons.lock_open,
                    color: shouldBlock ? Colors.red : Colors.green,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    shouldBlock
                        ? 'Are you sure you want to block all users?'
                        : 'Are you sure you want to unblock all users?',
                    style: TextStyle(
                      color: _isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    shouldBlock
                        ? 'This action will:\n• Block all regular users\n• Admins will not be blocked'
                        : 'This action will:\n• Unblock all regular users\n• Admin status will not be affected',
                    style: TextStyle(
                      color: _isDark ? Colors.white70 : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    shouldBlock
                        ? 'You can unblock users individually later.'
                        : 'You can block users individually later.',
                    style: TextStyle(
                      color: shouldBlock ? Colors.orange : Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: _isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                shouldBlock ? 'Block All' : 'Unblock All',
                style: TextStyle(
                  color: shouldBlock ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                shouldBlock ? Colors.red : Colors.green,
              ),
            ),
          ),
        );

        try {
          // Create a batch for the updates
          final batch = FirebaseFirestore.instance.batch();

          // Add updates to batch for non-admin users
          for (var userDoc in usersSnapshot.docs) {
            // Skip if user is an admin
            if (!adminEmails.contains(userDoc.id)) {
              batch.update(userDoc.reference, {'blocked': shouldBlock});
            }
          }

          // Commit the batch
          await batch.commit();

          // Close loading indicator
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                shouldBlock
                    ? 'All users have been blocked'
                    : 'All users have been unblocked',
              ),
              backgroundColor: shouldBlock ? Colors.red : Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          // Close loading indicator if there's an error
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                shouldBlock
                    ? 'Failed to block users: $e'
                    : 'Failed to unblock users: $e',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Operation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildUserCard(Map<String, dynamic> user, String email, String name,
      int points, bool isBlocked) {
    return Card(
      elevation: 6,
      margin: EdgeInsets.zero,
      color: isBlocked
          ? (_isDark ? Color(0xFF3A1A1A) : Color(0xFFFFEBEE))
          : (_isDark ? Color(0xFF2A2A2A) : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: isBlocked
            ? BorderSide(
                color: _isDark ? Colors.red[700]! : Colors.red[300]!,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: _isDark ? Colors.white : Colors.black,
                displayColor: _isDark ? Colors.white : Colors.black,
              ),
        ),
        child: Stack(
          children: [
            if (isBlocked)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isDark ? Colors.red[900] : Colors.red,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
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
            ExpansionTile(
              tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              title: Row(
                children: [
                  _buildProfileImage(email, name),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _highlightText(name, _searchText, isName: true),
                            SizedBox(width: 8),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('requests')
                                  .where('userEmail', isEqualTo: email)
                                  .where('isApproved', isEqualTo: false)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    snapshot.data!.docs.isNotEmpty) {
                                  return Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: _isDark
                                          ? Colors.orange[700]
                                          : Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.notifications_active,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  );
                                }
                                return SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            color: _isDark ? Colors.grey[400] : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Points: $points',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isDark ? Colors.red[300] : Colors.red,
                                fontSize: 14,
                              ),
                            ),
                            if (isBlocked) ...[
                              SizedBox(width: 10),
                              Icon(Icons.block,
                                  color: _isDark ? Colors.red[300] : Colors.red,
                                  size: 18),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        _showEditDialog(context, email, name, points);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(Icons.edit,
                            color:
                                _isDark ? Colors.blue[300] : Colors.blueAccent),
                      ),
                    ),
                  ),
                ],
              ),
              children: isBlocked
                  ? []
                  : [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('requests')
                            .where('userEmail', isEqualTo: email)
                            .where('isApproved', isEqualTo: false)
                            .snapshots(),
                        builder: (context, activitySnapshot) {
                          if (!activitySnapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (activitySnapshot.hasError) {
                            return Center(
                                child:
                                    Text('Error: ${activitySnapshot.error}'));
                          }

                          final List<Activity> activities = [];
                          if (activitySnapshot.hasData &&
                              activitySnapshot.data != null) {
                            activities.addAll(activitySnapshot.data!.docs
                                .map((doc) => Activity.fromJson({
                                      ...doc.data() as Map<String, dynamic>,
                                      'id': doc.id,
                                    }))
                                .toList());
                          }

                          if (activities.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text('No pending requests',
                                  style: TextStyle(
                                      color: _isDark
                                          ? Colors.white70
                                          : Colors.blueGrey)),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: ClampingScrollPhysics(),
                            itemCount: activities.length,
                            separatorBuilder: (context, idx) =>
                                SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final activity = activities[index];
                              return AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: _buildActivityTile(activity,
                                    (removedActivity) {
                                  activities.removeWhere(
                                      (a) => a.id == removedActivity.id);
                                }),
                              );
                            },
                          );
                        },
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    String? emailError;
    String? passwordError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: _isDark ? Color(0xFF2A2A2A) : Colors.white,
            title: Row(
              children: [
                Icon(
                  Icons.person_add,
                  color: _isDark ? Colors.blue[300] : Colors.blue,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Add New User',
                  style: TextStyle(
                    color: _isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _emailController,
                    style: TextStyle(
                      color: _isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black87,
                      ),
                      errorText: emailError,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _isDark ? Colors.blue[300]! : Colors.blue,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    style: TextStyle(
                      color: _isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black87,
                      ),
                      errorText: passwordError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: _isDark ? Colors.white70 : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _isDark ? Colors.blue[300]! : Colors.blue,
                        ),
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    dropdownColor: _isDark ? Color(0xFF2A2A2A) : Colors.white,
                    style: TextStyle(
                      color: _isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Role',
                      labelStyle: TextStyle(
                        color: _isDark ? Colors.white70 : Colors.black87,
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _isDark ? Colors.white30 : Colors.black26,
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: _isDark ? Colors.blue[300]! : Colors.blue,
                        ),
                      ),
                    ),
                    items: _userRoles.map((String role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Text(role),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedRole = newValue;
                        });
                      }
                    },
                  ),
                  if (isLoading) ...[
                    SizedBox(height: 16),
                    CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: _isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() {
                          emailError = null;
                          passwordError = null;
                          isLoading = true;
                        });

                        final email = _emailController.text.trim();
                        final password = _passwordController.text;

                        // Validate inputs
                        bool hasError = false;
                        if (email.isEmpty) {
                          setState(() {
                            emailError = 'Please enter an email';
                            hasError = true;
                          });
                        }
                        if (password.isEmpty) {
                          setState(() {
                            passwordError = 'Please enter a password';
                            hasError = true;
                          });
                        } else if (password.length < 8) {
                          setState(() {
                            passwordError =
                                'Password must be at least 8 characters';
                            hasError = true;
                          });
                        }

                        if (hasError) {
                          setState(() {
                            isLoading = false;
                          });
                          return;
                        }

                        try {
                          // Create a secondary auth instance for new user creation
                          FirebaseApp secondaryApp;
                          try {
                            secondaryApp = await Firebase.initializeApp(
                              name: 'SecondaryApp',
                              options: Firebase.app().options,
                            );
                          } catch (e) {
                            // If secondary app already exists, get it
                            secondaryApp = Firebase.app('SecondaryApp');
                          }

                          // Create user using secondary auth instance
                          final secondaryAuth =
                              FirebaseAuth.instanceFor(app: secondaryApp);
                          await secondaryAuth.createUserWithEmailAndPassword(
                            email: email,
                            password: password,
                          );

                          // Add user to Firestore
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(email)
                              .set({
                            'email': email,
                            'name':
                                email.split('@')[0], // Default name from email
                            'points': 0,
                            'blocked': false,
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          // If role is Admin, add to admins collection
                          if (_selectedRole != 'User') {
                            await FirebaseFirestore.instance
                                .collection('admins')
                                .doc(email)
                                .set({
                              'isAdmin': true,
                              'role': _selectedRole,
                            });
                          }

                          // Sign out and delete the secondary auth instance
                          await secondaryAuth.signOut();
                          await secondaryApp.delete();

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('User created successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } on FirebaseAuthException catch (e) {
                          setState(() {
                            isLoading = false;
                            if (e.code == 'weak-password') {
                              passwordError =
                                  'The password provided is too weak';
                            } else if (e.code == 'email-already-in-use') {
                              emailError =
                                  'An account already exists for this email';
                            } else {
                              emailError = e.message;
                            }
                          });
                        } catch (e) {
                          setState(() {
                            isLoading = false;
                            emailError = 'An error occurred: ${e.toString()}';
                          });
                        }
                      },
                child: Text(
                  'Create',
                  style: TextStyle(
                    color: _isDark ? Colors.blue[300] : Colors.blue,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: null,
        elevation: 0,
        backgroundColor: _isDark ? Color(0xFF1A1A1A) : Colors.white,
        iconTheme: IconThemeData(
            color: _isDark ? Colors.blue[300] : Colors.blueAccent),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add),
            tooltip: 'Add',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                backgroundColor: _isDark ? Color(0xFF2A2A2A) : Colors.white,
                builder: (context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: Icon(Icons.admin_panel_settings,
                              color: _isDark ? Colors.blue[300] : Colors.blue),
                          title: Text('Promote a user to be an admin',
                              style: TextStyle(
                                  color:
                                      _isDark ? Colors.white : Colors.black)),
                          onTap: () {
                            Navigator.pop(context);
                            TextEditingController _emailController =
                                TextEditingController();
                            showDialog(
                              context: context,
                              builder: (context) => StatefulBuilder(
                                builder: (context, setState) {
                                  return AlertDialog(
                                    backgroundColor: _isDark
                                        ? Color(0xFF2A2A2A)
                                        : Colors.white,
                                    title: Text('Promote User to Admin',
                                        style: TextStyle(
                                            color: _isDark
                                                ? Colors.white
                                                : Colors.black)),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: _emailController,
                                          style: TextStyle(
                                              color: _isDark
                                                  ? Colors.white
                                                  : Colors.black),
                                          decoration: InputDecoration(
                                            labelText: 'User Email',
                                            labelStyle: TextStyle(
                                                color: _isDark
                                                    ? Colors.white70
                                                    : Colors.black87),
                                            errorText: errorText,
                                            enabledBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: _isDark
                                                      ? Colors.white30
                                                      : Colors.black26),
                                            ),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                  color: _isDark
                                                      ? Colors.blue[300]!
                                                      : Colors.blue),
                                            ),
                                          ),
                                          keyboardType:
                                              TextInputType.emailAddress,
                                        ),
                                        if (isLoading)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 16.0),
                                            child: CircularProgressIndicator(),
                                          ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Cancel',
                                            style: TextStyle(
                                                color: _isDark
                                                    ? Colors.white70
                                                    : Colors.black87)),
                                      ),
                                      TextButton(
                                        onPressed: isLoading
                                            ? null
                                            : () async {
                                                setState(() {
                                                  errorText = null;
                                                  isLoading = true;
                                                });
                                                final email = _emailController
                                                    .text
                                                    .trim();
                                                if (email.isEmpty) {
                                                  setState(() {
                                                    errorText =
                                                        'Please enter an email.';
                                                    isLoading = false;
                                                  });
                                                  return;
                                                }
                                                try {
                                                  final userDoc =
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('users')
                                                          .doc(email)
                                                          .get();
                                                  if (!userDoc.exists) {
                                                    setState(() {
                                                      errorText =
                                                          'No user found with this email.';
                                                      isLoading = false;
                                                    });
                                                    return;
                                                  }
                                                  // Add to admins collection
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('admins')
                                                      .doc(email)
                                                      .set({'isAdmin': true});
                                                  Navigator.pop(context);
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'User promoted to admin successfully!'),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );
                                                } catch (e) {
                                                  setState(() {
                                                    errorText =
                                                        'Error: ${e.toString()}';
                                                    isLoading = false;
                                                  });
                                                }
                                              },
                                        child: Text('Promote',
                                            style: TextStyle(
                                                color: _isDark
                                                    ? Colors.blue[300]
                                                    : Colors.blue)),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.person_add,
                              color: _isDark ? Colors.blue[300] : Colors.blue),
                          title: Text('Add new user',
                              style: TextStyle(
                                  color:
                                      _isDark ? Colors.white : Colors.black)),
                          onTap: () {
                            Navigator.pop(context);
                            _showAddUserDialog(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder:
                (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (!snapshot.hasData) {
                return IconButton(
                  icon: const Icon(Icons.block),
                  onPressed: null,
                );
              }

              final usersData = snapshot.data!.docs;
              int blockedCount = 0;
              int totalUsers = 0;

              for (var doc in usersData) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['blocked'] == true) blockedCount++;
                totalUsers++;
              }

              final bool mostlyBlocked = blockedCount > (totalUsers / 2);

              return IconButton(
                icon: Icon(mostlyBlocked ? Icons.lock_open : Icons.block),
                tooltip:
                    mostlyBlocked ? 'Unblock All Users' : 'Block All Users',
                onPressed: _blockAllUsers,
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Reset All Points',
            onPressed: _resetAllPoints,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isDark
                ? [Color(0xFF1A1A1A), Color(0xFF2A2A2A)]
                : [Colors.white, Colors.blue[50] ?? Colors.blue.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isDark ? Color(0xFF2A2A2A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                              color: _isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Search users...',
                            labelStyle: TextStyle(
                                color:
                                    _isDark ? Colors.white70 : Colors.black87),
                            prefixIcon: Icon(Icons.search,
                                color: _isDark
                                    ? Colors.blue[300]
                                    : Colors.blueAccent),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortOption,
                          borderRadius: BorderRadius.circular(12),
                          style: TextStyle(
                              color: _isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold),
                          dropdownColor:
                              _isDark ? Color(0xFF2A2A2A) : Colors.white,
                          onChanged: (String? newValue) {
                            setState(() {
                              _sortOption = newValue!;
                            });
                          },
                          items: <String>[
                            'Name',
                            'Newest',
                            'Highest Points',
                            'Pending Requests'
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text('Sort by $value'),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 18),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.data == null) {
                    return Center(child: Text('No user data available.'));
                  }

                  final users = (snapshot.data?.docs ?? [])
                      .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
                      .toList();

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getSortedAndFilteredUserList(
                        users, _sortOption, _searchText),
                    builder: (context, sortedUserListSnapshot) {
                      if (sortedUserListSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (sortedUserListSnapshot.hasError) {
                        return Center(
                            child:
                                Text('Error: ${sortedUserListSnapshot.error}'));
                      }

                      final userList = sortedUserListSnapshot.data ?? [];

                      if (userList.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64,
                                  color: _isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[100]),
                              SizedBox(height: 16),
                              Text('No users found',
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: _isDark
                                          ? Colors.white70
                                          : Colors.blueGrey)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: userList.length,
                        separatorBuilder: (context, idx) =>
                            SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final user = userList[index];
                          final name = user['name'];
                          final email = user['id'];
                          final points = user['points'];
                          final isBlocked = user['blocked'];

                          return AnimatedContainer(
                            duration: Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            child: GestureDetector(
                              onLongPress: () {
                                _showOptionsDialog(
                                    context, email, name, isBlocked);
                              },
                              child: _buildUserCard(
                                  user, email, name, points, isBlocked),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
