import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class AdminExportPage extends StatefulWidget {
  const AdminExportPage({Key? key}) : super(key: key);

  @override
  State<AdminExportPage> createState() => _AdminExportPageState();
}

class _AdminExportPageState extends State<AdminExportPage> {
  bool _isLoading = true;
  String? _exportText;
  String? _fileName;
  Map<String, dynamic>? _stats;
  String? _error;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _prepareExport();
  }

  Future<void> _prepareExport() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _showSuccess = false;
    });
    try {
      final usersSnap =
          await FirebaseFirestore.instance.collection('users').get();
      final adminsSnap =
          await FirebaseFirestore.instance.collection('admins').get();
      final requestsSnap = await FirebaseFirestore.instance
          .collection('requests')
          .where('isApproved', isEqualTo: false)
          .get();
      List<Map<String, dynamic>> users = [];
      for (var doc in usersSnap.docs) {
        final data = doc.data();
        final email = doc.id;
        final name = data['name'] ?? '';
        final points = data['points'] ?? 0;
        final blocked = data['blocked'] ?? false;
        final role =
            adminsSnap.docs.any((a) => a.id == email) ? 'Admin' : 'User';
        final numRequests =
            requestsSnap.docs.where((r) => r['userEmail'] == email).length;
        users.add({
          'email': email,
          'name': name,
          'points': points,
          'role': role,
          'blocked': blocked,
          'num_requests': numRequests,
        });
      }
      final now = DateTime.now();
      final dateTimeString = DateFormat('MM/dd/yyyy hh:mm a').format(now);
      final stats = {
        'total_users': usersSnap.size,
        'total_admins': adminsSnap.size,
        'blocked_users': users.where((u) => u['blocked'] == true).length,
        'pending_requests': requestsSnap.size,
        'exported_at': dateTimeString,
      };
      final buffer = StringBuffer();
      buffer.writeln('=== Admin Export ===');
      buffer.writeln('Exported at: $dateTimeString');
      buffer.writeln('Total users: ${stats['total_users']}');
      buffer.writeln('Admins: ${stats['total_admins']}');
      buffer.writeln('Blocked users: ${stats['blocked_users']}');
      buffer.writeln('Pending requests: ${stats['pending_requests']}');
      buffer.writeln('');
      buffer.writeln('--- Users ---');
      for (var user in users) {
        buffer.writeln('Name: ${user['name']}');
        buffer.writeln('Email: ${user['email']}');
        buffer.writeln('Role: ${user['role']}');
        buffer.writeln('Points: ${user['points']}');
        buffer.writeln('Blocked: ${user['blocked'] ? 'Yes' : 'No'}');
        buffer.writeln('Pending Requests: ${user['num_requests']}');
        buffer.writeln('');
      }
      setState(() {
        _exportText = buffer.toString();
        _fileName =
            'admin_export_${now.toIso8601String().replaceAll(':', '-')}.txt';
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveExport() async {
    if (_exportText == null || _fileName == null) return;
    try {
      final bytes = utf8.encode(_exportText!);
      await FileSaver.instance.saveAs(
        name: _fileName!,
        bytes: bytes,
        ext: 'txt',
        mimeType: MimeType.text,
      );
      setState(() {
        _showSuccess = true;
      });
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF23262F) : Colors.white;
            final dialogText = isDark ? Colors.white : Colors.black;
            return AlertDialog(
              backgroundColor: dialogBg,
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Export Successful',
                      style: TextStyle(color: dialogText)),
                ],
              ),
              content: Text(
                  'File "$_fileName" has been saved to your device.\n\nYou can find it in your downloads or files app.',
                  style: TextStyle(color: dialogText)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK', style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to export: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF181A20) : Colors.white;
    final cardColor = isDark ? const Color(0xFF23262F) : Colors.grey[100];
    final borderColor =
        isDark ? Colors.blueGrey.shade700 : Colors.blueAccent.withOpacity(0.2);
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black87;
    final buttonColor = isDark ? Colors.blue[400] : Colors.blue;
    final successColor = isDark ? Colors.green[400] : Colors.green;
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Export', style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: buttonColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _prepareExport,
          ),
        ],
      ),
      backgroundColor: bgColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text('Error: $_error',
                      style: TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_stats != null) ...[
                        Text('Exported at: ${_stats!['exported_at']}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: textColor)),
                        SizedBox(height: 8),
                        Text('Total users: ${_stats!['total_users']}',
                            style: TextStyle(color: textColor)),
                        Text('Admins: ${_stats!['total_admins']}',
                            style: TextStyle(color: textColor)),
                        Text('Blocked users: ${_stats!['blocked_users']}',
                            style: TextStyle(color: textColor)),
                        Text('Pending requests: ${_stats!['pending_requests']}',
                            style: TextStyle(color: textColor)),
                        SizedBox(height: 16),
                      ],
                      Text('Preview:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: textColor)),
                      SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(_exportText ?? '',
                                style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    color: textColor)),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      Center(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.save_alt,
                              size: 28, color: Colors.white),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 8.0),
                            child: Text('Download as Text File',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: successColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 32, vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: _saveExport,
                        ),
                      ),
                      if (_showSuccess) ...[
                        SizedBox(height: 16),
                        Center(
                          child: Text('File "$_fileName" saved successfully!',
                              style: TextStyle(
                                  color: successColor,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
