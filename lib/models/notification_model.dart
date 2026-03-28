import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String userId;
  final String type; // 'membership_request', 'event_approved', etc.
  final String title;
  final String message;
  final String? fromUserId;
  final String? relatedClubId;
  final String? relatedEventId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.fromUserId,
    this.relatedClubId,
    this.relatedEventId,
    this.isRead = false,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId: doc.id,
      userId: data['user_id'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      fromUserId: data['from_user_id'],
      relatedClubId: data['related_club_id'],
      relatedEventId: data['related_event_id'],
      isRead: data['is_read'] ?? false,
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'type': type,
      'title': title,
      'message': message,
      'from_user_id': fromUserId,
      'related_club_id': relatedClubId,
      'related_event_id': relatedEventId,
      'is_read': isRead,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
