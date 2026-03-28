import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create Event
  Future<void> createEvent(EventModel event) async {
    try {
      await _firestore.collection('events').doc(event.eventId).set(event.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // Get Approved Events by College
  Stream<List<EventModel>> getApprovedEvents(String collegeName) {
    return _firestore
        .collection('events')
        .where('status', isEqualTo: EventStatus.approved.name)
        // Note: You'll need to filter by college. Since events are linked to clubs, 
        // and clubs have college_name, we might need to store college_name in event too 
        // or join. For now, assuming club_id is enough if we filter clubs first.
        // To make it efficient, let's add college_name to EventModel if not there.
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromFirestore(doc))
            .toList());
  }

  // Get Events for a Club
  Stream<List<EventModel>> getEventsByClub(String clubId) {
    return _firestore
        .collection('events')
        .where('club_id', isEqualTo: clubId)
        .orderBy('event_date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromFirestore(doc))
            .toList());
  }

  // Get Pending Events for Approval (for Club Masters)
  Stream<List<EventModel>> getPendingEvents(String clubId) {
    return _firestore
        .collection('events')
        .where('club_id', isEqualTo: clubId)
        .where('status', isEqualTo: EventStatus.pending.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromFirestore(doc))
            .toList());
  }

  // Approve/Reject Event
  Future<void> updateEventStatus(String eventId, EventStatus status) async {
    await _firestore.collection('events').doc(eventId).update({
      'status': status.name,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // RSVP to Event
  Future<void> updateRSVP({
    required String eventId,
    required String userId,
    required String userName,
    required String response,
    String? previousResponse,
  }) async {
    final batch = _firestore.batch();
    final eventRef = _firestore.collection('events').doc(eventId);
    final rsvpRef = eventRef.collection('rsvps').doc(userId);

    final rsvp = EventRSVP(
      userId: userId,
      userName: userName,
      response: response,
      respondedAt: DateTime.now(),
    );

    batch.set(rsvpRef, rsvp.toFirestore());

    // Update counts
    if (previousResponse != response) {
      if (previousResponse != null) {
        batch.update(eventRef, {
          '${previousResponse}_count': FieldValue.increment(-1),
        });
      }
      batch.update(eventRef, {
        '${response}_count': FieldValue.increment(1),
      });
      
      if (response == 'attending') {
         batch.update(eventRef, {
          'current_participants': FieldValue.increment(1),
        });
      }
      if (previousResponse == 'attending') {
         batch.update(eventRef, {
          'current_participants': FieldValue.increment(-1),
        });
      }
    }

    await batch.commit();
  }

  // Get User's RSVP for an Event
  Stream<EventRSVP?> getUserRSVP(String eventId, String userId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('rsvps')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? EventRSVP.fromFirestore(doc) : null);
  }
}
