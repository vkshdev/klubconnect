import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/club_model.dart';
import '../models/club_membership_model.dart';
import '../models/membership_request_model.dart';
import '../utils/constants.dart';
import '../utils/institution_utils.dart';
import 'audit_log_service.dart';

class MembershipService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLogService _auditLogService = AuditLogService();

  String requestIdFor(String clubId, String userId) => '${clubId}_$userId';

  Stream<MembershipRequestModel?> streamUserRequest({
    required String clubId,
    required String userId,
  }) {
    return _firestore
        .collection('membership_requests')
        .doc(requestIdFor(clubId, userId))
        .snapshots()
        .map((doc) =>
            doc.exists ? MembershipRequestModel.fromFirestore(doc) : null);
  }

  Stream<List<MembershipRequestModel>> getPendingRequests(String clubId) {
    return _firestore
        .collection('membership_requests')
        .where('club_id', isEqualTo: clubId)
        .where('status', isEqualTo: RequestStatus.pending.name)
        .orderBy('requested_at', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(MembershipRequestModel.fromFirestore).toList());
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
    final requestRef =
        _firestore.collection('membership_requests').doc(requestId);
    final existingRequest = await requestRef.get();

    if (existingRequest.exists) {
      final request = MembershipRequestModel.fromFirestore(existingRequest);
      if (request.status == RequestStatus.pending) {
        throw Exception('Your join request is already pending.');
      }
    }

    final request = MembershipRequestModel(
      requestId: requestId,
      institutionId: club.institutionId.isNotEmpty
          ? club.institutionId
          : InstitutionUtils.idFromCollegeName(club.collegeName),
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
    final requestRef =
        _firestore.collection('membership_requests').doc(request.requestId);

    batch.update(requestRef, {
      'status': status.name,
      'responded_at': FieldValue.serverTimestamp(),
      'responded_by_id': respondedById,
    });

    if (status == RequestStatus.approved) {
      final clubRef = _firestore
          .collection(AppConstants.clubsCollection)
          .doc(request.clubId);
      final userRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(request.userId);
      final clubDoc = await clubRef.get();
      final clubData = clubDoc.data() ?? {};
      final institutionId = request.institutionId.isNotEmpty
          ? request.institutionId
          : (clubData['institution_id'] ??
                  InstitutionUtils.idFromCollegeName(
                      clubData['college_name'] ?? ''))
              .toString();
      final membership = ClubMembershipModel(
        membershipId: request.userId,
        clubId: request.clubId,
        userId: request.userId,
        userName: request.userName,
        institutionId: institutionId,
        role: ClubMembershipRole.member,
        joinedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      batch.update(clubRef, {
        'members': FieldValue.arrayUnion([request.userId]),
        'total_members': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
      });
      batch.update(userRef, {
        'clubs_joined': FieldValue.arrayUnion([request.clubId]),
        'updated_at': FieldValue.serverTimestamp(),
      });
      batch.set(
        clubRef.collection('memberships').doc(request.userId),
        membership.toFirestore(),
      );
      batch.set(
        userRef.collection('club_memberships').doc(request.clubId),
        membership.toUserMirrorFirestore(
          clubName: request.clubName,
          clubCategory: (clubData['category'] ?? '').toString(),
          clubLogoUrl: clubData['logo_url']?.toString(),
        ),
      );
    }

    await batch.commit();
    await _auditLogService.record(
      institutionId: request.institutionId,
      actorUserId: respondedById,
      actorRole: 'club_manager',
      action: status == RequestStatus.approved
          ? 'membership_approved'
          : 'membership_rejected',
      targetType: 'membership_request',
      targetId: request.requestId,
      metadata: {
        'club_id': request.clubId,
        'user_id': request.userId,
      },
    );
  }

  Future<void> leaveClub({
    required ClubModel club,
    required String userId,
  }) async {
    if (club.presidentId == userId || club.organizers.contains(userId)) {
      throw Exception(
          'Role holders must be reassigned before leaving this club.');
    }

    final batch = _firestore.batch();
    final clubRef =
        _firestore.collection(AppConstants.clubsCollection).doc(club.clubId);
    final userRef =
        _firestore.collection(AppConstants.usersCollection).doc(userId);

    batch.update(clubRef, {
      'members': FieldValue.arrayRemove([userId]),
      'total_members': FieldValue.increment(-1),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(userRef, {
      'clubs_joined': FieldValue.arrayRemove([club.clubId]),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.set(
      clubRef.collection('memberships').doc(userId),
      {
        'status': ClubMembershipStatus.left.name,
        'role': ClubMembershipRole.member.name,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      userRef.collection('club_memberships').doc(club.clubId),
      {
        'status': ClubMembershipStatus.left.name,
        'role': ClubMembershipRole.member.name,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    await _auditLogService.record(
      institutionId: club.institutionId.isNotEmpty
          ? club.institutionId
          : InstitutionUtils.idFromCollegeName(club.collegeName),
      actorUserId: userId,
      actorRole: 'member',
      action: 'membership_left',
      targetType: 'club',
      targetId: club.clubId,
    );
  }

  Future<void> setOrganizerRole({
    required String clubId,
    required String userId,
    required String actorUserId,
    required bool isOrganizer,
  }) async {
    final batch = _firestore.batch();
    final clubRef =
        _firestore.collection(AppConstants.clubsCollection).doc(clubId);
    final userRef =
        _firestore.collection(AppConstants.usersCollection).doc(userId);
    final clubDoc = await clubRef.get();
    final userDoc = await userRef.get();
    final clubData = clubDoc.data() ?? {};
    final userData = userDoc.data() ?? {};
    final role =
        isOrganizer ? ClubMembershipRole.organizer : ClubMembershipRole.member;
    final membership = ClubMembershipModel(
      membershipId: userId,
      clubId: clubId,
      userId: userId,
      userName: (userData['full_name'] ?? '').toString(),
      userProfileImageUrl: userData['profile_image_url']?.toString(),
      institutionId: (clubData['institution_id'] ??
              InstitutionUtils.idFromCollegeName(
                  clubData['college_name'] ?? ''))
          .toString(),
      role: role,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    batch.update(clubRef, {
      'organizers': isOrganizer
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
      'members': FieldValue.arrayUnion([userId]),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(userRef, {
      'is_organizer_of': isOrganizer
          ? FieldValue.arrayUnion([clubId])
          : FieldValue.arrayRemove([clubId]),
      'clubs_joined': FieldValue.arrayUnion([clubId]),
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.set(
      clubRef.collection('memberships').doc(userId),
      membership.toFirestore(),
      SetOptions(merge: true),
    );
    batch.set(
      userRef.collection('club_memberships').doc(clubId),
      membership.toUserMirrorFirestore(
        clubName: (clubData['name'] ?? '').toString(),
        clubCategory: (clubData['category'] ?? '').toString(),
        clubLogoUrl: clubData['logo_url']?.toString(),
      ),
      SetOptions(merge: true),
    );

    await batch.commit();
    await _auditLogService.record(
      institutionId: membership.institutionId,
      actorUserId: actorUserId,
      actorRole: 'club_manager',
      action: isOrganizer ? 'organizer_assigned' : 'organizer_removed',
      targetType: 'club_membership',
      targetId: '${clubId}_$userId',
      metadata: {'club_id': clubId, 'user_id': userId},
    );
  }

  Future<void> assignPresident({
    required String clubId,
    required String oldPresidentId,
    required String newPresidentId,
    required String newPresidentName,
    required String actorUserId,
  }) async {
    final batch = _firestore.batch();
    final clubRef =
        _firestore.collection(AppConstants.clubsCollection).doc(clubId);
    final clubDoc = await clubRef.get();
    final clubData = clubDoc.data() ?? {};
    final institutionId = (clubData['institution_id'] ??
            InstitutionUtils.idFromCollegeName(clubData['college_name'] ?? ''))
        .toString();

    batch.update(clubRef, {
      'president_id': newPresidentId,
      'president_name': newPresidentName,
      'members': FieldValue.arrayUnion([newPresidentId]),
      'updated_at': FieldValue.serverTimestamp(),
    });

    if (oldPresidentId.isNotEmpty) {
      batch.update(
          _firestore
              .collection(AppConstants.usersCollection)
              .doc(oldPresidentId),
          {
            'is_president_of': FieldValue.arrayRemove([clubId]),
            'updated_at': FieldValue.serverTimestamp(),
          });
      batch.set(
        clubRef.collection('memberships').doc(oldPresidentId),
        {
          'role': ClubMembershipRole.member.name,
          'status': ClubMembershipStatus.active.name,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(
        _firestore
            .collection(AppConstants.usersCollection)
            .doc(oldPresidentId)
            .collection('club_memberships')
            .doc(clubId),
        {
          'role': ClubMembershipRole.member.name,
          'status': ClubMembershipStatus.active.name,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    batch.update(
        _firestore.collection(AppConstants.usersCollection).doc(newPresidentId),
        {
          'is_president_of': FieldValue.arrayUnion([clubId]),
          'clubs_joined': FieldValue.arrayUnion([clubId]),
          'updated_at': FieldValue.serverTimestamp(),
        });
    final newPresidentMembership = ClubMembershipModel(
      membershipId: newPresidentId,
      clubId: clubId,
      userId: newPresidentId,
      userName: newPresidentName,
      institutionId: institutionId,
      role: ClubMembershipRole.president,
      joinedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    batch.set(
      clubRef.collection('memberships').doc(newPresidentId),
      newPresidentMembership.toFirestore(),
      SetOptions(merge: true),
    );
    batch.set(
      _firestore
          .collection(AppConstants.usersCollection)
          .doc(newPresidentId)
          .collection('club_memberships')
          .doc(clubId),
      newPresidentMembership.toUserMirrorFirestore(
        clubName: (clubData['name'] ?? '').toString(),
        clubCategory: (clubData['category'] ?? '').toString(),
        clubLogoUrl: clubData['logo_url']?.toString(),
      ),
      SetOptions(merge: true),
    );

    await batch.commit();
    await _auditLogService.record(
      institutionId: institutionId,
      actorUserId: actorUserId,
      actorRole: 'club_manager',
      action: 'president_assigned',
      targetType: 'club',
      targetId: clubId,
      metadata: {
        'old_president_id': oldPresidentId,
        'new_president_id': newPresidentId,
      },
    );
  }
}
