import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/club_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> createClub(ClubModel club) async {
    final batch = _firestore.batch();
    final clubRef = _firestore.collection(AppConstants.clubsCollection).doc(club.clubId);
    final masterRef = _firestore.collection(AppConstants.usersCollection).doc(club.clubMasterId);
    final presidentRef = _firestore.collection(AppConstants.usersCollection).doc(club.presidentId);

    batch.set(clubRef, club.toFirestore());
    batch.update(masterRef, {
      'clubs_created': FieldValue.arrayUnion([club.clubId]),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(presidentRef, {
      'is_president_of': FieldValue.arrayUnion([club.clubId]),
      'clubs_joined': FieldValue.arrayUnion([club.clubId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Stream<List<ClubModel>> getClubsByCollege(String collegeName) {
    return _firestore
        .collection(AppConstants.clubsCollection)
        .where('college_name', isEqualTo: collegeName)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ClubModel.fromFirestore).toList());
  }

  Stream<List<ClubModel>> getClubsForUser(List<String> clubIds) {
    if (clubIds.isEmpty) return Stream.value([]);
    return _firestore
        .collection(AppConstants.clubsCollection)
        .where(FieldPath.documentId, whereIn: clubIds.take(10).toList())
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ClubModel.fromFirestore).toList());
  }

  Stream<ClubModel?> streamClub(String clubId) {
    return _firestore.collection(AppConstants.clubsCollection).doc(clubId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ClubModel.fromFirestore(doc);
    });
  }

  Future<ClubModel?> getClubById(String clubId) async {
    final doc = await _firestore.collection(AppConstants.clubsCollection).doc(clubId).get();
    if (!doc.exists) return null;
    return ClubModel.fromFirestore(doc);
  }

  Stream<List<UserModel>> streamCollegeStudents(String collegeName) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('college_name', isEqualTo: collegeName)
        .where('user_type', isEqualTo: AppConstants.userTypeStudent)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(UserModel.fromFirestore).toList());
  }

  Stream<List<UserModel>> streamClubMembers(List<String> memberIds) {
    if (memberIds.isEmpty) return Stream.value([]);
    return _firestore
        .collection(AppConstants.usersCollection)
        .where(FieldPath.documentId, whereIn: memberIds.take(10).toList())
        .snapshots()
        .map((snapshot) => snapshot.docs.map(UserModel.fromFirestore).toList());
  }

  Stream<List<ClubModel>> searchClubs({
    required String collegeName,
    String query = '',
    String? category,
  }) {
    Query<Map<String, dynamic>> ref = _firestore
        .collection(AppConstants.clubsCollection)
        .where('college_name', isEqualTo: collegeName)
        .where('is_active', isEqualTo: true);

    if (category != null && category.isNotEmpty && category != 'All') {
      ref = ref.where('category', isEqualTo: category);
    }

    final normalizedQuery = query.trim().toLowerCase();
    return ref.snapshots().map((snapshot) {
      final clubs = snapshot.docs.map(ClubModel.fromFirestore).toList();
      if (normalizedQuery.isEmpty) return clubs;
      return clubs
          .where((club) =>
              club.name.toLowerCase().contains(normalizedQuery) ||
              club.category.toLowerCase().contains(normalizedQuery) ||
              club.description.toLowerCase().contains(normalizedQuery))
          .toList();
    });
  }

  Future<void> updateClub(String clubId, Map<String, dynamic> updates) async {
    await _firestore.collection(AppConstants.clubsCollection).doc(clubId).update({
      ...updates,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadClubImage({
    required String clubId,
    required File image,
    required String fileName,
  }) async {
    final ref = _storage.ref().child('clubs').child(clubId).child(fileName);
    await ref.putFile(image);
    return ref.getDownloadURL();
  }
}
