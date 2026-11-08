import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'utils/constants.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/tournaments/tournaments_screen.dart';

// Used to show a snackbar from a Firebase push message even when the app is
// in the foreground and no screen is actively showing a ScaffoldMessenger.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') {
        rethrow;
      }
    }
  }

  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
  } catch (e) {
    debugPrint('App Check activation failed: $e');

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.debug,
      );
    } catch (e2) {
      debugPrint('Debug App Check also failed: $e2');
    }
  }

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );
  _setupPushNotifications();

  runApp(const MyApp());
}

// Requests notification permission, keeps the device's FCM token in sync on
// the user's Firestore document, and shows a snackbar for incoming messages
// while the app is in the foreground.
Future<void> _setupPushNotifications() async {
  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted = settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return;

    Future<void> saveToken(String? token) async {
      if (token == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            'fcmTokens': FieldValue.arrayUnion([token]),
          }, SetOptions(merge: true));
    }

    await saveToken(await messaging.getToken());
    messaging.onTokenRefresh.listen(saveToken);

    // A different user logging in on this device should also get this
    // device's token saved under their own uid.
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) messaging.getToken().then(saveToken);
    });

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      appMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('${notification.title ?? 'JC Sports Hub'}\n'
              '${notification.body ?? ''}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          backgroundColor: AppColors.primary,
        ),
      );
    });
  } catch (e) {
    debugPrint('Push notification setup failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const LoginScreen(),
        '/verify-otp': (context) => const OtpScreen(),
        '/admin-login': (context) => const AdminLoginScreen(),
        '/admin-panel': (context) => const AdminPanelScreen(),
        '/home': (context) =>
            const HomeScreen(),
        '/tournaments': (context) => const TournamentsScreen(),
      },
    );
  }
}
