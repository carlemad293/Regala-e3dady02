import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import '../../../app/notification_service.dart';

class SignInScreen extends StatefulWidget {
  static Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      final secureStorage = FlutterSecureStorage();
      final email = await secureStorage.read(key: 'email');
      final password = await secureStorage.read(key: 'password');

      if (email != null && password != null) {
        try {
          final userCredential =
              await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          if (userCredential.user != null) {
            return true;
          }
        } catch (e) {
          print('Auto-login check failed: $e');
          // Clear invalid credentials
          await secureStorage.deleteAll();
          await prefs.setBool('isLoggedIn', false);
        }
      }
    }
    return false;
  }

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  String _errorMessage = '';
  String _successMessage = '';
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    String? email = await _secureStorage.read(key: 'email');
    String? password = await _secureStorage.read(key: 'password');
    String? name = await _secureStorage.read(key: 'name');

    if (email != null) {
      _emailController.text = email;
    }
    if (password != null) {
      _passwordController.text = password;
    }
    if (name != null) {
      _nameController.text = name;
    }
  }

  Future<void> _saveCredentials(
      String email, String password, String name) async {
    await _secureStorage.write(key: 'email', value: email);
    await _secureStorage.write(key: 'password', value: password);
    await _secureStorage.write(key: 'name', value: name);
  }

  Future<void> _saveLoginState(String email, String password) async {
    // This function will only handle the isLoggedIn flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
  }

  Future<void> login() async {
    setState(() {
      _errorMessage = '';
      _successMessage = '';
    });

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _nameController.text.trim().isEmpty ||
        !RegExp(r'[a-zA-Z]').hasMatch(_nameController.text)) {
      setState(() {
        _errorMessage = 'Please enter a valid name with letters';
      });
      return;
    }

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        setState(() {
          _successMessage = 'Signing in successfully...';
        });

        // Update the user's display name in Firebase Auth
        await userCredential.user!
            .updateDisplayName(_nameController.text.trim());

        // Update the user's name in Firestore
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.email);
        await userDoc.set({
          'name': _nameController.text.trim(),
          'email': userCredential.user!.email,
        }, SetOptions(merge: true));

        // Save credentials securely
        await _saveCredentials(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );

        // Save login state
        await _saveLoginState(
          _emailController.text.trim(),
          _passwordController.text,
        );

        // Save notification token for the user
        final notificationService = NotificationService();
        await notificationService.savePendingToken();

        // Get the updated user data
        final userSnapshot = await userDoc.get();
        if (userSnapshot.exists) {
          final userData = userSnapshot.data() as Map<String, dynamic>;
          final points = userData['points'] ?? 0;

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
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email';
          break;
        case 'wrong-password':
          message = 'Wrong password provided';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        default:
          message = 'An error occurred. Please try again';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF1A1A1A) : Colors.white,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'assets/crosses_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.only(top: 20.0, left: 25.0, right: 25.0),
                child: Card(
                  elevation: 6,
                  color: isDark ? Color(0xFF2A2A2A) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Container(
                    width: 500,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 20.0),
                    child: AutofillGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/cross.png',
                              height: 160.0,
                              width: 120.0,
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Sign in to continue',
                            style: TextStyle(
                              fontSize: 18,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 24),
                          _buildTextField(
                            controller: _nameController,
                            label: 'Name',
                            icon: Icons.person_outline,
                          ),
                          SizedBox(height: 20),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: 20),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.login, size: 24),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                textStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: login,
                              label: Text('Sign In'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300),
                tween: Tween(begin: -1.0, end: 0.0),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value * 100),
                    child: Opacity(
                      opacity: 1 + value,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.red.shade900.withOpacity(0.3)
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.red.shade700
                                  : Colors.red.shade200,
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
                                  color: isDark
                                      ? Colors.red.shade800.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 500),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  curve: Curves.elasticOut,
                                  builder: (context, value, child) {
                                    return Transform.rotate(
                                      angle: value * 2 * 3.14159,
                                      child: Icon(
                                        Icons.error_outline,
                                        color: isDark
                                            ? Colors.red.shade300
                                            : Colors.red,
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.red.shade300
                                        : Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color:
                                      isDark ? Colors.red.shade300 : Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = '';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_successMessage.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300),
                tween: Tween(begin: -1.0, end: 0.0),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value * 100),
                    child: Opacity(
                      opacity: 1 + value,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.green.shade900.withOpacity(0.3)
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.green.shade700
                                  : Colors.green.shade200,
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
                                  color: isDark
                                      ? Colors.green.shade800.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 500),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  curve: Curves.elasticOut,
                                  builder: (context, value, child) {
                                    return Transform.rotate(
                                      angle: value * 2 * 3.14159,
                                      child: Icon(
                                        Icons.check_circle_outline,
                                        color: isDark
                                            ? Colors.green.shade300
                                            : Colors.green,
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _successMessage,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.green.shade300
                                        : Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: isDark
                                      ? Colors.green.shade300
                                      : Colors.green,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _successMessage = '';
                                  });
                                },
                              ),
                            ],
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueAccent, width: 2),
        ),
        filled: true,
        fillColor: isDark ? Color(0xFF3A3A3A) : Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
      autofillHints: isPassword
          ? [AutofillHints.password]
          : label.toLowerCase() == 'email'
              ? [AutofillHints.email]
              : label.toLowerCase() == 'name'
                  ? [AutofillHints.name]
                  : null,
    );
  }
}
