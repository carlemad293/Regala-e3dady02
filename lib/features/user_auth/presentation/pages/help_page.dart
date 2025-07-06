// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth for user instance
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/app_drawer.dart'; // Import the AppDrawer
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HelpScreen extends StatefulWidget {
  @override
  _HelpScreenState createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  List<Map<String, dynamic>> _fixers = [];
  TextEditingController searchController = TextEditingController();
  String sortBy = 'name'; // Default sort by name
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFixers();
    searchController.addListener(() {
      filterFixers();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFixers() async {
    try {
      setState(() => _isLoading = true);

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
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading fixers: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load fixers: $e')),
      );
    }
  }

  void filterFixers() {
    final query = searchController.text.toLowerCase();
    setState(() {
      _fixers = _fixers.where((fixer) {
        final name = fixer['name'].toString().toLowerCase();
        final number = fixer['number'].toString().toLowerCase();
        return name.contains(query) || number.contains(query);
      }).toList();
      sortFixers(); // Sort the filtered results
    });
  }

  void sortFixers() {
    setState(() {
      _fixers.sort((a, b) {
        if (sortBy == 'name') {
          return a['name'].compareTo(b['name']);
        } else if (sortBy == 'number') {
          return a['number'].compareTo(b['number']);
        }
        return 0;
      });
    });
  }

  Widget highlightText(String text, String query, {bool isName = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (query.isEmpty) {
      return Text(
        text,
        style: isName
            ? TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              )
            : TextStyle(color: isDark ? Colors.white : Colors.black),
      );
    }
    final matches = query.toLowerCase().allMatches(text.toLowerCase());
    if (matches.isEmpty) {
      return Text(
        text,
        style: isName
            ? TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              )
            : TextStyle(color: isDark ? Colors.white : Colors.black),
      );
    }
    final spans = <TextSpan>[];
    int start = 0;
    for (final match in matches) {
      if (match.start != start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          backgroundColor: isDark ? Colors.amber[900] : Colors.yellow,
          color: isDark ? Colors.white : Colors.black,
        ),
      ));
      start = match.end;
    }
    if (start != text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ));
    }
    return RichText(
      text: TextSpan(
        style: isName
            ? TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              )
            : TextStyle(color: isDark ? Colors.white : Colors.black),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(''),
        backgroundColor: isDark ? Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      drawer: user != null ? AppDrawer(user: user) : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Color(0xFF1A1A1A), Color(0xFF2A2A2A)]
                : [Colors.white, Colors.grey[200]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('resources')
                    .doc('whatsapp_group_link')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                      child: ListTile(
                        title: Text(
                          'Error loading group link',
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black),
                        ),
                        subtitle: Text(
                          snapshot.error.toString(),
                          style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Card(
                      color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                      child: ListTile(
                        title: Text(
                          'Group link not available',
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black),
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final groupLink = data['link'] as String? ?? '';

                  return Card(
                    color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                    elevation: 5,
                    margin: EdgeInsets.only(bottom: 20.h),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, color: Colors.red),
                          SizedBox(width: 8.w),
                          CircleAvatar(
                            backgroundImage:
                                AssetImage('assets/logo_el_group.png'),
                            radius: 22.r,
                          ),
                        ],
                      ),
                      title: Text(
                        'رجالة اعدادي مارجرجس',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                            color: isDark ? Colors.white : Colors.black),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.arrow_forward,
                            color: isDark ? Colors.white70 : Colors.black87),
                        onPressed: () async {
                          if (groupLink.isNotEmpty) {
                            final Uri url = Uri.parse(groupLink);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Could not launch WhatsApp')),
                              );
                            }
                          }
                        },
                      ),
                      onTap: () async {
                        if (groupLink.isNotEmpty) {
                          final Uri url = Uri.parse(groupLink);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Could not launch WhatsApp')),
                            );
                          }
                        }
                      },
                    ),
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Search',
                        labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87),
                        prefixIcon: Icon(Icons.search,
                            color: isDark ? Colors.white70 : Colors.black87),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(
                              color: isDark ? Colors.grey[700]! : Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(
                              color: isDark ? Colors.grey[700]! : Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(
                              color: isDark ? Colors.blue[300]! : Colors.blue),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  DropdownButton<String>(
                    value: sortBy,
                    dropdownColor: isDark ? Color(0xFF2A2A2A) : Colors.white,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black),
                    onChanged: (String? newValue) {
                      setState(() {
                        sortBy = newValue!;
                        sortFixers();
                      });
                    },
                    items: <String>['name', 'number']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text('Sort by $value'),
                      );
                    }).toList(),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? Colors.blue[300]! : Colors.blue,
                          ),
                        ),
                      )
                    : _fixers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64.sp,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.blue.withOpacity(0.5),
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'No fixers found',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.blue.withOpacity(0.7),
                                    fontSize: 18.sp,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _fixers.length,
                            itemBuilder: (context, index) {
                              final fixer = _fixers[index];
                              final name = fixer['name'].toString();
                              final number = fixer['number'].toString();
                              return Dismissible(
                                key: Key(fixer['id']),
                                direction: DismissDirection.horizontal,
                                background: slideRightBackground(),
                                secondaryBackground: slideLeftBackground(),
                                confirmDismiss: (direction) async {
                                  if (await Vibration.hasVibrator() ?? false) {
                                    Vibration.vibrate(duration: 50);
                                  }
                                  if (direction ==
                                      DismissDirection.startToEnd) {
                                    _launchWhatsApp(context, number);
                                  } else if (direction ==
                                      DismissDirection.endToStart) {
                                    _launchCall(context, number);
                                  }
                                  return false;
                                },
                                child: GestureDetector(
                                  onLongPress: () {
                                    _showActionDialog(context, name, number);
                                  },
                                  child: Card(
                                    margin: EdgeInsets.symmetric(vertical: 8.0),
                                    elevation: 5,
                                    color: isDark
                                        ? Color(0xFF2A2A2A)
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      title: highlightText(
                                          name, searchController.text,
                                          isName: true),
                                      subtitle: highlightText(
                                          number, searchController.text),
                                      trailing: Container(
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Color(0xFF3A3A3A)
                                              : Colors.grey[100],
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              spreadRadius: 1,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: IconButton(
                                          icon: Icon(Icons.copy,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87),
                                          onPressed: () async {
                                            Clipboard.setData(
                                                ClipboardData(text: number));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      '$number copied to clipboard')),
                                            );
                                            if (await Vibration.hasVibrator() ??
                                                false) {
                                              Vibration.vibrate(duration: 50);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget slideRightBackground() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: Colors.transparent,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.only(left: 20.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Color(0xFF2A2A2A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: CircleAvatar(
          backgroundColor: Colors.transparent,
          radius: 30,
          child: FaIcon(
            FontAwesomeIcons.whatsapp,
            color: Colors.green,
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget slideLeftBackground() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: Colors.transparent,
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(right: 20.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Color(0xFF2A2A2A) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: CircleAvatar(
          backgroundColor: Colors.transparent,
          radius: 30,
          child: Icon(
            Icons.call,
            color: Colors.blue,
            size: 30,
          ),
        ),
      ),
    );
  }

  void _showActionDialog(BuildContext context, String name, String number) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Color(0xFF2A2A2A) : Colors.white,
          title: Text(
            'Choose Action',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                title: Text(
                  'WhatsApp',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                onTap: () async {
                  if (await Vibration.hasVibrator() ?? false) {
                    Vibration.vibrate(duration: 50);
                  }
                  _launchWhatsApp(context, number);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: Icon(Icons.call, color: Colors.blue),
                title: Text(
                  'Call',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                onTap: () async {
                  if (await Vibration.hasVibrator() ?? false) {
                    Vibration.vibrate(duration: 50);
                  }
                  _launchCall(context, number);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _launchWhatsApp(BuildContext context, String number) async {
    final cleanedNumber = number.replaceAll(RegExp(r'\D'), '');
    final Uri url = Uri.parse('https://wa.me/$cleanedNumber');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch WhatsApp')),
      );
    }
  }

  void _launchCall(BuildContext context, String number) async {
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not make the call')),
      );
    }
  }
}
