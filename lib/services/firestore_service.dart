import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/institution_utils.dart';
import '../utils/search_index_utils.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create User Document
  Future<void> createUser({
    required String uid,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final collegeName = (userData['college_name'] ?? '').toString();
      final institutionId =
          (userData['institution_id'] ?? '').toString().trim().isNotEmpty
              ? userData['institution_id']
              : InstitutionUtils.idFromCollegeName(collegeName);

      await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
        ...userData,
        'institution_id': institutionId,
        'full_name_lower': SearchIndexUtils.normalize(
            (userData['full_name'] ?? '').toString()),
        'search_keywords': SearchIndexUtils.keywords([
          userData['full_name']?.toString(),
          userData['email']?.toString(),
          userData['enrollment_number']?.toString(),
          userData['course']?.toString(),
          userData['branch']?.toString(),
          userData['department']?.toString(),
        ]),
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

  Stream<List<UserModel>> searchUsersByCollege({
    required String collegeName,
    String? institutionId,
    String query = '',
  }) {
    final normalizedQuery = SearchIndexUtils.normalize(query);
    var legacyQuery = _firestore
        .collection(AppConstants.usersCollection)
        .where('college_name', isEqualTo: collegeName);

    final Stream<List<UserModel>> source;
    if (institutionId == null || institutionId.isEmpty) {
      if (normalizedQuery.isNotEmpty) {
        legacyQuery = legacyQuery.where(
          'search_keywords',
          arrayContains: normalizedQuery,
        );
      }
      source = legacyQuery.limit(30).snapshots().map(
          (snapshot) => snapshot.docs.map(UserModel.fromFirestore).toList());
    } else {
      var institutionQuery = _firestore
          .collection(AppConstants.usersCollection)
          .where('institution_id', isEqualTo: institutionId);
      if (normalizedQuery.isNotEmpty) {
        legacyQuery = legacyQuery.where(
          'search_keywords',
          arrayContains: normalizedQuery,
        );
        institutionQuery = institutionQuery.where(
          'search_keywords',
          arrayContains: normalizedQuery,
        );
      }
      source = _mergeDocumentStreams(
        primary: institutionQuery.limit(30).snapshots(),
        legacy: legacyQuery.limit(30).snapshots(),
        mapper: UserModel.fromFirestore,
        compare: (a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
    }

    return source;
  }

  // Update User Profile
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
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
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
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
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
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
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
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
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
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

  Stream<List<T>> _mergeDocumentStreams<T>({
    required Stream<QuerySnapshot<Map<String, dynamic>>> primary,
    required Stream<QuerySnapshot<Map<String, dynamic>>> legacy,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) mapper,
    int Function(T a, T b)? compare,
  }) {
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
        primarySubscription;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
        legacySubscription;
    final controller = StreamController<List<T>>();
    Map<String, T> primaryItems = {};
    Map<String, T> legacyItems = {};
    var hasPrimary = false;
    var hasLegacy = false;

    void emit() {
      if (!hasPrimary || !hasLegacy || controller.isClosed) return;
      final merged = <String, T>{...legacyItems, ...primaryItems};
      final values = merged.values.toList();
      if (compare != null) {
        values.sort(compare);
      }
      controller.add(values);
    }

    controller.onListen = () {
      primarySubscription = primary.listen(
        (snapshot) {
          primaryItems = {
            for (final doc in snapshot.docs) doc.id: mapper(doc),
          };
          hasPrimary = true;
          emit();
        },
        onError: controller.addError,
      );
      legacySubscription = legacy.listen(
        (snapshot) {
          legacyItems = {
            for (final doc in snapshot.docs) doc.id: mapper(doc),
          };
          hasLegacy = true;
          emit();
        },
        onError: controller.addError,
      );
    };
    controller.onCancel = () async {
      await primarySubscription.cancel();
      await legacySubscription.cancel();
    };

    return controller.stream;
  }
}
