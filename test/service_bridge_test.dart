import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/models/club_membership_model.dart';
import 'package:klub_connect/models/membership_request_model.dart';
import 'package:klub_connect/services/membership_service.dart';
import 'package:klub_connect/utils/institution_utils.dart';

void main() {
  group('Service Bridge & Dual-Write Model Contract Tests', () {
    test('MembershipService generates deterministic request IDs', () {
      final id = MembershipService.requestIdFor('club_robotics', 'usr_student_42');
      expect(id, equals('club_robotics_usr_student_42'));
    });

    test('ClubMembershipModel toUserMirrorFirestore contains essential display fields', () {
      final now = DateTime(2026, 8, 30);
      final membership = ClubMembershipModel(
        membershipId: 'usr_student_42',
        clubId: 'club_robotics',
        userId: 'usr_student_42',
        userName: 'Alex Chen',
        institutionId: 'inst_mit',
        role: ClubMembershipRole.organizer,
        joinedAt: now,
        updatedAt: now,
      );

      final mirror = membership.toUserMirrorFirestore(
        clubName: 'MIT Robotics Team',
        clubCategory: 'Technical',
        clubLogoUrl: 'https://cdn.klubconnect.app/logo.png',
      );

      expect(mirror['club_id'], equals('club_robotics'));
      expect(mirror['role'], equals('organizer'));
      expect(mirror['club_name'], equals('MIT Robotics Team'));
      expect(mirror['club_category'], equals('Technical'));
      expect(mirror['club_logo_url'], equals('https://cdn.klubconnect.app/logo.png'));
    });

    test('InstitutionUtils creates consistent IDs and slugs across variants', () {
      expect(
        InstitutionUtils.idFromCollegeName('Stanford University'),
        equals('stanford-university'),
      );
      expect(
        InstitutionUtils.slugFromCollegeName('UC Berkeley'),
        equals('uc-berkeley'),
      );
    });

    test('MembershipRequestModel correctly parses status enums', () {
      final reqPending = MembershipRequestModel(
        requestId: 'req_1',
        institutionId: 'inst_1',
        clubId: 'club_1',
        clubName: 'Club One',
        userId: 'user_1',
        userName: 'User One',
        status: RequestStatus.pending,
        requestedAt: DateTime.now(),
      );

      final reqApproved = MembershipRequestModel(
        requestId: 'req_2',
        institutionId: 'inst_1',
        clubId: 'club_1',
        clubName: 'Club One',
        userId: 'user_2',
        userName: 'User Two',
        status: RequestStatus.approved,
        requestedAt: DateTime.now(),
      );

      expect(reqPending.toFirestore()['status'], equals('pending'));
      expect(reqApproved.toFirestore()['status'], equals('approved'));
    });
  });
}
