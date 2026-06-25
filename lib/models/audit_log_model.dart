import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String auditLogId;
  final String institutionId;
  final String actorUserId;
  final String actorRole;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AuditLogModel({
    required this.auditLogId,
    required this.institutionId,
    required this.actorUserId,
    required this.actorRole,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.metadata = const {},
    required this.createdAt,
  });

  factory AuditLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLogModel(
      auditLogId: doc.id,
      institutionId: data['institution_id'] ?? '',
      actorUserId: data['actor_user_id'] ?? '',
      actorRole: data['actor_role'] ?? '',
      action: data['action'] ?? '',
      targetType: data['target_type'] ?? '',
      targetId: data['target_id'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: _dateFrom(data['created_at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'institution_id': institutionId,
      'actor_user_id': actorUserId,
      'actor_role': actorRole,
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'metadata': metadata,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
