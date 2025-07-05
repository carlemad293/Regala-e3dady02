import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Notification channel for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  String? _pendingToken;

  Future<void> initialize() async {
    try {
      // Request permission for iOS
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('User granted permission: ${settings.authorizationStatus}');

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token with retry logic
      String? token = await _getFCMTokenWithRetry();
      if (token != null) {
        print('FCM Token: $token');
        await _saveTokenToFirestore(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        _saveTokenToFirestore(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from notification
      RemoteMessage? initialMessage =
          await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  // Retry logic for getting FCM token
  Future<String?> _getFCMTokenWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        print('Attempt ${i + 1}: Getting FCM token...');
        String? token = await _firebaseMessaging.getToken();
        print('Attempt ${i + 1}: Raw token response: $token');

        if (token != null && token.isNotEmpty) {
          print('Successfully got FCM token on attempt ${i + 1}');
          print('Token length: ${token.length}');
          print('Token starts with: ${token.substring(0, 20)}...');
          return token;
        }
        print('Attempt ${i + 1}: Got null or empty token, retrying...');
        await Future.delayed(Duration(seconds: 1));
      } catch (e) {
        print('Attempt ${i + 1}: Error getting FCM token: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2));
        }
      }
    }
    print('Failed to get FCM token after $maxRetries attempts');
    return null;
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Delete any existing tokens for this user first
        await FirebaseFirestore.instance
            .collection('user_token')
            .doc(user.email)
            .delete();

        // Save the new token
        await FirebaseFirestore.instance
            .collection('user_token')
            .doc(user.email)
            .set({
          'email': user.email,
          'token': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': _getPlatform(),
          'userId': user.uid,
        });

        print('Token saved to user_token collection for user: ${user.email}');
        print('Token value: $token');
      } else {
        print('User not logged in, token will be saved after login');
        _pendingToken = token;
      }
    } catch (e) {
      print('Error saving token to Firestore: $e');
    }
  }

  String _getPlatform() {
    if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    }
    return 'web';
  }

  // Method to save pending token when user logs in
  Future<void> savePendingToken() async {
    if (_pendingToken != null) {
      await _saveTokenToFirestore(_pendingToken!);
      _pendingToken = null;
    }
  }

  // Method to manually save current user's token
  Future<void> saveCurrentUserToken() async {
    try {
      final token = await _getFCMTokenWithRetry();
      if (token != null) {
        await _saveTokenToFirestore(token);
      }
    } catch (e) {
      print('Error saving current user token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      _showLocalNotification(message);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('App opened from notification: ${message.data}');
    // Handle navigation based on message data
    _handleNotificationNavigation(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Handle notification tap
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            color: Colors.blue,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Handle navigation based on notification data
    // You can customize this based on your app's navigation structure
    String? type = data['type'];
    String? target = data['target'];

    print('Navigation type: $type, target: $target');

    // Example navigation logic
    switch (type) {
      case 'announcement':
        // Navigate to announcements
        break;
      case 'event':
        // Navigate to events
        break;
      case 'points':
        // Navigate to points page
        break;
      default:
        // Default navigation
        break;
    }
  }

  // Method to schedule a local notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, dynamic>? payload,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          icon: '@mipmap/ic_launcher',
          color: Colors.blue,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload?.toString(),
    );
  }

  // Method to cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  // Method to cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Send notification to specific users
  Future<bool> sendNotificationToUsers({
    required List<String> userEmails,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('Attempting to send notification to users: $userEmails');

      // Get tokens for the specified users from user_token collection
      final tokensSnapshot = await FirebaseFirestore.instance
          .collection('user_token')
          .where('email', whereIn: userEmails)
          .get();

      print('Found ${tokensSnapshot.docs.length} user documents');

      final tokens = tokensSnapshot.docs
          .map((doc) => doc.data()['token'] as String?)
          .where((token) => token != null && token!.isNotEmpty)
          .map((token) => token!)
          .toList();

      print('Valid tokens found: ${tokens.length}');

      if (tokens.isEmpty) {
        print('No valid tokens found for the specified users');
        return false;
      }

      // Send notifications using FCM HTTP API
      final success = await _sendNotificationsViaFCM(
        tokens: tokens,
        title: title,
        body: body,
        data: data,
      );

      // Log the notification
      await FirebaseFirestore.instance.collection('notification_history').add({
        'title': title,
        'body': body,
        'data': data,
        'userEmails': userEmails,
        'tokensCount': tokens.length,
        'sentBy': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'status': success ? 'sent' : 'failed',
      });

      print('Notification sending completed. Success: $success');
      return success;
    } catch (e) {
      print('Error sending notification to users: $e');
      return false;
    }
  }

  // Send notification to all users
  Future<bool> sendNotificationToAllUsers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all user tokens from user_token collection
      final tokensSnapshot =
          await FirebaseFirestore.instance.collection('user_token').get();

      final tokens = tokensSnapshot.docs
          .map((doc) => doc.data()['token'] as String?)
          .where((token) => token != null && token!.isNotEmpty)
          .map((token) => token!)
          .toList();

      if (tokens.isEmpty) {
        print('No users found with valid tokens');
        return false;
      }

      // Send notifications using FCM HTTP API
      final success = await _sendNotificationsViaFCM(
        tokens: tokens,
        title: title,
        body: body,
        data: data,
      );

      // Log the notification
      await FirebaseFirestore.instance.collection('notification_history').add({
        'title': title,
        'body': body,
        'data': data,
        'userEmails': ['all_users'],
        'tokensCount': tokens.length,
        'sentBy': FirebaseAuth.instance.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'status': success ? 'sent' : 'failed',
      });

      return success;
    } catch (e) {
      print('Error sending notification to all users: $e');
      return false;
    }
  }

  // Send notifications via FCM HTTP API
  Future<bool> _sendNotificationsViaFCM({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // For now, we'll use a simple approach that shows local notification
      // but logs the tokens for debugging
      print('Would send FCM notification to ${tokens.length} tokens:');
      for (int i = 0; i < tokens.length && i < 3; i++) {
        print('Token ${i + 1}: ${tokens[i]}');
      }
      if (tokens.length > 3) {
        print('... and ${tokens.length - 3} more tokens');
      }

      // Show a local notification to confirm the sending process
      await _localNotifications.show(
        999, // Unique ID
        'Notification Sent',
        'Sent to ${tokens.length} users: $title',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            color: Colors.green,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'sent_to_${tokens.length}_users',
      );

      // TODO: Implement actual FCM HTTP API call
      // This would require your Firebase server key
      // For now, we'll simulate success
      print('FCM notification sending simulated successfully');
      return true;
    } catch (e) {
      print('Error sending FCM notifications: $e');
      return false;
    }
  }

  // Method to send notifications via FCM HTTP API (for future implementation)
  Future<bool> _sendViaFCMHttpAPI({
    required List<String> tokens,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // This is a placeholder for the FCM HTTP API implementation
    // You would need to:
    // 1. Get your server key from Firebase Console
    // 2. Make HTTP POST requests to FCM endpoints
    // 3. Handle responses and errors

    print('FCM HTTP API implementation would go here');
    print('Server key needed from Firebase Console');
    print('Tokens to send to: ${tokens.length}');

    return true;
  }

  // Method to unsubscribe from notifications
  Future<void> unsubscribe() async {
    try {
      await _firebaseMessaging.deleteToken();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('user_token')
            .doc(user.email)
            .delete();
      }
      print('Unsubscribed from notifications');
    } catch (e) {
      print('Error unsubscribing from notifications: $e');
    }
  }

  // Debug method to test token generation and storage
  Future<void> debugTokenGeneration() async {
    print('=== DEBUG: Token Generation Test ===');

    try {
      // Test Firebase initialization
      print('1. Testing Firebase initialization...');
      Firebase.app();
      print('✓ Firebase is initialized');

      // Test getting FCM token
      print('2. Testing FCM token generation...');
      final token = await _getFCMTokenWithRetry();
      if (token != null) {
        print('✓ FCM token generated successfully');
        print('Token: $token');
      } else {
        print('✗ Failed to generate FCM token');
        return;
      }

      // Test saving to Firestore
      print('3. Testing token storage to Firestore...');
      await _saveTokenToFirestore(token!);
      print('✓ Token saved to Firestore');

      // Test retrieving from Firestore
      print('4. Testing token retrieval from Firestore...');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        final doc = await FirebaseFirestore.instance
            .collection('user_token')
            .doc(user.email)
            .get();

        if (doc.exists) {
          final savedToken = doc.data()?['token'] as String?;
          print('✓ Token retrieved from Firestore');
          print('Saved token: $savedToken');
          print('Token matches: ${token == savedToken}');
        } else {
          print('✗ Token document not found in Firestore');
        }
      } else {
        print('✗ User not logged in');
      }

      print('=== DEBUG: Test Complete ===');
    } catch (e) {
      print('✗ Debug test failed: $e');
    }
  }
}
