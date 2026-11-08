import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../utils/secrets.dart';

class OtpService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _senderEmail = AppSecrets.senderEmail;
  late final SmtpServer _smtpServer = AppSecrets.smtpServer;

  // Generates a random 6-digit number as a string
  // Example output: "847291"
  String _generateOtp() {
    final random = Random();
    // nextInt(900000) gives 0-899999, adding 100000 ensures always 6 digits
    int otp = 100000 + random.nextInt(900000);
    return otp.toString();
  }

  // Sends OTP email via Gmail SMTP and saves code to Firestore
  Future<Map<String, dynamic>> sendOtp({
    required String userId,
    required String email,
    required String name,
  }) async {
    try {
      // Step 1 - Generate the OTP code
      final String otpCode = _generateOtp();

      // Step 2 - Calculate expiry time (10 minutes from now)
      final DateTime expiryTime = DateTime.now().add(
        const Duration(minutes: 10),
      );

      // Step 3 - Save OTP to Firestore BEFORE sending the email
      // This way the code exists in our database even if email sending fails
      await _firestore.collection('otps').doc(userId).set({
        'code': otpCode,
        'expiresAt': Timestamp.fromDate(expiryTime),
        'email': email,
        'verified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Step 4 - Build the email message
      // Message() is the mailer package's class for constructing an email
      final message = Message()
        // from sets the sender - shows as "JC Sports Hub <wanswadrake@gmail.com>"
        ..from = const Address(_senderEmail, 'JC Sports Hub')
        // recipients is a list - we're sending to one person
        ..recipients.add(email)
        ..subject = 'JC Sports Hub - Your Verification Code'
        // text is the plain text body of the email
        ..text = '''
Hello $name,

Your JC Sports Hub verification code is:

$otpCode

This code expires in 10 minutes.

Do not share this code with anyone.

- JC Sports Hub Team
''';

      // Step 5 - Actually send the email through Gmail's SMTP server
      // send() is an async function from the mailer package
      // It connects to Gmail, authenticates, and delivers the email
      final sendReport = await send(message, _smtpServer);

      // Print for debugging - visible in VS Code terminal
      debugPrint('===== Email Sent =====');
      debugPrint('Message sent: ${sendReport.toString()}');
      debugPrint('=======================');

      return {
        'success': true,
        'message': 'Verification code sent to $email',
      };
    } on MailerException catch (e) {
      // MailerException is thrown specifically when SMTP sending fails
      // e.problems contains a list of specific issues (auth failure, connection issue etc)
      debugPrint('===== Mailer Exception =====');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code} - ${p.msg}');
      }
      debugPrint('=============================');

      // Delete the OTP since email failed to send
      await _firestore.collection('otps').doc(userId).delete();

      return {
        'success': false,
        'message': 'Failed to send email: ${e.problems.isNotEmpty ? e.problems[0].msg : e.toString()}',
      };
    } catch (e) {
      debugPrint('===== General Exception =====');
      debugPrint(e.toString());
      debugPrint('==============================');

      return {
        'success': false,
        'message': 'Something went wrong sending the email. Please try again.',
      };
    }
  }

  // Verifies the OTP code the user typed.
  Future<Map<String, dynamic>> verifyOtp({
    required String userId,
    required String enteredCode,
  }) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('otps').doc(userId).get();

      if (!doc.exists) {
        return {
          'success': false,
          'message': 'No verification code found. Please request a new one.',
        };
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['verified'] == true) {
        return {
          'success': false,
          'message': 'This code has already been used.',
        };
      }

      DateTime expiryTime = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiryTime)) {
        return {
          'success': false,
          'message': 'Code has expired. Please request a new one.',
        };
      }

      if (data['code'] != enteredCode) {
        return {
          'success': false,
          'message': 'Incorrect code. Please try again.',
        };
      }

      // The OTP document is the verification record. This avoids depending
      // on a separately deployed users rule during the login verification
      // flow.
      await _firestore.collection('otps').doc(userId).update({
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Email verified successfully!',
      };
    } on FirebaseException catch (e) {
      debugPrint('===== Verify OTP Exception =====');
      debugPrint('${e.code}: ${e.message}');
      debugPrint('================================');
      return {
        'success': false,
        'message': 'Verification failed (${e.code}). Please try again.',
      };
    } catch (e) {
      debugPrint('===== Verify OTP Exception =====');
      debugPrint(e.toString());
      debugPrint('================================');
      return {
        'success': false,
        'message': 'Something went wrong. Please try again.',
      };
    }
  }

  // Resends a fresh OTP by calling sendOtp again
  Future<Map<String, dynamic>> resendOtp({
    required String userId,
    required String email,
    required String name,
  }) async {
    return await sendOtp(
      userId: userId,
      email: email,
      name: name,
    );
  }
}