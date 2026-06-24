import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/event_model.dart';
import '../utils/search_index_utils.dart';
import 'audit_log_service.dart';
import 'image_upload_service.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuditLogService _auditLogService = AuditLogService();
  final ImageUploadService _imageUploadService = ImageUploadService();

  Future<void> createEvent(EventModel event) async {
    await _firestore
        .collection('events')
        .doc(event.eventId)
        .set(event.toFirestore());
  }

  Stream<EventModel?> streamEvent(String eventId) {
    return _firestore.collection('events').doc(eventId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return EventModel.fromFirestore(doc);
    });
  }

  Stream<List<EventModel>> getApprovedEvents(
    String collegeName, {
    String? institutionId,
  }) {
    final legacyQuery = _firestore
        .collection('events')
        .where('college_name', isEqualTo: collegeName)
        .where('status', isEqualTo: EventStatus.approved.name)
        .orderBy('event_date');

    if (institutionId == null || institutionId.isEmpty) {
      return legacyQuery.snapshots().map(
          (snapshot) => snapshot.docs.map(EventModel.fromFirestore).toList());
    }

    final institutionQuery = _firestore
        .collection('events')
        .where('institution_id', isEqualTo: institutionId)
        .where('status', isEqualTo: EventStatus.approved.name)
        .orderBy('event_date');

    return _mergeDocumentStreams(
      primary: institutionQuery.snapshots(),
      legacy: legacyQuery.snapshots(),
      mapper: EventModel.fromFirestore,
      compare: (a, b) => a.eventDate.compareTo(b.eventDate),
    );
  }

  Stream<List<EventModel>> getEventsByClub(String clubId) {
    return _firestore
        .collection('events')
        .where('club_id', isEqualTo: clubId)
        .orderBy('event_date')
        .snapshots()
        .map(
            (snapshot) => snapshot.docs.map(EventModel.fromFirestore).toList());
  }

  Stream<List<EventModel>> getPendingEvents(String clubId) {
    return _firestore
        .collection('events')
        .where('club_id', isEqualTo: clubId)
        .where('status', isEqualTo: EventStatus.pending.name)
        .orderBy('event_date')
        .snapshots()
        .map(
            (snapshot) => snapshot.docs.map(EventModel.fromFirestore).toList());
  }

  Stream<List<EventModel>> getPendingEventsForClubs(List<String> clubIds) {
    if (clubIds.isEmpty) return Stream.value([]);
    return _streamEventsForClubChunks(
      clubIds: clubIds,
      status: EventStatus.pending,
    );
  }

  Stream<List<EventModel>> searchEvents({
    required String collegeName,
    String? institutionId,
    String query = '',
    String? clubId,
    EventStatus? status,
  }) {
    Query<Map<String, dynamic>> legacyRef = _firestore
        .collection('events')
        .where('college_name', isEqualTo: collegeName);

    Query<Map<String, dynamic>>? institutionRef;
    if (institutionId != null && institutionId.isNotEmpty) {
      institutionRef = _firestore
          .collection('events')
          .where('institution_id', isEqualTo: institutionId);
    }

    if (clubId != null && clubId.isNotEmpty) {
      legacyRef = legacyRef.where('club_id', isEqualTo: clubId);
      institutionRef = institutionRef?.where('club_id', isEqualTo: clubId);
    }
    if (status != null) {
      legacyRef = legacyRef.where('status', isEqualTo: status.name);
      institutionRef = institutionRef?.where('status', isEqualTo: status.name);
    }

    final normalizedQuery = SearchIndexUtils.normalize(query);
    if (normalizedQuery.isNotEmpty) {
      legacyRef =
          legacyRef.where('search_keywords', arrayContains: normalizedQuery);
      institutionRef = institutionRef?.where(
        'search_keywords',
        arrayContains: normalizedQuery,
      );
    }
    legacyRef = legacyRef.limit(30);
    institutionRef = institutionRef?.limit(30);

    final source = institutionRef == null
        ? legacyRef.snapshots().map(
            (snapshot) => snapshot.docs.map(EventModel.fromFirestore).toList())
        : _mergeDocumentStreams(
            primary: institutionRef.snapshots(),
            legacy: legacyRef.snapshots(),
            mapper: EventModel.fromFirestore,
            compare: (a, b) => a.eventDate.compareTo(b.eventDate),
          );

    return source;
  }

  Future<void> updateEventStatus(
    String eventId,
    EventStatus status, {
    String? actorUserId,
    String? institutionId,
  }) async {
    await _firestore.collection('events').doc(eventId).update({
      'status': status.name,
      'updated_at': FieldValue.serverTimestamp(),
    });
    if (actorUserId != null && institutionId != null) {
      await _auditLogService.record(
        institutionId: institutionId,
        actorUserId: actorUserId,
        actorRole: 'club_master',
        action: status == EventStatus.approved
            ? 'event_approved'
            : 'event_rejected',
        targetType: 'event',
        targetId: eventId,
      );
    }
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    await _firestore.collection('events').doc(eventId).update({
      ...updates,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRSVP({
    required EventModel event,
    required String userId,
    required String userName,
    required String response,
    String? previousResponse,
  }) async {
    final eventRef = _firestore.collection('events').doc(event.eventId);
    final rsvpRef = eventRef.collection('rsvps').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final eventSnapshot = await transaction.get(eventRef);
      if (!eventSnapshot.exists) {
        throw Exception('Event not found.');
      }
      if (!['attending', 'interested', 'not_going'].contains(response)) {
        throw Exception('Invalid RSVP response.');
      }

      final eventData = eventSnapshot.data() ?? {};
      final currentResponseSnapshot = await transaction.get(rsvpRef);
      final currentResponseData = currentResponseSnapshot.data();
      String? currentResponse;
      if (currentResponseSnapshot.exists && currentResponseData != null) {
        currentResponse = currentResponseData['response'] as String?;
      }

      if (currentResponse == response) {
        transaction.set(
          rsvpRef,
          EventRSVP(
            userId: userId,
            userName: userName,
            response: response,
            respondedAt: DateTime.now(),
          ).toFirestore(),
          SetOptions(merge: true),
        );
        return;
      }

      final maxParticipants =
          ((eventData['max_participants'] ?? 0) as num).toInt();
      final counts = <String, int>{
        'attending': ((eventData['current_participants'] ?? 0) as num).toInt(),
        'interested': ((eventData['interested_count'] ?? 0) as num).toInt(),
        'not_going': ((eventData['not_going_count'] ?? 0) as num).toInt(),
      };

      if (currentResponse != null && counts.containsKey(currentResponse)) {
        counts[currentResponse] =
            ((counts[currentResponse]! - 1).clamp(0, 1 << 31)).toInt();
      }
      counts[response] = (counts[response] ?? 0) + 1;

      if (response == 'attending' && counts['attending']! > maxParticipants) {
        throw Exception('This event is already full.');
      }

      transaction.set(
        rsvpRef,
        EventRSVP(
          userId: userId,
          userName: userName,
          response: response,
          respondedAt: DateTime.now(),
        ).toFirestore(),
      );
      transaction.update(eventRef, {
        'current_participants': counts['attending'],
        'interested_count': counts['interested'],
        'not_going_count': counts['not_going'],
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<EventRSVP?> getUserRSVP(String eventId, String userId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('rsvps')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? EventRSVP.fromFirestore(doc) : null);
  }

  Stream<List<EventRSVP>> getEventRsvps(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('rsvps')
        .orderBy('responded_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(EventRSVP.fromFirestore).toList());
  }

  Future<String> uploadEventBanner({
    required String eventId,
    required File image,
    required String ownerId,
    required String institutionId,
  }) async {
    return _imageUploadService.uploadCompressedImage(
      image: image,
      storagePath: 'events/$eventId/banner.jpg',
      ownerId: ownerId,
      institutionId: institutionId,
      ownerType: 'event',
    );
  }

  Stream<List<T>> _mergeDocumentStreams<T>({
    required Stream<QuerySnapshot<Map<String, dynamic>>> primary,
    required Stream<QuerySnapshot<Map<String, dynamic>>> legacy,
    required T Function(DocumentSnapshot<Map<String, dynamic>>) mapper,
    int Function(T a, T b)? compare,
  }) {
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
        primarySubscription;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
        legacySubscription;
    final controller = StreamController<List<T>>();
    Map<String, T> primaryItems = {};
    Map<String, T> legacyItems = {};
    var hasPrimary = false;
    var hasLegacy = false;

    void emit() {
      if (!hasPrimary || !hasLegacy || controller.isClosed) return;
      final merged = <String, T>{...legacyItems, ...primaryItems};
      final values = merged.values.toList();
      if (compare != null) {
        values.sort(compare);
      }
      controller.add(values);
    }

    controller.onListen = () {
      primarySubscription = primary.listen(
        (snapshot) {
          primaryItems = {
            for (final doc in snapshot.docs) doc.id: mapper(doc),
          };
          hasPrimary = true;
          emit();
        },
        onError: controller.addError,
      );
      legacySubscription = legacy.listen(
        (snapshot) {
          legacyItems = {
            for (final doc in snapshot.docs) doc.id: mapper(doc),
          };
          hasLegacy = true;
          emit();
        },
        onError: controller.addError,
      );
    };
    controller.onCancel = () async {
      await primarySubscription.cancel();
      await legacySubscription.cancel();
    };

    return controller.stream;
  }

  Stream<List<EventModel>> _streamEventsForClubChunks({
    required List<String> clubIds,
    EventStatus? status,
  }) {
    final uniqueClubIds = clubIds.toSet().toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < uniqueClubIds.length; i += 10) {
      chunks.add(uniqueClubIds.skip(i).take(10).toList());
    }

    final controller = StreamController<List<EventModel>>();
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    final chunkItems = <int, Map<String, EventModel>>{};

    void emit() {
      if (chunkItems.length != chunks.length || controller.isClosed) return;
      final merged = <String, EventModel>{};
      for (final items in chunkItems.values) {
        merged.addAll(items);
      }
      final values = merged.values.toList()
        ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
      controller.add(values);
    }

    controller.onListen = () {
      for (var index = 0; index < chunks.length; index++) {
        var query = _firestore
            .collection('events')
            .where('club_id', whereIn: chunks[index]);
        if (status != null) {
          query = query.where('status', isEqualTo: status.name);
        }
        final subscription = query.snapshots().listen(
          (snapshot) {
            chunkItems[index] = {
              for (final doc in snapshot.docs)
                doc.id: EventModel.fromFirestore(doc),
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
}
