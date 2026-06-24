import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/announcement_model.dart';
import 'audit_log_service.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLogService _auditLogService = AuditLogService();

  // Post Announcement
  Future<void> postAnnouncement(AnnouncementModel announcement) async {
    try {
      final id = const Uuid().v4();
      final data = announcement.toFirestore();
      await _firestore.collection('announcements').doc(id).set({
        ...data,
        'created_at': FieldValue.serverTimestamp(),
      });
      await _auditLogService.record(
        institutionId: announcement.institutionId,
        actorUserId: announcement.postedById,
        actorRole: announcement.postedByRole,
        action: 'announcement_posted',
        targetType: 'announcement',
        targetId: id,
        metadata: {
          'club_id': announcement.clubId,
          'title': announcement.title,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  // Get Club Announcements
  Stream<List<AnnouncementModel>> streamClubAnnouncements(String clubId) {
    return _firestore
        .collection('announcements')
        .where('club_id', isEqualTo: clubId)
        .orderBy('is_pinned', descending: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AnnouncementModel.fromFirestore(doc))
            .toList());
  }

  // Get All Announcements for User's Clubs
  Stream<List<AnnouncementModel>> streamUserClubsAnnouncements(
      List<String> clubIds) {
    if (clubIds.isEmpty) return Stream.value([]);

    final uniqueClubIds = clubIds.toSet().toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < uniqueClubIds.length; i += 10) {
      chunks.add(uniqueClubIds.skip(i).take(10).toList());
    }

    final controller = StreamController<List<AnnouncementModel>>();
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final chunkItems = <int, Map<String, AnnouncementModel>>{};

    void emit() {
      if (chunkItems.length != chunks.length || controller.isClosed) return;
      final merged = <String, AnnouncementModel>{};
      for (final items in chunkItems.values) {
        merged.addAll(items);
      }
      final values = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(values.take(20).toList());
    }

    controller.onListen = () {
      for (var index = 0; index < chunks.length; index++) {
        final subscription = _firestore
            .collection('announcements')
            .where('club_id', whereIn: chunks[index])
            .orderBy('created_at', descending: true)
            .limit(20)
            .snapshots()
            .listen(
          (snapshot) {
            chunkItems[index] = {
              for (final doc in snapshot.docs)
                doc.id: AnnouncementModel.fromFirestore(doc),
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

  // Pin/Unpin Announcement
  Future<void> togglePin(String announcementId, bool isPinned) async {
    await _firestore
        .collection('announcements')
        .doc(announcementId)
        .update({'is_pinned': isPinned});
  }

  // Delete Announcement
  Future<void> deleteAnnouncement(String announcementId) async {
    await _firestore.collection('announcements').doc(announcementId).delete();
  }

  // Increment View Count
  Future<void> incrementViewCount(String announcementId) async {
    await _firestore
        .collection('announcements')
        .doc(announcementId)
        .update({'views_count': FieldValue.increment(1)});
  }
}
