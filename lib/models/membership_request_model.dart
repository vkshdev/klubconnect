import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, approved, rejected }

class MembershipRequestModel {
  final String requestId; // composite: club_id_user_id
  final String clubId;
  final String clubName;
  final String userId;
  final String userName;
  final RequestStatus status;
  final String? message;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? respondedById;

  MembershipRequestModel({
    required this.requestId,
    required this.clubId,
    required this.clubName,
    required this.userId,
    required this.userName,
    this.status = RequestStatus.pending,
    this.message,
    required this.requestedAt,
    this.respondedAt,
    this.respondedById,
  });

  factory MembershipRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MembershipRequestModel(
      requestId: doc.id,
      clubId: data['club_id'] ?? '',
      clubName: data['club_name'] ?? '',
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? '',
      status: RequestStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => RequestStatus.pending,
      ),
      message: data['message'],
      requestedAt: (data['requested_at'] as Timestamp).toDate(),
      respondedAt: data['responded_at'] != null
          ? (data['responded_at'] as Timestamp).toDate()
          : null,
      respondedById: data['responded_by_id'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'club_id': clubId,
      'club_name': clubName,
      'user_id': userId,
      'user_name': userName,
      'status': status.name,
      'message': message,
      'requested_at': Timestamp.fromDate(requestedAt),
      'responded_at': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'responded_by_id': respondedById,
    };
  }
}
