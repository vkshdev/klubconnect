import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/event_model.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> createEvent(EventModel event) async {
    await _firestore.collection('events').doc(event.eventId).set(event.toFirestore());
  }

  Stream<EventModel?> streamEvent(String eventId) {
    return _firestore.collection('events').doc(eventId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return EventModel.fromFirestore(doc);
    });
  }

  Stream<List<EventModel>> getApprovedEvents(String collegeName) {
    return _firestore
        .collection('events')
        .where('college_name', isEqualTo: collegeName)
        .where('status', isEqualTo: EventStatus.approved.name)
        .orderBy('event_date')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(EventModel.fromFirestore).toList());
  }

  Stream<List<EventModel>> getEventsByClub(String clubId) {
    return _firestore
        .collection('events')
        .where('club_id', isEqualTo: clubId)
        .orderBy('event_date')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(EventModel.fromFirestore).toList());
  }

  Stream<List<EventModel>> getPendingEvents(String clubId) {
    return _firestore
        .collection('events')
        .where('club_id', isEqualTo: clubId)
        .where('status', isEqualTo: EventStatus.pending.name)
        .orderBy('event_date')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(EventModel.fromFirestore).toList());
  }

  Stream<List<EventModel>> getPendingEventsForClubs(List<String> clubIds) {
    if (clubIds.isEmpty) return Stream.value([]);
    return _firestore
        .collection('events')
        .where('club_id', whereIn: clubIds.take(10).toList())
        .where('status', isEqualTo: EventStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(EventModel.fromFirestore).toList());
  }

  Stream<List<EventModel>> searchEvents({
    required String collegeName,
    String query = '',
    String? clubId,
    EventStatus? status,
  }) {
    Query<Map<String, dynamic>> ref = _firestore
        .collection('events')
        .where('college_name', isEqualTo: collegeName);

    if (clubId != null && clubId.isNotEmpty) {
      ref = ref.where('club_id', isEqualTo: clubId);
    }
    if (status != null) {
      ref = ref.where('status', isEqualTo: status.name);
    }

    final normalizedQuery = query.trim().toLowerCase();
    return ref.snapshots().map((snapshot) {
      final events = snapshot.docs.map(EventModel.fromFirestore).toList();
      if (normalizedQuery.isEmpty) return events;
      return events
          .where((event) =>
              event.title.toLowerCase().contains(normalizedQuery) ||
              event.clubName.toLowerCase().contains(normalizedQuery) ||
              event.description.toLowerCase().contains(normalizedQuery))
          .toList();
    });
  }

  Future<void> updateEventStatus(String eventId, EventStatus status) async {
    await _firestore.collection('events').doc(eventId).update({
      'status': status.name,
      'updated_at': FieldValue.serverTimestamp(),
    });
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
    if (response == 'attending' &&
        previousResponse != 'attending' &&
        event.currentParticipants >= event.maxParticipants) {
      throw Exception('This event is already full.');
    }

    final batch = _firestore.batch();
    final eventRef = _firestore.collection('events').doc(event.eventId);
    final rsvpRef = eventRef.collection('rsvps').doc(userId);

    final rsvp = EventRSVP(
      userId: userId,
      userName: userName,
      response: response,
      respondedAt: DateTime.now(),
    );

    batch.set(rsvpRef, rsvp.toFirestore());

    if (previousResponse != response) {
      final countUpdates = <String, Object>{
        'updated_at': FieldValue.serverTimestamp(),
      };
      _mergeCountDelta(countUpdates, previousResponse, -1);
      _mergeCountDelta(countUpdates, response, 1);
      batch.update(eventRef, countUpdates);
    }

    await batch.commit();
  }

  void _mergeCountDelta(
    Map<String, Object> updates,
    String? response,
    int delta,
  ) {
    if (response == null) return;
    if (response == 'attending') {
      updates['current_participants'] = FieldValue.increment(delta);
    } else if (response == 'interested') {
      updates['interested_count'] = FieldValue.increment(delta);
    } else if (response == 'not_going') {
      updates['not_going_count'] = FieldValue.increment(delta);
    }
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
  }) async {
    final ref = _storage.ref().child('events').child(eventId).child('banner.jpg');
    await ref.putFile(image);
    return ref.getDownloadURL();
  }
}
