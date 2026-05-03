import 'package:cloud_firestore/cloud_firestore.dart';

enum EventStatus { draft, pending, approved, rejected }

class EventModel {
  final String eventId;
  final String title;
  final String description;
  final String clubId;
  final String clubName;
  final String clubColor;
  final String collegeName;
  final String createdById;
  final String createdByName;
  final String createdByRole;
  final DateTime eventDate;
  final String eventTime;
  final String location;
  final String venueType; // 'online' or 'offline'
  final String? bannerUrl;
  final int maxParticipants;
  final int currentParticipants;
  final int interestedCount;
  final int notGoingCount;
  final EventStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  EventModel({
    required this.eventId,
    required this.title,
    required this.description,
    required this.clubId,
    required this.clubName,
    required this.clubColor,
    required this.collegeName,
    required this.createdById,
    required this.createdByName,
    required this.createdByRole,
    required this.eventDate,
    required this.eventTime,
    required this.location,
    required this.venueType,
    this.bannerUrl,
    required this.maxParticipants,
    this.currentParticipants = 0,
    this.interestedCount = 0,
    this.notGoingCount = 0,
    this.status = EventStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      eventId: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      clubId: data['club_id'] ?? '',
      clubName: data['club_name'] ?? '',
      clubColor: data['club_color'] ?? '#000000',
      collegeName: data['college_name'] ?? '',
      createdById: data['created_by_id'] ?? '',
      createdByName: data['created_by_name'] ?? '',
      createdByRole: data['created_by_role'] ?? '',
      eventDate: _dateFrom(data['event_date']),
      eventTime: data['event_time'] ?? '',
      location: data['location'] ?? '',
      venueType: data['venue_type'] ?? 'offline',
      bannerUrl: data['banner_url'],
      maxParticipants: data['max_participants'] ?? 0,
      currentParticipants: data['current_participants'] ?? 0,
      interestedCount: data['interested_count'] ?? 0,
      notGoingCount: data['not_going_count'] ?? 0,
      status: EventStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => EventStatus.pending,
      ),
      createdAt: _dateFrom(data['created_at']),
      updatedAt: _dateFrom(data['updated_at']),
    );
  }

  static DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'club_id': clubId,
      'club_name': clubName,
      'club_color': clubColor,
      'college_name': collegeName,
      'created_by_id': createdById,
      'created_by_name': createdByName,
      'created_by_role': createdByRole,
      'event_date': Timestamp.fromDate(eventDate),
      'event_time': eventTime,
      'location': location,
      'venue_type': venueType,
      'banner_url': bannerUrl,
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
      'interested_count': interestedCount,
      'not_going_count': notGoingCount,
      'status': status.name,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }
}

class EventRSVP {
  final String userId;
  final String userName;
  final String response; // 'attending', 'interested', 'not_going'
  final DateTime respondedAt;

  EventRSVP({
    required this.userId,
    required this.userName,
    required this.response,
    required this.respondedAt,
  });

  factory EventRSVP.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventRSVP(
      userId: doc.id,
      userName: data['user_name'] ?? '',
      response: data['response'] ?? 'interested',
      respondedAt: _dateFrom(data['responded_at']),
    );
  }

  static DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_name': userName,
      'response': response,
      'responded_at': Timestamp.fromDate(respondedAt),
    };
  }
}
