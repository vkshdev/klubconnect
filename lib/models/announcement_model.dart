import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementModel {
  final String announcementId;
  final String institutionId;
  final String clubId;
  final String clubName;
  final String title;
  final String content;
  final String postedById;
  final String postedByName;
  final String postedByRole;
  final List<String> mediaUrls;
  final bool isPinned;
  final DateTime createdAt;
  final int viewsCount;

  AnnouncementModel({
    required this.announcementId,
    this.institutionId = '',
    required this.clubId,
    required this.clubName,
    required this.title,
    required this.content,
    required this.postedById,
    required this.postedByName,
    required this.postedByRole,
    this.mediaUrls = const [],
    this.isPinned = false,
    required this.createdAt,
    this.viewsCount = 0,
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnnouncementModel(
      announcementId: doc.id,
      institutionId: data['institution_id'] ?? '',
      clubId: data['club_id'] ?? '',
      clubName: data['club_name'] ?? '',
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      postedById: data['posted_by_id'] ?? '',
      postedByName: data['posted_by_name'] ?? '',
      postedByRole: data['posted_by_role'] ?? '',
      mediaUrls: List<String>.from(data['media_urls'] ?? []),
      isPinned: data['is_pinned'] ?? false,
      createdAt: _dateFrom(data['created_at']),
      viewsCount: data['views_count'] ?? 0,
    );
  }

  static DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'club_id': clubId,
      if (institutionId.isNotEmpty) 'institution_id': institutionId,
      'club_name': clubName,
      'title': title,
      'content': content,
      'posted_by_id': postedById,
      'posted_by_name': postedByName,
      'posted_by_role': postedByRole,
      'media_urls': mediaUrls,
      'is_pinned': isPinned,
      'created_at': Timestamp.fromDate(createdAt),
      'views_count': viewsCount,
    };
  }
}
