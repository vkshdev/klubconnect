import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create User Document
  Future<void> createUser({
    required String uid,
    required Map<String, dynamic> userData,
  }) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
        ...userData,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'is_active': true,
        'is_online': false,
        'profile_completed': false,
        'clubs_joined': [],
        'clubs_created': [],
        'is_president_of': [],
        'is_organizer_of': [],
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error creating user document: $e');
      }
      rethrow;
    }
  }

  // Get User by ID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user: $e');
      }
      return null;
    }
  }

  // Stream User Data
  Stream<UserModel?> streamUser(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Update User Profile
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
        ...updates,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user profile: $e');
      }
      rethrow;
    }
  }

  // Update Last Login
  Future<void> updateUserLastLogin(String uid) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
        'last_login': FieldValue.serverTimestamp(),
        'is_online': true,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating last login: $e');
      }
    }
  }

  // Update Online Status
  Future<void> updateUserOnlineStatus(String uid, bool isOnline) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
        'is_online': isOnline,
        if (!isOnline) 'last_seen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating online status: $e');
      }
    }
  }

  // Mark Profile as Complete
  Future<void> markProfileComplete(String uid) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
        'profile_completed': true,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error marking profile complete: $e');
      }
      rethrow;
    }
  }

  // Check if Email Exists
  Future<bool> checkEmailExists(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking email: $e');
      }
      return false;
    }
  }

  // Check if Enrollment Number Exists
  Future<bool> checkEnrollmentExists(String enrollmentNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('enrollment_number', isEqualTo: enrollmentNumber.toUpperCase())
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking enrollment: $e');
      }
      return false;
    }
  }

  // Update Profile Image URL
  Future<void> updateProfileImage(String uid, String imageUrl) async {
    try {
      await _firestore.collection(AppConstants.usersCollection).doc(uid).update({
        'profile_image_url': imageUrl,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating profile image: $e');
      }
      rethrow;
    }
  }
}