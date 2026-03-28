import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/announcement_model.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Post Announcement
  Future<void> postAnnouncement(AnnouncementModel announcement) async {
    try {
      final id = const Uuid().v4();
      final data = announcement.toFirestore();
      await _firestore.collection('announcements').doc(id).set({
        ...data,
        'created_at': FieldValue.serverTimestamp(),
      });
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
  Stream<List<AnnouncementModel>> streamUserClubsAnnouncements(List<String> clubIds) {
    if (clubIds.isEmpty) return Stream.value([]);
    
    return _firestore
        .collection('announcements')
        .where('club_id', whereIn: clubIds)
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AnnouncementModel.fromFirestore(doc))
            .toList());
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
