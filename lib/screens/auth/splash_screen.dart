// We import Flutter's UI toolkit
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// We import our constants file so we can use AppColors, AppStrings, AppSizes
import '../../utils/constants.dart';

// SplashScreen is a StatefulWidget because it CHANGES over time
// Specifically - it shows for a few seconds then navigates away
// StatefulWidget has two classes - the widget itself and its State
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  // createState() links this widget to its State class
  // Flutter calls this automatically when the widget is first created
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// The State class is where all the logic and data lives
// The underscore _ before the name means it's private - only this file can use it
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // AnimationController controls our animation - its speed, direction, repeat
  // 'late' means we'll assign this value soon, not right now
  late AnimationController _animationController;

  // Animation<double> holds a value that changes smoothly over time
  // We'll use it to fade the logo in from invisible to fully visible
  late Animation<double> _fadeAnimation;

  // initState() is called ONCE when this screen first appears
  // It's like the screen's constructor - set up everything here
  @override
  void initState() {
    super
        .initState(); // Always call super.initState() first - Flutter requires it

    // Create the animation controller
    // vsync: this - prevents animations from running when screen is off (saves battery)
    // duration - how long the animation takes to complete
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // 1.5 seconds to fade in
    );

    // Tween defines the START and END values of our animation
    // We go from 0.0 (completely invisible) to 1.0 (completely visible)
    // .animate() connects the tween to our controller
    // CurvedAnimation makes the transition smooth instead of robotic
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn, // Starts slow, speeds up - feels natural
      ),
    );

    // Start the fade animation immediately
    _animationController.forward();

    // After 3 seconds, navigate to the next screen
    _navigateToNext();
  }

  // This function waits 3 seconds then decides where to send the user
  // This function waits 3 seconds then decides where to send the user
  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    debugPrint('STEP 1: Checking current user');
    User? currentUser = FirebaseAuth.instance.currentUser;
    debugPrint('STEP 2: currentUser = ${currentUser?.uid}');

    if (currentUser != null) {
      debugPrint('STEP 3: Fetching Firestore doc for ${currentUser.uid}');
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        print('STEP 4: Firestore doc fetched, exists = ${userDoc.exists}');

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          final firebaseVerified = currentUser.emailVerified == true;
          var isVerified = firebaseVerified || data['isVerified'] == true;
          if (!isVerified) {
            final otpDoc = await FirebaseFirestore.instance
                .collection('otps')
                .doc(currentUser.uid)
                .get();
            isVerified = otpDoc.data()?['verified'] == true;
          }

          if (!mounted) return;

          if (isVerified) {
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            Navigator.pushReplacementNamed(
              context,
              '/verify-otp',
              arguments: {
                'userId': currentUser.uid,
                'email': data['email'],
                'name': data['fullName'],
              },
            );
          }
        } else {
          Navigator.pushReplacementNamed(context, '/onboarding');
        }
      } catch (e) {
        debugPrint('STEP ERROR: Firestore fetch failed: $e');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } else {
      debugPrint('STEP 3-ALT: No user logged in, going to onboarding');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  // dispose() is called when the screen is permanently removed
  // Always dispose controllers to free up memory - very important habit
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // build() draws the screen - Flutter calls this whenever the screen needs redrawing
  @override
  Widget build(BuildContext context) {
    // Scaffold is the basic screen structure in Flutter
    // It provides background color, app bar slot, body slot etc
    return Scaffold(
      // backgroundColor sets the screen's background
      backgroundColor: AppColors.primary,

      // body is the main content area of the screen
      body: Center(
        // FadeTransition animates opacity using our _fadeAnimation
        // As _fadeAnimation goes from 0.0 to 1.0, the child fades in
        child: FadeTransition(
          opacity: _fadeAnimation,

          // Column stacks widgets vertically
          child: Column(
            // mainAxisAlignment controls vertical positioning
            mainAxisAlignment: MainAxisAlignment.center,

            // crossAxisAlignment controls horizontal positioning
            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              // App logo - using a soccer ball icon for now
              // We'll replace with a real logo later
              Container(
                // Container is a box widget - we can style it with decoration
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  // Colors.white.withOpacity() makes white slightly transparent
                  color: Colors.white.withOpacity(0.2),

                  // BorderRadius makes the corners rounded
                  // .circular() makes all 4 corners equally rounded - a circle
                  borderRadius: BorderRadius.circular(60),
                ),

                // child is the widget INSIDE the container
                child: const Icon(
                  Icons.sports_soccer,
                  color: Colors.white,
                  size: 70,
                ),
              ),

              // SizedBox with height creates vertical space between widgets
              const SizedBox(height: 32),

              // App name text
              const Text(
                AppStrings.appName, // Using our constant instead of hardcoding
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: AppSizes.fontXL,
                  fontWeight: FontWeight.bold,
                  // letterSpacing adds space between each letter
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 8),

              // University name subtitle
              Text(
                AppStrings.university,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: AppSizes.fontSmall,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 60),

              // Loading indicator at the bottom
              // CircularProgressIndicator shows a spinning circle
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  // strokeWidth is how thick the spinning circle is
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    // AlwaysStoppedAnimation keeps a fixed color on the indicator
                    Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
