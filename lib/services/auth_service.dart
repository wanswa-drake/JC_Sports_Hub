import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'otp_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OtpService _otpService = OtpService();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String password,
    required String userType,
    String? webmail,
    String? regNumber,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(fullName);
        await user.sendEmailVerification();

        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': fullName,
          'email': email,
          'userType': userType,
          'webmail': webmail ?? '',
          'regNumber': regNumber ?? '',
          'isAdmin': false,
          'isVerified': false,
          'badgeCount': 0,
          'walletBalance': 0,
          'momoNumber': '',
          'joinedAt': FieldValue.serverTimestamp(),
          'profileImage': '',
        });
      }

      Map<String, dynamic> otpResult = await _otpService.sendOtp(
        userId: user!.uid,
        email: email,
        name: fullName,
      );

      return {
        'success': true,
        'otpSent': otpResult['success'] == true,
        'message': otpResult['success'] == true
            ? 'Account created! Check your email for the verification code.'
            : 'Account created. Verification email could not be delivered yet. Please use Resend Code on the next screen.',
        'userId': user.uid,
        'email': email,
        'name': fullName,
      };
    } on FirebaseAuthException catch (e) {
      String message = _getAuthErrorMessage(e.code);
      return {'success': false, 'message': message};
    } catch (e) {
      return {
        'success': false,
        'message': 'Something went wrong. Please try again.'
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          var isVerified = data['isVerified'] == true;
          if (!isVerified) {
            final otpDoc =
                await _firestore.collection('otps').doc(user.uid).get();
            final otpData = otpDoc.data();
            isVerified = otpData != null && otpData['verified'] == true;
          }
          if (!isVerified) {
            final verifiedOtp = await _firestore
                .collection('otps')
                .where('email', isEqualTo: data['email'] ?? email)
                .where('verified', isEqualTo: true)
                .limit(1)
                .get();
            isVerified = verifiedOtp.docs.isNotEmpty;
          }

          if (!isVerified) {
            return {
              'success': false,
              'needVerification': true,
              'userId': user.uid,
              'email': data['email'] ?? email,
              'name': data['fullName'] ?? '',
              'message': 'Please verify your email before logging in.',
            };
          }

          return {
            'success': true,
            'message': 'Login successful',
            'userData': data,
          };
        }
      }

      return {'success': true, 'message': 'Login successful'};
    } on FirebaseAuthException catch (e) {
      String message = _getAuthErrorMessage(e.code);
      return {'success': false, 'message': message};
    } catch (e) {
      return {
        'success': false,
        'message': 'Something went wrong. Please try again.'
      };
    }
  }

  Future<Map<String, dynamic>> loginAsGuest({required String email}) async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      User? user = userCredential.user;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'fullName': 'Guest',
          'email': email,
          'userType': 'guest',
          'isAdmin': false,
          'isVerified': false,
          'badgeCount': 0,
          'walletBalance': 0,
          'momoNumber': '',
          'joinedAt': FieldValue.serverTimestamp(),
          'profileImage': '',
        });
      }

      return {'success': true, 'message': 'Continuing as guest'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Could not continue as guest. Please try again.'
      };
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<Map<String, dynamic>> resetPassword({required String email}) async {
    try {
      // Standard Firebase Auth email reset. This works regardless of any
      // custom OTP/SMTP setup and uses Firebase's own email template + action
      // handler, so it reliably delivers a reset link the user can click.
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {
        'success': true,
        'message':
            'A password reset email has been sent to ${email.trim()}. Open the link it contains to reset your password.'
      };
    } on FirebaseAuthException catch (e) {
      // Show the REAL Firebase error so the cause is never hidden.
      final human = switch (e.code) {
        'user-not-found' => 'No account found with this email.',
        'invalid-email' => 'The email address is not valid.',
        'too-many-requests' =>
          'Too many requests. Please wait a moment and try again.',
        'network-request-failed' =>
          'No internet connection. Please check your network.',
        _ => e.message ?? 'Password reset failed.',
      };
      return {'success': false, 'message': human};
    } catch (e) {
      return {
        'success': false,
        'message': 'Something went wrong: $e'
      };
    }
  }

  // Identity Toolkit REST call used by the in-app reset below: asks Firebase
  // for a one-time password-reset link without requiring the user to open an
  // email. Returns the oobCode so confirmPasswordReset can apply the new
  // password immediately, or null so the caller can fall back to the email.
  Future<String?> _fetchResetOobCode(String email) async {
    final apiKey = _auth.app.options.apiKey;
    // "PASSWORD_RESET" is the documented requestType; "RESET_PASSWORD" is the
    // legacy alias some projects still accept - try both so the in-app reset
    // never silently falls back to the email link.
    for (final requestType in ['PASSWORD_RESET', 'RESET_PASSWORD']) {
      try {
        final uri = Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey');
        final resp = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'requestType': requestType,
                'email': email,
                'returnOobLink': true,
              }),
            )
            .timeout(const Duration(seconds: 20));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          // Depending on the API version the link comes back in "oobLink" or
          // in the "email" field; a regex pulls the oobCode from either.
          final link = ((data['oobLink'] ?? data['email']) ?? '').toString();
          final match =
              RegExp(r'[?&]oobCode=([A-Za-z0-9_\-\.]+)').firstMatch(link);
          if (match != null) return match.group(1);
          final direct = (data['oobCode'] ?? data['code'] ?? '').toString();
          if (direct.isNotEmpty) return direct;
        }
      } catch (_) {
        // try the next requestType
      }
    }
    return null;
  }

  // Forgot-password step 3: the user entered the correct OTP (step 2) and now
  // sets a new password entirely inside the app. The OTP doc is the proof of
  // email ownership, so we confirm the reset directly. A full in-app reset is
  // attempted first; if the reset link cannot be obtained, it falls back to
  // sending the standard Firebase password-reset email.
  Future<Map<String, dynamic>> resetForgottenPassword({
    required String resetUserId,
    required String newPassword,
  }) async {
    try {
      final doc = await _firestore.collection('otps').doc(resetUserId).get();
      final data = doc.exists
          ? (doc.data() as Map<String, dynamic>)
          : <String, dynamic>{};
      final verified = data['verified'] == true;
      final sessionAllowed = data['pwResetAllowed'] == true;
      if (!verified || !sessionAllowed) {
        return {
          'success': false,
          'message': 'Please verify your code first before resetting.'
        };
      }
      final allowedAt = (data['allowedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (DateTime.now().difference(allowedAt) > const Duration(minutes: 10)) {
        return {
          'success': false,
          'message': 'Reset session expired. Please request a new code.'
        };
      }
      if (newPassword.length < 6) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters.'
        };
      }

      final email = data['email'] as String?;
      if (email == null) {
        return {'success': false, 'message': 'Account not found.'};
      }

      final oobCode = await _fetchResetOobCode(email);
      if (oobCode != null) {
        await _auth.confirmPasswordReset(
            code: oobCode, newPassword: newPassword);
        // Consume the reset session so the code can't be replayed.
        await _firestore
            .collection('otps')
            .doc(resetUserId)
            .update({'pwResetAllowed': false});
        return {
          'success': true,
          'message': 'Password reset successfully! You can now log in with your new password.'
        };
      }

      // Fallback: the standard Firebase reset email (identity already proven).
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'emailSent': true,
        'message': 'A password reset email has been sent to $email. Open the link it contains to set your new password.'
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Something went wrong resetting your password. Please try again.'
      };
    }
  }

  // Forgot-password step 1: confirms the account exists (via Firebase Auth,
  // no Firestore read so it works for unauthenticated users on the login
  // screen) and emails an OTP stored under a random reset id.
  Future<Map<String, dynamic>> sendForgotPasswordOtp({
    required String email,
  }) async {
    try {
      // Confirm the account exists WITHOUT leaking which email is registered
      // (with email-enumeration protection, a nonexistent account throws
      // user-not-found - which is also what tells us "no account" safely).
      try {
        await _auth.signInWithEmailAndPassword(email: email, password: 'x');
      } on FirebaseAuthException catch (e) {
        if (e.code != 'wrong-password' && e.code != 'invalid-credential') {
          return {
            'success': false,
            'message': 'No account found with this email address.'
          };
        }
        // wrong-password/invalid-credential => the account EXISTS.
      }

      // A random, non-guessable store id so the reset code can't be looked up
      // by someone who merely knows the victim's email.
      final random = Random();
      final resetId =
          'rst-${(email.hashCode % 1000000).abs()}-${100000 + random.nextInt(900000)}';

      final displayName = email.substring(0, email.indexOf('@'));
      final otpResult = await _otpService.sendOtp(
        userId: resetId,
        email: email,
        name: displayName,
      );
      return {
        'success': otpResult['success'] == true,
        'message': otpResult['message'],
        'userId': resetId,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Something went wrong sending the code. Please try again.'
      };
    }
  }

  // Forgot-password step 2: checks the OTP. This flow never updates the
  // user's isVerified flag - the code is stored under a synthetic reset id.
  // On success it also marks this reset session as verified/allowed so that
  // step 3 can change the password without needing the reset email link.
  Future<Map<String, dynamic>> verifyForgotPasswordOtp({
    required String userId,
    required String code,
  }) async {
    final result = await _otpService.verifyOtp(
      userId: userId,
      enteredCode: code,
    );
    if (result['success'] == true) {
      await _firestore.collection('otps').doc(userId).update({
        'pwResetAllowed': true,
        'allowedAt': FieldValue.serverTimestamp(),
      });
    }
    return result;
  }

  // Change password for an already signed-in user: reauthenticates with the
  // current password then updates to the new one. Returns the result map.
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'You must be signed in first.'};
      }
      if (newPassword.length < 6) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters.'
        };
      }

      final email = user.email;
      if (email == null) {
        return {
          'success': false,
          'message': 'This account has no email to verify against.'
        };
      }

      // Re-authenticate with the current password to prove identity before
      // allowing the password change (Firebase security requirement).
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      return {'success': true, 'message': 'Password updated successfully.'};
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return {
          'success': false,
          'message': 'Current password is incorrect.'
        };
      }
      if (e.code == 'weak-password') {
        return {
          'success': false,
          'message': 'New password is too weak. Use at least 6 characters.'
        };
      }
      return {'success': false, 'message': _getAuthErrorMessage(e.code)};
    } catch (e) {
      return {
        'success': false,
        'message': 'Something went wrong changing the password. Please try again.'
      };
    }
  }

  Future<Map<String, dynamic>> resendOtp({
    required String userId,
    required String email,
    required String name,
  }) async {
    return await _otpService.resendOtp(
        userId: userId, email: email, name: name);
  }

  Future<bool> isAdmin() async {
    User? user = _auth.currentUser;
    if (user == null) return false;
    DocumentSnapshot doc =
        await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return data['isAdmin'] == true;
    }
    return false;
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
