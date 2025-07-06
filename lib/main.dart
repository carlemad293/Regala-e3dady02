import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:regala_e3dady/features/app/splash_screen/splash_screen.dart';
import 'package:regala_e3dady/features/app/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:regala_e3dady/features/app/theme/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

// Background message handler function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Check if Firebase is already initialized
    Firebase.app();
    print("Firebase already initialized in background handler");
  } catch (e) {
    // Initialize Firebase only if not already initialized
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDGKsJEnyO4GSLA2GDi-Hi2wbl68T0a0xo',
        appId: '1:697018854717:web:9d42721dc27e8966396954',
        messagingSenderId: '697018854717',
        projectId: 'dma-app-a8112',
        storageBucket: "dma-app-a8112.appspot.com",
      ),
    );
    print("Firebase initialized in background handler");
  }
  print("Handling a background message: ${message.messageId}");
}

Future<void> initializeFirebase() async {
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDGKsJEnyO4GSLA2GDi-Hi2wbl68T0a0xo",
          appId: "1:697018854717:web:9d42721dc27e8966396954",
          messagingSenderId: "697018854717",
          projectId: "dma-app-a8112",
          storageBucket: "dma-app-a8112.appspot.com",
        ),
      );
    } else {
      // Try to initialize with default configuration first
      try {
        await Firebase.initializeApp();
        print('Firebase initialized with default configuration');
      } catch (e) {
        print(
            'Default Firebase initialization failed, trying explicit configuration: $e');
        // Fallback to explicit configuration
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyCrN8GdZqFmbO02BwOKs8yRluc9oKiXQmU",
            appId: "1:697018854717:ios:4c61095b22d053d3396954",
            messagingSenderId: "697018854717",
            projectId: "dma-app-a8112",
            storageBucket: "dma-app-a8112.appspot.com",
          ),
        );
        print('Firebase initialized with explicit configuration');
      }
    }

    // Verify Firebase initialization
    Firebase.app();
    print('Firebase verification successful');

    // Register the background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    print('Background message handler registered');
  } catch (e) {
    print('Firebase initialization failed: $e');
    print('App will continue without Firebase services');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await initializeFirebase();

  // Initialize Notification Service
  try {
    await NotificationService().initialize();
    print('Notification service initialized successfully');
  } catch (e) {
    print('Failed to initialize notification service: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.themeMode == ThemeMode.dark
        ? ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(
              Theme.of(context).textTheme,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            drawerTheme: DrawerThemeData(
              backgroundColor: Color(0xFF1A1A1A),
              elevation: 0,
            ),
            cardColor: Color(0xFF2A2A2A),
            scaffoldBackgroundColor: Color(0xFF121212),
          )
        : ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.poppinsTextTheme(
              Theme.of(context).textTheme,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            drawerTheme: DrawerThemeData(
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            cardColor: Colors.white,
          );

    return AnimatedTheme(
      data: theme,
      duration: Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Regala e3dady",
        themeMode: themeProvider.themeMode,
        theme: theme,
        darkTheme: theme,
        home: SplashScreen(),
      ),
    );
  }
}

Future<bool> _checkLoginStatus() async {
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
        await secureStorage.deleteAll();
        await prefs.setBool('isLoggedIn', false);
      }
    }
  }
  return false;
}

Future<Map<String, dynamic>> _getUserData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.email)
      .get();

  return userDoc.data() ?? {};
}
