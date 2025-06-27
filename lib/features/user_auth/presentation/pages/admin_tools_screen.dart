import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminToolsScreen extends StatefulWidget {
  @override
  _AdminToolsScreenState createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _whatsappLinkController = TextEditingController();
  final _googleDriveLinkController = TextEditingController();
  final _fixerNameController = TextEditingController();
  final _fixerNumberController = TextEditingController();
  final _announcementTitleController = TextEditingController();
  final _announcementContentController = TextEditingController();
  final _psalmTitleController = TextEditingController();
  final _psalmContentController = TextEditingController();
  final _appVersionController = TextEditingController();
  final _updateLinkController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  TimeOfDay _selectedEndTime = TimeOfDay.now(); // Add end time
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  String? _splashImageUrl;
  String? _drawerImageUrl;
  String? _whatsappGroupLink;
  String? _googleDriveLink;
  bool _isUploading = false;
  List<Map<String, dynamic>> _fixers = [];
  bool _isLoadingFixers = false;
  bool _isFixersExpanded = false;
  bool _isEventsExpanded = false; // Add this line to fix the error
  String? _editingEventId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadResources();
    _loadEvents();
    _loadFixers();
    _loadPsalmContent();
    _loadVersionControl();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _whatsappLinkController.dispose();
    _googleDriveLinkController.dispose();
    _fixerNameController.dispose();
    _fixerNumberController.dispose();
    _announcementTitleController.dispose();
    _announcementContentController.dispose();
    _psalmTitleController.dispose();
    _psalmContentController.dispose();
    _appVersionController.dispose();
    _updateLinkController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    try {
      // Load all resources in a single batch operation for better performance
      final resourcesRef = FirebaseFirestore.instance.collection('resources');
      final docs = await Future.wait([
        resourcesRef.doc('splash_screen').get(),
        resourcesRef.doc('drawer_header').get(),
        resourcesRef.doc('whatsapp_group_link').get(),
        resourcesRef.doc('google_drive_link').get(),
      ]);

      if (mounted) {
        setState(() {
          // Process splash screen image
          if (docs[0].exists) {
            _splashImageUrl = docs[0].data()?['imageUrl'];
          }

          // Process drawer header image
          if (docs[1].exists) {
            _drawerImageUrl = docs[1].data()?['imageUrl'];
          }

          // Process WhatsApp group link
          if (docs[2].exists) {
            _whatsappGroupLink = docs[2].data()?['link'];
            _whatsappLinkController.text = _whatsappGroupLink ?? '';
          }

          // Process Google Drive link
          if (docs[3].exists) {
            _googleDriveLink = docs[3].data()?['link'];
            _googleDriveLinkController.text = _googleDriveLink ?? '';
          }
        });
      }
    } catch (e) {
      print('Error loading resources: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load resources: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage(String path, XFile image) async {
    try {
      setState(() => _isUploading = true);

      final storageRef = FirebaseStorage.instance.ref().child(path);
      final bytes = await image.readAsBytes();
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final uploadTask = await storageRef.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() => _isUploading = false);
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
      return null;
    }
  }

  Future<void> _updateImageUrl(String docId, String imageUrl) async {
    try {
      await FirebaseFirestore.instance.collection('resources').doc(docId).set({
        'imageUrl': imageUrl,
        'version': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image updated successfully')),
      );
    } catch (e) {
      print('Error updating image URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update image: $e')),
      );
    }
  }

  Future<void> _deleteImage(String docId) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Color(0xFF2A2A2A) : Colors.white,
          title: Text(
            'Remove Image',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to remove this image? This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Remove'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('resources').doc(docId).set({
        'imageUrl': null,
        'version': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      // Update local state
      if (docId == 'splash_screen') {
        setState(() => _splashImageUrl = null);
      } else if (docId == 'drawer_header') {
        setState(() => _drawerImageUrl = null);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image removed successfully')),
      );
    } catch (e) {
      print('Error deleting image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove image: $e')),
      );
    }
  }

  Future<void> _updateLink(String docId, String link) async {
    try {
      await FirebaseFirestore.instance
          .collection('resources')
          .doc(docId)
          .set({'link': link});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link updated successfully')),
      );
    } catch (e) {
      print('Error updating link: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update link: $e')),
      );
    }
  }

  Future<void> _pickAndUploadImage(String docId, String path) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final downloadUrl = await _uploadImage(path, image);
      if (downloadUrl != null) {
        await _updateImageUrl(docId, downloadUrl);
        if (docId == 'splash_screen') {
          setState(() => _splashImageUrl = downloadUrl);
        } else if (docId == 'drawer_header') {
          setState(() => _drawerImageUrl = downloadUrl);
        }
      }
    }
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final querySnapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('date')
          .get();

      setState(() {
        _events = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] as String? ?? 'Unnamed Event',
            'description': data['description'] as String? ?? '',
            'date': (data['date'] as Timestamp).toDate(),
            'endTime': data['endTime'] != null
                ? (data['endTime'] as Timestamp).toDate()
                : null,
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addEvent() async {
    if (_formKey.currentState!.validate()) {
      try {
        final dateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        final endDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedEndTime.hour,
          _selectedEndTime.minute,
        );

        await FirebaseFirestore.instance.collection('events').add({
          'name': _nameController.text,
          'description': _descriptionController.text,
          'date': Timestamp.fromDate(dateTime),
          'endTime': Timestamp.fromDate(endDateTime),
        });

        _nameController.clear();
        _descriptionController.clear();
        _loadEvents();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event added successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add event: $e')),
        );
      }
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .delete();
      _loadEvents();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Event deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete event: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime,
    );
    if (picked != null && picked != _selectedEndTime) {
      setState(() {
        _selectedEndTime = picked;
      });
    }
  }

  Future<void> _loadFixers() async {
    try {
      setState(() => _isLoadingFixers = true);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('fixers')
          .orderBy('name')
          .get();

      setState(() {
        _fixers = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] as String? ?? '',
            'number': data['number'] as String? ?? '',
          };
        }).toList();
        _isLoadingFixers = false;
      });
    } catch (e) {
      print('Error loading fixers: $e');
      setState(() => _isLoadingFixers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load fixers: $e')),
      );
    }
  }

  Future<void> _addFixer() async {
    if (_fixerNameController.text.isEmpty ||
        _fixerNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('fixers').add({
        'name': _fixerNameController.text,
        'number': _fixerNumberController.text,
      });

      _fixerNameController.clear();
      _fixerNumberController.clear();
      _loadFixers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fixer added successfully')),
      );
    } catch (e) {
      print('Error adding fixer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add fixer: $e')),
      );
    }
  }

  Future<void> _deleteFixer(String fixerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('fixers')
          .doc(fixerId)
          .delete();

      _loadFixers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fixer deleted successfully')),
      );
    } catch (e) {
      print('Error deleting fixer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete fixer: $e')),
      );
    }
  }

  Future<void> _editFixer(Map<String, dynamic> fixer) async {
    _fixerNameController.text = fixer['name'];
    _fixerNumberController.text = fixer['number'];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Color(0xFF2A2A2A) : Colors.white,
          title: Text(
            'Edit Fixer',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _fixerNameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white30
                            : Colors.blue.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: isDark ? Colors.blue[300]! : Colors.blue),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _fixerNumberController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: isDark
                            ? Colors.white30
                            : Colors.blue.withOpacity(0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: isDark ? Colors.blue[300]! : Colors.blue),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                _fixerNameController.clear();
                _fixerNumberController.clear();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('fixers')
                      .doc(fixer['id'])
                      .update({
                    'name': _fixerNameController.text,
                    'number': _fixerNumberController.text,
                  });

                  Navigator.of(context).pop();
                  _fixerNameController.clear();
                  _fixerNumberController.clear();
                  _loadFixers();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fixer updated successfully')),
                  );
                } catch (e) {
                  print('Error updating fixer: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update fixer: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _editEvent(String eventId, Map<String, dynamic> event) async {
    setState(() {
      _nameController.text = event['name'];
      _descriptionController.text = event['description'];
      _selectedDate = event['date'];
      _selectedTime = TimeOfDay.fromDateTime(event['date']);
      _selectedEndTime = event['endTime'] != null
          ? TimeOfDay.fromDateTime(event['endTime'])
          : TimeOfDay.fromDateTime(event['date'].add(Duration(hours: 1)));
    });

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show edit dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Edit Event',
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Event Name',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white30 : Colors.black12,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white30 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.blue[300]! : Colors.blue,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white30 : Colors.black12,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white30 : Colors.black12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.blue[300]! : Colors.blue,
                    ),
                  ),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.calendar_today,
                        color: isDark ? Colors.blue[300] : Colors.blue,
                      ),
                      label: Text(
                        DateFormat('MMM dd, yyyy').format(_selectedDate),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      onPressed: () => _selectDate(context),
                      style: TextButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.blue[900]
                            : Colors.blue.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.access_time,
                        color: isDark ? Colors.blue[300] : Colors.blue,
                      ),
                      label: Text(
                        "Start: ${_selectedTime.format(context)}",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      onPressed: () => _selectTime(context),
                      style: TextButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.blue[900]
                            : Colors.blue.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: Icon(
                        Icons.access_time,
                        color: isDark ? Colors.blue[300] : Colors.blue,
                      ),
                      label: Text(
                        "End: ${_selectedEndTime.format(context)}",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      onPressed: () => _selectEndTime(context),
                      style: TextButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.blue[900]
                            : Colors.blue.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text('Add Event'),
                onPressed: _addEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.green[900] : Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty) {
                final dateTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                );

                try {
                  final endDateTime = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    _selectedEndTime.hour,
                    _selectedEndTime.minute,
                  );

                  await FirebaseFirestore.instance
                      .collection('events')
                      .doc(eventId)
                      .update({
                    'name': _nameController.text,
                    'description': _descriptionController.text,
                    'date': Timestamp.fromDate(dateTime),
                    'endTime': Timestamp.fromDate(endDateTime),
                  });

                  _nameController.clear();
                  _descriptionController.clear();
                  _loadEvents();

                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Event updated successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update event: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[900] : Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      // Event was successfully added/updated
    }
  }

  Future<void> _addAnnouncement() async {
    if (_announcementTitleController.text.isEmpty ||
        _announcementContentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _announcementTitleController.text,
        'content': _announcementContentController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [], // Add this field to track who has read the announcement
      });

      _announcementTitleController.clear();
      _announcementContentController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Announcement added successfully')),
      );
    } catch (e) {
      print('Error adding announcement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add announcement: $e')),
      );
    }
  }

  Future<void> _editAnnouncement(
      String announcementId, Map<String, dynamic> data) async {
    _announcementTitleController.text = data['title'] ?? '';
    _announcementContentController.text = data['content'] ?? '';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: isDark ? Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue[900]!.withOpacity(0.3)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Announcement',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: isDark ? Colors.white70 : Colors.black54),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _announcementTitleController.clear();
                          _announcementContentController.clear();
                        },
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _announcementTitleController,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87),
                          textAlign:
                              _isArabicText(_announcementTitleController.text)
                                  ? TextAlign.right
                                  : TextAlign.left,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            labelStyle: TextStyle(
                                color:
                                    isDark ? Colors.white70 : Colors.black54),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white30
                                    : Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white30
                                    : Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.blue[300]! : Colors.blue,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        TextField(
                          controller: _announcementContentController,
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87),
                          textAlign:
                              _isArabicText(_announcementContentController.text)
                                  ? TextAlign.right
                                  : TextAlign.left,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Content',
                            labelStyle: TextStyle(
                                color:
                                    isDark ? Colors.white70 : Colors.black54),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white30
                                    : Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white30
                                    : Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.blue[300]! : Colors.blue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _announcementTitleController.clear();
                            _announcementContentController.clear();
                          },
                          child: Text('Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('announcements')
                                  .doc(announcementId)
                                  .update({
                                'title': _announcementTitleController.text,
                                'content': _announcementContentController.text,
                                'readBy':
                                    [], // Reset readBy when announcement is edited
                              });

                              Navigator.of(context).pop();
                              _announcementTitleController.clear();
                              _announcementContentController.clear();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Announcement updated successfully')),
                              );
                            } catch (e) {
                              print('Error updating announcement: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Failed to update announcement: $e')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.blue[900] : Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteAnnouncement(String announcementId) async {
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(announcementId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Announcement deleted successfully')),
      );
    } catch (e) {
      print('Error deleting announcement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete announcement: $e')),
      );
    }
  }

  Future<void> _loadPsalmContent() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('mazmour_el_kora')
          .doc('content')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _psalmTitleController.text = data['title'] ?? 'Psalm';
          _psalmContentController.text = data['content'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading psalm content: $e');
    }
  }

  Future<void> _updatePsalmContent() async {
    if (_psalmTitleController.text.isEmpty ||
        _psalmContentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('mazmour_el_kora')
          .doc('content')
          .set({
        'title': _psalmTitleController.text,
        'content': _psalmContentController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Psalm content updated successfully')),
      );
    } catch (e) {
      print('Error updating psalm content: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update psalm content: $e')),
      );
    }
  }

  Future<void> _clearPsalmContent() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Color(0xFF2A2A2A) : Colors.white,
          title: Text(
            'Clear Psalm Content',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to clear the current psalm content? This action cannot be undone.',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Clear'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('mazmour_el_kora')
          .doc('content')
          .set({
        'title': '',
        'content': '',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Clear the text controllers
      setState(() {
        _psalmTitleController.clear();
        _psalmContentController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Psalm content cleared successfully')),
      );
    } catch (e) {
      print('Error clearing psalm content: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear psalm content: $e')),
      );
    }
  }

  Future<void> _loadVersionControl() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_version')
          .doc('version_info')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _appVersionController.text = data['current_version'] ?? '2.0.0';
          _updateLinkController.text = data['update_link'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading version control: $e');
    }
  }

  Future<void> _updateVersionControl() async {
    if (_appVersionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter the required app version')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('app_version')
          .doc('version_info')
          .set({
        'current_version': _appVersionController.text,
        'update_link': _updateLinkController.text,
        'last_updated': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Version control updated successfully')),
      );
    } catch (e) {
      print('Error updating version control: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update version control: $e')),
      );
    }
  }

  // Function to detect if text contains Arabic characters
  bool _isArabicText(String text) {
    if (text.isEmpty) return false;

    // Check for Arabic Unicode ranges
    final arabicRegex = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF\u0671-\u06D3\u06FA-\u06FC]');

    // Count Arabic characters vs total characters
    final arabicMatches = arabicRegex.allMatches(text);
    final arabicCharCount = arabicMatches.length;
    final totalCharCount = text.trim().length;

    // If more than 30% of characters are Arabic, consider it Arabic text
    return arabicCharCount > 0 && (arabicCharCount / totalCharCount) > 0.3;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Tools',
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: isDark ? Colors.blue[300] : Colors.blue,
          labelColor: isDark ? Colors.white : Colors.black87,
          unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          labelPadding: EdgeInsets.only(left: 8, right: 8),
          padding: EdgeInsets.only(left: 0),
          tabs: [
            Tab(
              icon: Icon(Icons.event),
              text: 'Events',
            ),
            Tab(
              icon: Icon(Icons.announcement),
              text: 'Announcements',
            ),
            Tab(
              icon: Icon(Icons.book),
              text: 'Psalm',
            ),
            Tab(
              icon: Icon(Icons.image),
              text: 'Resources',
            ),
            Tab(
              icon: Icon(Icons.people),
              text: 'Fixers',
            ),
            Tab(
              icon: Icon(Icons.settings),
              text: 'Version Control',
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Color(0xFF1A1A1A), Color(0xFF2A2A2A)]
                : [Colors.white, Colors.blue[50]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildEventsTab(isDark),
            _buildAnnouncementsTab(isDark),
            _buildPsalmTab(isDark),
            _buildResourcesTab(isDark),
            _buildFixersTab(isDark),
            _buildVersionControlTab(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _buildEventsCard(isDark),
    );
  }

  Widget _buildAnnouncementsTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _buildAnnouncementsCard(isDark),
    );
  }

  Widget _buildPsalmTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _buildPsalmManagementCard(isDark),
    );
  }

  Widget _buildResourcesTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Splash Screen Image Card
          _buildResourceCard(
            title: 'Splash Screen Image',
            icon: Icons.image,
            child: _buildImageSection(
              title: 'Splash Screen Image',
              imageUrl: _splashImageUrl,
              onUpload: () =>
                  _pickAndUploadImage('splash_screen', 'splash_images'),
              onLinkUpload: (link) => _updateImageUrl('splash_screen', link),
              onDelete: () => _deleteImage('splash_screen'),
            ),
          ),
          SizedBox(height: 16),
          // Drawer Header Image Card
          _buildResourceCard(
            title: 'Drawer Header Image',
            icon: Icons.image,
            child: _buildImageSection(
              title: 'Drawer Header Image',
              imageUrl: _drawerImageUrl,
              onUpload: () =>
                  _pickAndUploadImage('drawer_header', 'drawer_images'),
              onLinkUpload: (link) => _updateImageUrl('drawer_header', link),
              onDelete: () => _deleteImage('drawer_header'),
            ),
          ),
          SizedBox(height: 16),
          // WhatsApp Group Link Card
          _buildResourceCard(
            title: 'WhatsApp Group Link',
            icon: Icons.link,
            child: _buildLinkSection(
              title: 'WhatsApp Group Link',
              controller: _whatsappLinkController,
              onSave: () => _updateLink(
                  'whatsapp_group_link', _whatsappLinkController.text),
            ),
          ),
          SizedBox(height: 16),
          // Google Drive Link Card
          _buildResourceCard(
            title: 'Google Drive Link',
            icon: Icons.link,
            child: _buildLinkSection(
              title: 'Google Drive Link',
              controller: _googleDriveLinkController,
              onSave: () => _updateLink(
                  'google_drive_link', _googleDriveLinkController.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixersTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _buildFixersCard(isDark),
    );
  }

  Widget _buildEventsCard(bool isDark) {
    return Card(
      elevation: 8,
      shadowColor: isDark ? Colors.black : Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark ? Color(0xFF2A2A2A).withOpacity(0.95) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue[900]
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.event,
                      color: isDark ? Colors.blue[300] : Colors.blue),
                ),
                SizedBox(width: 12),
                Text(
                  'Event Management',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Event Name',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark
                                ? Colors.white30
                                : Colors.blue.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark ? Colors.blue[300]! : Colors.blue),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.blue.withOpacity(0.05),
                      prefixIcon: Icon(
                        Icons.title,
                        color: isDark ? Colors.white70 : Colors.blue,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an event name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Description (Optional)',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark
                                ? Colors.white30
                                : Colors.blue.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark ? Colors.blue[300]! : Colors.blue),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.blue.withOpacity(0.05),
                      prefixIcon: Icon(
                        Icons.description,
                        color: isDark ? Colors.white70 : Colors.blue,
                      ),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.calendar_today),
                          label: Text(
                              DateFormat('MMM dd, yyyy').format(_selectedDate)),
                          onPressed: () => _selectDate(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.blue[900] : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.access_time),
                          label:
                              Text("Start: ${_selectedTime.format(context)}"),
                          onPressed: () => _selectTime(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.blue[900] : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.access_time),
                          label:
                              Text("End: ${_selectedEndTime.format(context)}"),
                          onPressed: () => _selectEndTime(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.blue[900] : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Add Event'),
                    onPressed: _addEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? Colors.green[900] : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.list_alt,
                    color: isDark ? Colors.white70 : Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Current Events',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? Colors.blue[300]! : Colors.blue,
                  ),
                ),
              )
            else if (_events.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: isDark
                          ? Colors.white70
                          : Colors.blue.withOpacity(0.5),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No events found',
                      style: TextStyle(
                        color: isDark
                            ? Colors.white70
                            : Colors.blue.withOpacity(0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ExpansionPanelList(
                expandedHeaderPadding: EdgeInsets.zero,
                expansionCallback: (int index, bool isExpanded) {
                  setState(() {
                    _isEventsExpanded = isExpanded;
                  });
                },
                children: [
                  ExpansionPanel(
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                        title: Text(
                          'Current Events',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      );
                    },
                    body: ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        final currentDate = event['date'];

                        // Add date separator if it's the first event or if the date is different from the previous event
                        if (index == 0 ||
                            !_isSameDay(
                                currentDate, _events[index - 1]['date'])) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDateSeparator(currentDate, isDark),
                              _buildEventCard(event, isDark),
                            ],
                          );
                        }

                        return _buildEventCard(event, isDark);
                      },
                    ),
                    isExpanded: _isEventsExpanded,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsCard(bool isDark) {
    return _buildResourceCard(
      title: 'Announcements',
      icon: Icons.announcement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.blue.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Announcement',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _announcementTitleController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    textAlign: _isArabicText(_announcementTitleController.text)
                        ? TextAlign.right
                        : TextAlign.left,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white30
                              : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white30
                              : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.blue[300]! : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _announcementContentController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    textAlign:
                        _isArabicText(_announcementContentController.text)
                            ? TextAlign.right
                            : TextAlign.left,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Content',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white30
                              : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white30
                              : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.blue[300]! : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Add Announcement'),
                    onPressed: _addAnnouncement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue[900] : Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error loading announcements');
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: 48,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No announcements yet',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: isDark ? Colors.white54 : Colors.black54,
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
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'] != null
                      ? (data['timestamp'] as Timestamp).toDate()
                      : DateTime.now();

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    color:
                        isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  data['title'] ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: isDark
                                          ? Colors.blue[300]
                                          : Colors.blue,
                                    ),
                                    onPressed: () =>
                                        _editAnnouncement(doc.id, data),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color:
                                          isDark ? Colors.red[300] : Colors.red,
                                    ),
                                    onPressed: () =>
                                        _deleteAnnouncement(doc.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            data['content'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            DateFormat('MMM d, yyyy • h:mm a')
                                .format(timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
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
    );
  }

  Widget _buildPsalmManagementCard(bool isDark) {
    return _buildResourceCard(
      title: 'Psalm Management',
      icon: Icons.book,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.blue.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Psalm Content',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _psalmTitleController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Psalm Title',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white30
                              : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white30
                              : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.blue[300]! : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _psalmContentController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: 'Psalm Content',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white30
                              : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.white30
                              : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.blue[300]! : Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.update),
                    label: Text('Update Psalm'),
                    onPressed: _updatePsalmContent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? Colors.green[900] : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.clear),
                    label: Text('Clear Psalm'),
                    onPressed: _clearPsalmContent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.red[900] : Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildResourceCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 8,
      shadowColor: isDark ? Colors.black : Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark ? Color(0xFF2A2A2A).withOpacity(0.95) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue[900]
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: isDark ? Colors.blue[300] : Colors.blue),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection({
    required String title,
    required String? imageUrl,
    required VoidCallback onUpload,
    required Function(String) onLinkUpload,
    required VoidCallback onDelete,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final TextEditingController linkController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: imageUrl != null ? () => _showImageDialog(imageUrl) : null,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white30 : Colors.blue.withOpacity(0.2),
              ),
            ),
            child: imageUrl != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                Icons.error_outline,
                                color: isDark ? Colors.white70 : Colors.black54,
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: GestureDetector(
                                onTap: onDelete,
                                child: Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      Icons.image,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 48,
                    ),
                  ),
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: linkController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Enter image URL',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.blue.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white30
                          : Colors.blue.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? Colors.white30
                          : Colors.blue.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.blue[300]! : Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            ElevatedButton.icon(
              icon: Icon(Icons.link),
              label: Text('Set URL'),
              onPressed: () {
                if (linkController.text.isNotEmpty) {
                  onLinkUpload(linkController.text);
                  linkController.clear();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.blue[900] : Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(100, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          icon: Icon(Icons.upload),
          label: Text('Upload Image'),
          onPressed: _isUploading ? null : onUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.blue[900] : Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  void _showImageDialog(String imageUrl) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(16),
          child: Stack(
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 300,
                              child: Center(
                                child: Icon(
                                  Icons.error_outline,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                  size: 48,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinkSection({
    required String title,
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Enter link',
            hintStyle:
                TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.blue.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white30 : Colors.blue.withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.white30 : Colors.blue.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.blue[300]! : Colors.blue,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        ElevatedButton.icon(
          icon: Icon(Icons.save),
          label: Text('Save Link'),
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.blue[900] : Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFixersCard(bool isDark) {
    return Card(
      elevation: 8,
      shadowColor: isDark ? Colors.black : Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark ? Color(0xFF2A2A2A).withOpacity(0.95) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue[900]
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.people,
                      color: isDark ? Colors.blue[300] : Colors.blue),
                ),
                SizedBox(width: 12),
                Text(
                  'Fixers Management',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _fixerNameController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Name',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark
                                ? Colors.white30
                                : Colors.blue.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark ? Colors.blue[300]! : Colors.blue),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      prefixIcon: Icon(
                        Icons.person,
                        color: isDark ? Colors.white70 : Colors.blue,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a fixer name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _fixerNumberController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark
                                ? Colors.white30
                                : Colors.blue.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isDark ? Colors.blue[300]! : Colors.blue),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      prefixIcon: Icon(
                        Icons.phone,
                        color: isDark ? Colors.white70 : Colors.blue,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Add Fixer'),
                    onPressed: _addFixer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.blue[900] : Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.list_alt,
                    color: isDark ? Colors.white70 : Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Current Fixers',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            if (_isLoadingFixers)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? Colors.blue[300]! : Colors.blue,
                    ),
                  ),
                ),
              )
            else if (_fixers.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: isDark
                            ? Colors.white70
                            : Colors.blue.withOpacity(0.5),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No fixers found',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : Colors.blue.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ExpansionPanelList(
                expandedHeaderPadding: EdgeInsets.zero,
                expansionCallback: (int index, bool isExpanded) {
                  setState(() {
                    _isFixersExpanded = isExpanded;
                  });
                },
                children: [
                  ExpansionPanel(
                    headerBuilder: (BuildContext context, bool isExpanded) {
                      return ListTile(
                        title: Text(
                          'Current Fixers',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      );
                    },
                    body: _isLoadingFixers
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDark ? Colors.blue[300]! : Colors.blue,
                                ),
                              ),
                            ),
                          )
                        : _fixers.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 48,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.blue.withOpacity(0.5),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No fixers found',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.blue.withOpacity(0.7),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _fixers.length,
                                itemBuilder: (context, index) {
                                  final fixer = _fixers[index];
                                  return Card(
                                    margin: EdgeInsets.only(bottom: 8),
                                    elevation: 2,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.blue.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      title: Text(
                                        fixer['name'],
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        fixer['number'],
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit,
                                                color: isDark
                                                    ? Colors.blue[300]
                                                    : Colors.blue),
                                            onPressed: () => _editFixer(fixer),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete,
                                                color: isDark
                                                    ? Colors.red[300]
                                                    : Colors.red),
                                            onPressed: () =>
                                                _deleteFixer(fixer['id']),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    isExpanded: _isFixersExpanded,
                    canTapOnHeader: true,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, bool isDark) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.blue.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _editEvent(event['id'], event),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            event['name'],
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event['description'].isNotEmpty) ...[
                SizedBox(height: 4),
                Text(
                  event['description'],
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
              SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue[900]
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      DateFormat('h:mm a').format(event['date']),
                      style: TextStyle(
                        color: isDark ? Colors.blue[300] : Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete,
                color: isDark ? Colors.red[300] : Colors.red),
            onPressed: () => _deleteEvent(event['id']),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: isDark ? Colors.white30 : Colors.black26,
              thickness: 1,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue[900] : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                DateFormat('EEEE, MMMM d, yyyy').format(date),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.blue[300] : Colors.blue,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: isDark ? Colors.white30 : Colors.black26,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildVersionControlTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: _buildVersionControlCard(isDark),
    );
  }

  Widget _buildVersionControlCard(bool isDark) {
    return Card(
      elevation: 8,
      shadowColor: isDark ? Colors.black : Colors.blue.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDark ? Color(0xFF2A2A2A).withOpacity(0.95) : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue[900]
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.settings,
                      color: isDark ? Colors.blue[300] : Colors.blue),
                ),
                SizedBox(width: 12),
                Text(
                  'Version Control',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Required App Version',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _appVersionController,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'e.g., 2.0.0',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.blue.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white30
                            : Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white30
                            : Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.blue[300]! : Colors.blue,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Update Link',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _updateLinkController,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText:
                        'e.g., https://play.google.com/store/apps/details?id=your.app.id',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.blue.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white30
                            : Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white30
                            : Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.blue[300]! : Colors.blue,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: Icon(Icons.update),
                  label: Text('Update Version Control'),
                  onPressed: _updateVersionControl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.green[900] : Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue[900]!.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.blue[300]! : Colors.blue,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: isDark ? Colors.blue[300] : Colors.blue,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'How Version Control Works',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Required App Version: The minimum version required to use the app\n'
                        '• Update Link: Link to the app store where users can download the update\n'
                        '• If app version on phone is lower than required version, update dialog will show\n'
                        '• Version format should be: x.y.z (e.g., 2.0.0, 2.1.0)',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
