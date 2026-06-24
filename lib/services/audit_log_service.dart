import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/audit_log_model.dart';

class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> record({
    required String institutionId,
    required String actorUserId,
    required String actorRole,
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic> metadata = const {},
  }) async {
    if (institutionId.isEmpty || actorUserId.isEmpty) return;

    final id = const Uuid().v4();
    final auditLog = AuditLogModel(
      auditLogId: id,
      institutionId: institutionId,
      actorUserId: actorUserId,
      actorRole: actorRole,
      action: action,
      targetType: targetType,
      targetId: targetId,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('audit_logs')
        .doc(id)
        .set(auditLog.toFirestore());
  }

  Stream<List<AuditLogModel>> streamInstitutionLogs(String institutionId) {
    return _firestore
        .collection('audit_logs')
        .where('institution_id', isEqualTo: institutionId)
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(AuditLogModel.fromFirestore).toList());
  }
}
