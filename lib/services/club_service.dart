import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/club_model.dart';
import '../models/club_membership_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../utils/institution_utils.dart';
import '../utils/search_index_utils.dart';
import 'audit_log_service.dart';
import 'image_upload_service.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLogService _auditLogService = AuditLogService();
  final ImageUploadService _imageUploadService = ImageUploadService();

  Future<void> createClub(ClubModel club) async {
    final batch = _firestore.batch();
    final clubRef =
        _firestore.collection(AppConstants.clubsCollection).doc(club.clubId);
    final masterRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(club.clubMasterId);
    final presidentRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(club.presidentId);
    final institutionId = club.institutionId.isNotEmpty
        ? club.institutionId
        : InstitutionUtils.idFromCollegeName(club.collegeName);
    final presidentMembership = ClubMembershipModel(
      membershipId: club.presidentId,
      clubId: club.clubId,
      userId: club.presidentId,
      userName: club.presidentName,
      institutionId: institutionId,
      role: ClubMembershipRole.president,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    batch.set(
        clubRef, club.copyWith(institutionId: institutionId).toFirestore());
    batch.update(masterRef, {
      'clubs_created': FieldValue.arrayUnion([club.clubId]),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(presidentRef, {
      'is_president_of': FieldValue.arrayUnion([club.clubId]),
      'clubs_joined': FieldValue.arrayUnion([club.clubId]),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.set(
      clubRef.collection('memberships').doc(club.presidentId),
      presidentMembership.toFirestore(),
    );
    batch.set(
      presidentRef.collection('club_memberships').doc(club.clubId),
      presidentMembership.toUserMirrorFirestore(
        clubName: club.name,
        clubCategory: club.category,
        clubLogoUrl: club.logoUrl,
      ),
    );

    await batch.commit();
    await _auditLogService.record(
      institutionId: institutionId,
      actorUserId: club.clubMasterId,
      actorRole: 'faculty',
      action: 'club_created',
      targetType: 'club',
      targetId: club.clubId,
      metadata: {
        'club_name': club.name,
        'president_id': club.presidentId,
      },
    );
  }

  Stream<List<ClubModel>> getClubsByCollege(
    String collegeName, {
    String? institutionId,
  }) {
    final legacyQuery = _firestore
        .collection(AppConstants.clubsCollection)
        .where('college_name', isEqualTo: collegeName)
        .where('is_active', isEqualTo: true);

    if (institutionId == null || institutionId.isEmpty) {
      return legacyQuery.snapshots().map(
          (snapshot) => snapshot.docs.map(ClubModel.fromFirestore).toList());
    }

    final institutionQuery = _firestore
        .collection(AppConstants.clubsCollection)
        .where('institution_id', isEqualTo: institutionId)
        .where('is_active', isEqualTo: true);

    return _mergeDocumentStreams(
      primary: institutionQuery.snapshots(),
      legacy: legacyQuery.snapshots(),
      mapper: ClubModel.fromFirestore,
      compare: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  Stream<List<ClubModel>> getClubsForUser(List<String> clubIds) {
    if (clubIds.isEmpty) return Stream.value([]);
    return _streamDocumentsByIdChunks(
      ids: clubIds,
      collection: _firestore.collection(AppConstants.clubsCollection),
      mapper: ClubModel.fromFirestore,
      compare: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  Stream<ClubModel?> streamClub(String clubId) {
    return _firestore
        .collection(AppConstants.clubsCollection)
        .doc(clubId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ClubModel.fromFirestore(doc);
    });
  }

  Future<ClubModel?> getClubById(String clubId) async {
    final doc = await _firestore
        .collection(AppConstants.clubsCollection)
        .doc(clubId)
        .get();
    if (!doc.exists) return null;
    return ClubModel.fromFirestore(doc);
  }

  Stream<List<UserModel>> streamCollegeStudents(
    String collegeName, {
    String? institutionId,
  }) {
    final legacyQuery = _firestore
        .collection(AppConstants.usersCollection)
        .where('college_name', isEqualTo: collegeName)
        .where('user_type', isEqualTo: AppConstants.userTypeStudent);

    if (institutionId == null || institutionId.isEmpty) {
      return legacyQuery.snapshots().map(
          (snapshot) => snapshot.docs.map(UserModel.fromFirestore).toList());
    }

    final institutionQuery = _firestore
        .collection(AppConstants.usersCollection)
        .where('institution_id', isEqualTo: institutionId)
        .where('user_type', isEqualTo: AppConstants.userTypeStudent);

    return _mergeDocumentStreams(
      primary: institutionQuery.snapshots(),
      legacy: legacyQuery.snapshots(),
      mapper: UserModel.fromFirestore,
      compare: (a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  }

  Stream<List<UserModel>> streamClubMembers(List<String> memberIds) {
    if (memberIds.isEmpty) return Stream.value([]);
    return _streamDocumentsByIdChunks(
      ids: memberIds,
      collection: _firestore.collection(AppConstants.usersCollection),
      mapper: UserModel.fromFirestore,
      compare: (a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  }

  Stream<List<ClubMembershipModel>> streamClubMemberships(
    String clubId, {
    int limit = 50,
  }) {
    return _firestore
        .collection(AppConstants.clubsCollection)
        .doc(clubId)
        .collection('memberships')
        .where('status', isEqualTo: ClubMembershipStatus.active.name)
        .orderBy('joined_at', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(ClubMembershipModel.fromFirestore).toList());
  }

  Stream<List<ClubModel>> searchClubs({
    required String collegeName,
    String? institutionId,
    String query = '',
    String? category,
  }) {
    Query<Map<String, dynamic>> legacyRef = _firestore
        .collection(AppConstants.clubsCollection)
        .where('college_name', isEqualTo: collegeName)
        .where('is_active', isEqualTo: true);

    Query<Map<String, dynamic>>? institutionRef;
    if (institutionId != null && institutionId.isNotEmpty) {
      institutionRef = _firestore
          .collection(AppConstants.clubsCollection)
          .where('institution_id', isEqualTo: institutionId)
          .where('is_active', isEqualTo: true);
    }

    if (category != null && category.isNotEmpty && category != 'All') {
      legacyRef = legacyRef.where('category', isEqualTo: category);
      institutionRef = institutionRef?.where('category', isEqualTo: category);
    }

    final normalizedQuery = SearchIndexUtils.normalize(query);
    if (normalizedQuery.isNotEmpty) {
      legacyRef =
          legacyRef.where('search_keywords', arrayContains: normalizedQuery);
      institutionRef = institutionRef?.where(
        'search_keywords',
        arrayContains: normalizedQuery,
      );
    }
    legacyRef = legacyRef.limit(30);
    institutionRef = institutionRef?.limit(30);

    final source = institutionRef == null
        ? legacyRef.snapshots().map(
            (snapshot) => snapshot.docs.map(ClubModel.fromFirestore).toList())
        : _mergeDocumentStreams(
            primary: institutionRef.snapshots(),
            legacy: legacyRef.snapshots(),
            mapper: ClubModel.fromFirestore,
            compare: (a, b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return source;
  }

  Future<void> updateClub(String clubId, Map<String, dynamic> updates) async {
    await _firestore
        .collection(AppConstants.clubsCollection)
        .doc(clubId)
        .update({
      ...updates,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadClubImage({
    required String clubId,
    required File image,
    required String fileName,
    required String ownerId,
    required String institutionId,
  }) async {
    return _imageUploadService.uploadCompressedImage(
      image: image,
      storagePath: 'clubs/$clubId/$fileName',
      ownerId: ownerId,
      institutionId: institutionId,
      ownerType: 'club',
    );
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

  Stream<List<T>> _streamDocumentsByIdChunks<T>({
    required List<String> ids,
    required CollectionReference<Map<String, dynamic>> collection,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) mapper,
    int Function(T a, T b)? compare,
  }) {
    final uniqueIds = ids.toSet().toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < uniqueIds.length; i += 10) {
      chunks.add(uniqueIds.skip(i).take(10).toList());
    }

    final controller = StreamController<List<T>>();
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final chunkItems = <int, Map<String, T>>{};

    void emit() {
      if (chunkItems.length != chunks.length || controller.isClosed) return;
      final merged = <String, T>{};
      for (final items in chunkItems.values) {
        merged.addAll(items);
      }
      final values = merged.values.toList();
      if (compare != null) values.sort(compare);
      controller.add(values);
    }

    controller.onListen = () {
      for (var index = 0; index < chunks.length; index++) {
        final chunk = chunks[index];
        final subscription = collection
            .where(FieldPath.documentId, whereIn: chunk)
            .snapshots()
            .listen(
          (snapshot) {
            chunkItems[index] = {
              for (final doc in snapshot.docs) doc.id: mapper(doc),
            };
            emit();
          },
          onError: controller.addError,
        );
        subscriptions.add(subscription);
      }
    };
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }
}
