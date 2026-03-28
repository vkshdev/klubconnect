import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club_model.dart';
import '../models/membership_request_model.dart';

class ClubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Club
  Future<void> createClub(ClubModel club) async {
    try {
      await _firestore.collection('clubs').doc(club.clubId).set(club.toFirestore());
      
      // Update faculty's clubs_created
      await _firestore.collection('users').doc(club.clubMasterId).update({
        'clubs_created': FieldValue.arrayUnion([club.clubId])
      });
      
      // Update president's role
      await _firestore.collection('users').doc(club.presidentId).update({
        'is_president_of': FieldValue.arrayUnion([club.clubId]),
        'clubs_joined': FieldValue.arrayUnion([club.clubId])
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get Clubs by College
  Stream<List<ClubModel>> getClubsByCollege(String collegeName) {
    return _firestore
        .collection('clubs')
        .where('college_name', isEqualTo: collegeName)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClubModel.fromFirestore(doc))
            .toList());
  }

  // Get Club by ID
  Stream<ClubModel> streamClub(String clubId) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .snapshots()
        .map((doc) => ClubModel.fromFirestore(doc));
  }

  // Send Membership Request
  Future<void> sendJoinRequest({
    required String clubId,
    required String clubName,
    required String userId,
    required String userName,
    String? message,
  }) async {
    final requestId = '${clubId}_$userId';
    final request = MembershipRequestModel(
      requestId: requestId,
      clubId: clubId,
      clubName: clubName,
      userId: userId,
      userName: userName,
      message: message,
      requestedAt: DateTime.now(),
    );

    await _firestore
        .collection('membership_requests')
        .doc(requestId)
        .set(request.toFirestore());
  }

  // Handle Membership Request
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
      // Add user to club members
      final clubRef = _firestore.collection('clubs').doc(request.clubId);
      batch.update(clubRef, {
        'members': FieldValue.arrayUnion([request.userId]),
        'total_members': FieldValue.increment(1),
      });

      // Update user's joined clubs
      final userRef = _firestore.collection('users').doc(request.userId);
      batch.update(userRef, {
        'clubs_joined': FieldValue.arrayUnion([request.clubId]),
      });
    }

    await batch.commit();
  }

  // Get Pending Requests for Club
  Stream<List<MembershipRequestModel>> getPendingRequests(String clubId) {
    return _firestore
        .collection('membership_requests')
        .where('club_id', isEqualTo: clubId)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MembershipRequestModel.fromFirestore(doc))
            .toList());
  }

  // Leave Club
  Future<void> leaveClub(String clubId, String userId) async {
    final batch = _firestore.batch();

    final clubRef = _firestore.collection('clubs').doc(clubId);
    batch.update(clubRef, {
      'members': FieldValue.arrayRemove([userId]),
      'total_members': FieldValue.increment(-1),
    });

    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'clubs_joined': FieldValue.arrayRemove([clubId]),
    });

    await batch.commit();
  }
}
