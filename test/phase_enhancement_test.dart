import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/models/club_membership_model.dart';
import 'package:klub_connect/models/club_model.dart';
import 'package:klub_connect/models/event_model.dart';
import 'package:klub_connect/models/membership_request_model.dart';
import 'package:klub_connect/models/user_model.dart';
import 'package:klub_connect/utils/institution_utils.dart';
import 'package:klub_connect/utils/search_index_utils.dart';

void main() {
  group('InstitutionUtils', () {
    test('creates stable ids from college names', () {
      expect(
        InstitutionUtils.idFromCollegeName('  Acme College of Engineering  '),
        'acme-college-of-engineering',
      );
      expect(
        InstitutionUtils.idFromCollegeName('ACME!!! College'),
        'acme-college',
      );
    });

    test('falls back for blank names', () {
      expect(InstitutionUtils.idFromCollegeName('  '), 'unknown-institution');
    });
  });

  group('SearchIndexUtils', () {
    test('normalizes and tokenizes searchable values', () {
      expect(
        SearchIndexUtils.keywords([
          'Robotics Society',
          'AI/ML Workshops',
          'Robotics Society',
        ]),
        containsAll([
          'robotics society',
          'robotics',
          'robo',
          'society',
          'ai',
          'ml',
        ]),
      );
    });
  });

  group('ClubMembershipModel', () {
    test('serializes membership and user mirror fields', () {
      final joinedAt = DateTime(2026, 1, 2, 3, 4);
      final membership = ClubMembershipModel(
        membershipId: 'user_1',
        clubId: 'club_1',
        userId: 'user_1',
        userName: 'Ada Lovelace',
        userProfileImageUrl: 'https://example.com/avatar.jpg',
        institutionId: 'acme-college',
        role: ClubMembershipRole.president,
        joinedAt: joinedAt,
        updatedAt: joinedAt,
      );

      final data = membership.toFirestore();
      expect(data['club_id'], 'club_1');
      expect(data['user_id'], 'user_1');
      expect(data['institution_id'], 'acme-college');
      expect(data['role'], 'president');
      expect(data['status'], 'active');

      final mirror = membership.toUserMirrorFirestore(
        clubName: 'Robotics Society',
        clubCategory: 'Technical',
        clubLogoUrl: 'https://example.com/logo.jpg',
      );
      expect(mirror['club_name'], 'Robotics Society');
      expect(mirror['club_category'], 'Technical');
      expect(mirror['club_logo_url'], 'https://example.com/logo.jpg');
    });
  });

  group('UserModel', () {
    test('serializes user data with institution_id and role metadata', () {
      final now = DateTime(2026, 1, 1);
      final user = UserModel(
        uid: 'usr_test_1',
        institutionId: 'acme-college',
        email: 'ada@acme.edu',
        phoneNumber: '+1234567890',
        firstName: 'Ada',
        lastName: 'Lovelace',
        fullName: 'Ada Lovelace',
        userType: 'student',
        gender: 'Female',
        dateOfBirth: DateTime(2002, 12, 10),
        collegeName: 'Acme College',
        createdAt: now,
        updatedAt: now,
        clubsJoined: ['club_1'],
        isPresidentOf: ['club_1'],
      );

      final firestoreData = user.toFirestore();
      expect(firestoreData['institution_id'], 'acme-college');
      expect(firestoreData['email'], 'ada@acme.edu');
      expect(firestoreData['user_type'], 'student');
      expect(firestoreData['clubs_joined'], contains('club_1'));
      expect(firestoreData['is_president_of'], contains('club_1'));
      expect(firestoreData['search_keywords'], isNotEmpty);
    });
  });

  group('ClubModel', () {
    test('serializes club data with institutionId and slug', () {
      final now = DateTime(2026, 1, 1);
      final club = ClubModel(
        clubId: 'club_robotics',
        institutionId: 'acme-college',
        name: 'Robotics Society',
        slug: 'robotics-society',
        description: 'Building robots and autonomous systems',
        logoUrl: 'https://example.com/logo.png',
        bannerUrl: 'https://example.com/banner.png',
        category: 'Technical',
        colorCode: '#0055FF',
        collegeName: 'Acme College',
        clubMasterId: 'fac_1',
        clubMasterName: 'Dr. Turing',
        presidentId: 'usr_1',
        presidentName: 'Ada Lovelace',
        organizers: ['usr_2'],
        members: ['usr_1', 'usr_2'],
        totalMembers: 2,
        createdAt: now,
        updatedAt: now,
      );

      final data = club.toFirestore();
      expect(data['institution_id'], 'acme-college');
      expect(data['name'], 'Robotics Society');
      expect(data['slug'], 'robotics-society');
      expect(data['president_id'], 'usr_1');
      expect(data['total_members'], 2);
      expect(data['search_keywords'], isNotEmpty);
    });
  });

  group('EventModel', () {
    test('serializes event data with institutionId and participant limits', () {
      final now = DateTime(2026, 1, 1);
      final event = EventModel(
        eventId: 'evt_hackathon',
        institutionId: 'acme-college',
        title: 'Annual Hackathon 2026',
        description: '24 hour campus coding sprint',
        clubId: 'club_robotics',
        clubName: 'Robotics Society',
        clubColor: '#0055FF',
        collegeName: 'Acme College',
        createdById: 'usr_1',
        createdByName: 'Ada Lovelace',
        createdByRole: 'president',
        eventDate: DateTime(2026, 3, 15),
        eventTime: '09:00 AM',
        location: 'Main Auditorium',
        venueType: 'offline',
        maxParticipants: 100,
        currentParticipants: 10,
        status: EventStatus.approved,
        createdAt: now,
        updatedAt: now,
      );

      final data = event.toFirestore();
      expect(data['institution_id'], 'acme-college');
      expect(data['title'], 'Annual Hackathon 2026');
      expect(data['max_participants'], 100);
      expect(data['current_participants'], 10);
      expect(data['status'], 'approved');
      expect(data['search_keywords'], isNotEmpty);
    });
  });

  group('MembershipRequestModel', () {
    test('serializes join request with institutionId and composite ID', () {
      final now = DateTime(2026, 1, 1);
      final request = MembershipRequestModel(
        requestId: 'club_robotics_usr_10',
        institutionId: 'acme-college',
        clubId: 'club_robotics',
        clubName: 'Robotics Society',
        userId: 'usr_10',
        userName: 'Charles Babbage',
        status: RequestStatus.pending,
        message: 'Excited to join the hardware team!',
        requestedAt: now,
      );

      final data = request.toFirestore();
      expect(data['institution_id'], 'acme-college');
      expect(data['club_id'], 'club_robotics');
      expect(data['user_id'], 'usr_10');
      expect(data['status'], 'pending');
      expect(data['message'], 'Excited to join the hardware team!');
    });
  });
}
