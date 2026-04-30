import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/club_model.dart';
import '../models/membership_request_model.dart';
import '../utils/constants.dart';

class MembershipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String requestIdFor(String clubId, String userId) => '${clubId}_$userId';

  Stream<MembershipRequestModel?> streamUserRequest({
    required String clubId,
    required String userId,
  }) {
    return _firestore
        .collection('membership_requests')
        .doc(requestIdFor(clubId, userId))
        .snapshots()
        .map((doc) => doc.exists ? MembershipRequestModel.fromFirestore(doc) : null);
  }

  Stream<List<MembershipRequestModel>> getPendingRequests(String clubId) {
    return _firestore
        .collection('membership_requests')
        .where('club_id', isEqualTo: clubId)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .orderBy('requested_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MembershipRequestModel.fromFirestore).toList());
  }

  Future<void> sendJoinRequest({
    required ClubModel club,
    required String userId,
    required String userName,
    String? message,
  }) async {
    if (!club.isAcceptingMembers) {
      throw Exception('This club is not accepting new members right now.');
    }
    if (club.members.contains(userId)) {
      throw Exception('You are already a member of this club.');
    }

    final requestId = requestIdFor(club.clubId, userId);
    final requestRef = _firestore.collection('membership_requests').doc(requestId);
    final existingRequest = await requestRef.get();

    if (existingRequest.exists) {
      final request = MembershipRequestModel.fromFirestore(existingRequest);
      if (request.status == RequestStatus.pending) {
        throw Exception('Your join request is already pending.');
      }
    }

    final request = MembershipRequestModel(
      requestId: requestId,
      clubId: club.clubId,
      clubName: club.name,
      userId: userId,
      userName: userName,
      message: message,
      requestedAt: DateTime.now(),
    );

    await requestRef.set(request.toFirestore());
  }

  Future<void> respondToRequest({
    required MembershipRequestModel request,
    required RequestStatus status,
    required String respondedById,
  }) async {
    final batch = _firestore.batch();
    final requestRef = _firestore.collection('membership_requests').doc(request.requestId);

    batch.update(requestRef, {
      'status': status.name,
      'responded_at': FieldValue.serverTimestamp(),
      'responded_by_id': respondedById,
    });

    if (status == RequestStatus.approved) {
      final clubRef = _firestore.collection(AppConstants.clubsCollection).doc(request.clubId);
      final userRef = _firestore.collection(AppConstants.usersCollection).doc(request.userId);
      batch.update(clubRef, {
        'members': FieldValue.arrayUnion([request.userId]),
        'total_members': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });
      batch.update(userRef, {
        'clubs_joined': FieldValue.arrayUnion([request.clubId]),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> leaveClub({
    required ClubModel club,
    required String userId,
  }) async {
    if (club.presidentId == userId || club.organizers.contains(userId)) {
      throw Exception('Role holders must be reassigned before leaving this club.');
    }

    final batch = _firestore.batch();
    final clubRef = _firestore.collection(AppConstants.clubsCollection).doc(club.clubId);
    final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);

    batch.update(clubRef, {
      'members': FieldValue.arrayRemove([userId]),
      'total_members': FieldValue.increment(-1),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(userRef, {
      'clubs_joined': FieldValue.arrayRemove([club.clubId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> setOrganizerRole({
    required String clubId,
    required String userId,
    required bool isOrganizer,
  }) async {
    final batch = _firestore.batch();
    final clubRef = _firestore.collection(AppConstants.clubsCollection).doc(clubId);
    final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);

    batch.update(clubRef, {
      'organizers': isOrganizer ? FieldValue.arrayUnion([userId]) : FieldValue.arrayRemove([userId]),
      'members': FieldValue.arrayUnion([userId]),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(userRef, {
      'is_organizer_of': isOrganizer ? FieldValue.arrayUnion([clubId]) : FieldValue.arrayRemove([clubId]),
      'clubs_joined': FieldValue.arrayUnion([clubId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> assignPresident({
    required String clubId,
    required String oldPresidentId,
    required String newPresidentId,
    required String newPresidentName,
  }) async {
    final batch = _firestore.batch();
    final clubRef = _firestore.collection(AppConstants.clubsCollection).doc(clubId);

    batch.update(clubRef, {
      'president_id': newPresidentId,
      'president_name': newPresidentName,
      'members': FieldValue.arrayUnion([newPresidentId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    if (oldPresidentId.isNotEmpty) {
      batch.update(_firestore.collection(AppConstants.usersCollection).doc(oldPresidentId), {
        'is_president_of': FieldValue.arrayRemove([clubId]),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    batch.update(_firestore.collection(AppConstants.usersCollection).doc(newPresidentId), {
      'is_president_of': FieldValue.arrayUnion([clubId]),
      'clubs_joined': FieldValue.arrayUnion([clubId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
