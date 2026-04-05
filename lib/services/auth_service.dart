import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  User? get currentUser => _user;

  String? _verificationId;
  int? _resendToken;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Send Magic Link to Email
  Future<Map<String, dynamic>> sendMagicLink(String email) async {
    try {
      var acs = ActionCodeSettings(
        url: 'https://klubconnect.page.link/login', // Configure in Firebase Console
        handleCodeInApp: true,
        androidPackageName: 'com.example.klub_connect',
        androidInstallApp: true,
        androidMinimumVersion: '1',
      );

      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: acs,
      );

      return {
        'success': true,
        'message': 'Magic link sent to your email!',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error sending link: ${e.toString()}',
      };
    }
  }

  // Complete Sign In with Email Link
  Future<Map<String, dynamic>> signInWithEmailLink(String email, String emailLink) async {
    try {
      if (_auth.isSignInWithEmailLink(emailLink)) {
        final UserCredential userCredential = await _auth.signInWithEmailLink(
          email: email,
          emailLink: emailLink,
        );
        
        // Update last login
        await _firestoreService.updateUserLastLogin(userCredential.user!.uid);

        return {
          'success': true,
          'message': 'Login successful',
          'user': userCredential.user,
        };
      }
      return {
        'success': false,
        'message': 'Invalid login link',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Login failed: ${e.toString()}',
      };
    }
  }

  // Register with Email and Password
  Future<Map<String, dynamic>> registerWithEmailPassword({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestoreService.createUser(
        uid: userCredential.user!.uid,
        userData: userData,
      );

      return {
        'success': true,
        'message': 'Registration successful',
        'user': userCredential.user,
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed';
      switch (e.code) {
        case 'weak-password': errorMessage = 'The password provided is too weak'; break;
        case 'email-already-in-use': errorMessage = 'An account already exists for this email'; break;
        case 'invalid-email': errorMessage = 'The email address is not valid'; break;
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign In with Email and Password
  Future<Map<String, dynamic>> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestoreService.updateUserLastLogin(userCredential.user!.uid);

      return {
        'success': true,
        'message': 'Login successful',
        'user': userCredential.user,
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed';
      switch (e.code) {
        case 'user-not-found': errorMessage = 'No account found with this email'; break;
        case 'wrong-password': errorMessage = 'Incorrect password'; break;
        case 'invalid-credential': errorMessage = 'Invalid email or password'; break;
      }
      return {'success': false, 'message': errorMessage};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Send OTP to Phone
  Future<Map<String, dynamic>> sendPhoneOTP(String phoneNumber) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (kDebugMode) print('Phone verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );
      return {'success': true, 'message': 'OTP sent successfully'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Verify Phone OTP
  Future<Map<String, dynamic>> verifyPhoneOTP(String otp) async {
    try {
      if (_verificationId == null) {
        return {'success': false, 'message': 'Verification ID is null. Please resend OTP'};
      }
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      if (_auth.currentUser != null) {
        await _auth.currentUser!.linkWithCredential(credential);
      } else {
        await _auth.signInWithCredential(credential);
      }
      return {'success': true, 'message': 'Phone verified successfully'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      if (_user != null) {
        await _firestoreService.updateUserOnlineStatus(_user!.uid, false);
      }
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) print('Sign out error: $e');
    }
  }

  // Reset Password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {'success': true, 'message': 'Password reset email sent'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
