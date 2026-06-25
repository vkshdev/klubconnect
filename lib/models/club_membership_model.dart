import 'package:cloud_firestore/cloud_firestore.dart';

enum ClubMembershipRole { member, organizer, president }

enum ClubMembershipStatus { active, left, removed }

class ClubMembershipModel {
  final String membershipId;
  final String clubId;
  final String userId;
  final String userName;
  final String? userProfileImageUrl;
  final String institutionId;
  final ClubMembershipRole role;
  final ClubMembershipStatus status;
  final DateTime joinedAt;
  final DateTime updatedAt;

  const ClubMembershipModel({
    required this.membershipId,
    required this.clubId,
    required this.userId,
    this.userName = '',
    this.userProfileImageUrl,
    required this.institutionId,
    required this.role,
    this.status = ClubMembershipStatus.active,
    required this.joinedAt,
    required this.updatedAt,
  });

  factory ClubMembershipModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubMembershipModel(
      membershipId: doc.id,
      clubId: data['club_id'] ?? '',
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? '',
      userProfileImageUrl: data['user_profile_image_url'],
      institutionId: data['institution_id'] ?? '',
      role: ClubMembershipRole.values.firstWhere(
        (role) => role.name == (data['role'] ?? ClubMembershipRole.member.name),
        orElse: () => ClubMembershipRole.member,
      ),
      status: ClubMembershipStatus.values.firstWhere(
        (status) =>
            status.name == (data['status'] ?? ClubMembershipStatus.active.name),
        orElse: () => ClubMembershipStatus.active,
      ),
      joinedAt: _dateFrom(data['joined_at']),
      updatedAt: _dateFrom(data['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'club_id': clubId,
      'user_id': userId,
      'user_name': userName,
      'user_profile_image_url': userProfileImageUrl,
      'institution_id': institutionId,
      'role': role.name,
      'status': status.name,
      'joined_at': Timestamp.fromDate(joinedAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toUserMirrorFirestore({
    required String clubName,
    required String clubCategory,
    String? clubLogoUrl,
  }) {
    return {
      ...toFirestore(),
      'club_name': clubName,
      'club_category': clubCategory,
      'club_logo_url': clubLogoUrl,
    };
  }

  static DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
