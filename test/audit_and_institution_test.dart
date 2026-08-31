import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/services/institution_service.dart';
import 'package:klub_connect/models/audit_log_model.dart';

void main() {
  group('InstitutionService General Email Domain Verification Tests', () {
    test('permits email matching exact domain', () {
      expect(
        InstitutionService.isEmailAllowed(
          email: 'student@stanford.edu',
          allowedDomains: ['stanford.edu', 'berkeley.edu'],
        ),
        isTrue,
      );
    });

    test('permits email matching subdomain', () {
      expect(
        InstitutionService.isEmailAllowed(
          email: 'alex@cs.stanford.edu',
          allowedDomains: ['stanford.edu'],
        ),
        isTrue,
      );
    });

    test('rejects email with unlisted domain', () {
      expect(
        InstitutionService.isEmailAllowed(
          email: 'imposter@gmail.com',
          allowedDomains: ['stanford.edu', 'mit.edu'],
        ),
        isFalse,
      );
    });

    test('handles whitespace, case insensitivity, and leading @ gracefully', () {
      expect(
        InstitutionService.isEmailAllowed(
          email: '  STUDENT@MIT.EDU  ',
          allowedDomains: ['@mit.edu '],
        ),
        isTrue,
      );
    });

    test('permits any domain if allowedDomains list is empty', () {
      expect(
        InstitutionService.isEmailAllowed(
          email: 'user@anycollege.edu',
          allowedDomains: [],
        ),
        isTrue,
      );
    });
  });

  group('InstitutionService Faculty Domain Verification Tests', () {
    test('permits faculty email matching exact faculty domain', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'prof.smith@mit.edu',
          facultyDomains: ['mit.edu', 'faculty.mit.edu'],
        ),
        isTrue,
      );
    });

    test('permits faculty email matching faculty subdomain', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'dean@cs.mit.edu',
          facultyDomains: ['mit.edu'],
        ),
        isTrue,
      );
    });

    test('rejects faculty email with personal unlisted domain', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'faculty.member@gmail.com',
          facultyDomains: ['mit.edu', 'harvard.edu'],
        ),
        isFalse,
      );
    });

    test('rejects faculty email when facultyDomains is empty', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'prof@mit.edu',
          facultyDomains: [],
        ),
        isFalse,
      );
    });

    test('handles uppercase and spaces in faculty domain check', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: '  PROF@STANFORD.EDU  ',
          facultyDomains: [' @stanford.edu '],
        ),
        isTrue,
      );
    });
  });

  group('InstitutionService Faculty Invite Code Validation Tests', () {
    test('validates correct invite code with exact match', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: 'MIT-FAC-2026',
          validCodes: ['MIT-FAC-2026', 'DEAN-VIP-77'],
        ),
        isTrue,
      );
    });

    test('validates invite code case-insensitively and trims whitespace', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: '  mit-fac-2026  ',
          validCodes: ['MIT-FAC-2026'],
        ),
        isTrue,
      );
    });

    test('rejects invalid or unauthorized invite code', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: 'INVALID-CODE',
          validCodes: ['MIT-FAC-2026', 'DEAN-VIP-77'],
        ),
        isFalse,
      );
    });

    test('rejects empty or whitespace-only invite code', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: '   ',
          validCodes: ['MIT-FAC-2026'],
        ),
        isFalse,
      );
    });
  });

  group('InstitutionService Dual-Mode verifyFaculty Orchestrator Tests', () {
    final institution = InstitutionModel(
      institutionId: 'inst_mit',
      name: 'Massachusetts Institute of Technology',
      slug: 'mit',
      allowedEmailDomains: ['mit.edu'],
      facultyEmailDomains: ['mit.edu', 'faculty.mit.edu'],
      facultyInviteCodes: ['MIT-FAC-2026', 'DEAN-VIP-77'],
      status: 'active',
      adminUserIds: ['admin_1'],
      createdAt: DateTime(2026, 1, 1),
    );

    test('Mode 1: auto-activates faculty via domain match without invite code', () {
      final result = InstitutionService.verifyFaculty(
        email: 'prof.brown@mit.edu',
        institution: institution,
      );
      expect(result.accountStatus, equals('active'));
      expect(result.isVerified, isTrue);
      expect(result.verifiedVia, equals('domain'));
    });

    test('Mode 2: auto-activates faculty with authorized invite code despite unlisted domain', () {
      final result = InstitutionService.verifyFaculty(
        email: 'brown.adjunct@gmail.com',
        inviteCode: 'mit-fac-2026',
        institution: institution,
      );
      expect(result.accountStatus, equals('active'));
      expect(result.isVerified, isTrue);
      expect(result.verifiedVia, equals('invite_code'));
    });

    test('Fallback: defaults to pending_verification when domain and invite code both fail', () {
      final result = InstitutionService.verifyFaculty(
        email: 'imposter@gmail.com',
        inviteCode: 'WRONG-CODE',
        institution: institution,
      );
      expect(result.accountStatus, equals('pending_verification'));
      expect(result.isVerified, isFalse);
      expect(result.verifiedVia, isNull);
    });

    test('Missing institution: defaults to pending_verification', () {
      final result = InstitutionService.verifyFaculty(
        email: 'prof@mit.edu',
        institution: null,
      );
      expect(result.accountStatus, equals('pending_verification'));
      expect(result.isVerified, isFalse);
    });
  });

  group('AuditLogModel & InstitutionModel Serialization Tests', () {
    test('AuditLogModel serializes correctly', () {
      final now = DateTime(2026, 8, 30, 10, 0, 0);
      final log = AuditLogModel(
        auditLogId: 'log_123',
        institutionId: 'inst_mit',
        actorUserId: 'usr_faculty_1',
        actorRole: 'club_master',
        action: 'event_approved',
        targetType: 'event',
        targetId: 'evt_hackathon_99',
        metadata: {'club_id': 'club_ai'},
        createdAt: now,
      );

      final map = log.toFirestore();
      expect(map['institution_id'], equals('inst_mit'));
      expect(map['actor_user_id'], equals('usr_faculty_1'));
      expect(map['action'], equals('event_approved'));
      expect(map['target_id'], equals('evt_hackathon_99'));
      expect(map['metadata'], equals({'club_id': 'club_ai'}));
    });

    test('InstitutionModel serializes correctly with faculty fields', () {
      final now = DateTime(2026, 8, 30, 10, 0, 0);
      final inst = InstitutionModel(
        institutionId: 'inst_mit',
        name: 'Massachusetts Institute of Technology',
        slug: 'mit',
        allowedEmailDomains: ['mit.edu', 'csail.mit.edu'],
        facultyEmailDomains: ['mit.edu', 'faculty.mit.edu'],
        facultyInviteCodes: ['MIT-FAC-2026'],
        status: 'active',
        adminUserIds: ['admin_usr_1'],
        createdAt: now,
      );

      final map = inst.toFirestore();
      expect(map['name'], equals('Massachusetts Institute of Technology'));
      expect(map['slug'], equals('mit'));
      expect(map['allowed_email_domains'], equals(['mit.edu', 'csail.mit.edu']));
      expect(map['faculty_email_domains'], equals(['mit.edu', 'faculty.mit.edu']));
      expect(map['faculty_invite_codes'], equals(['MIT-FAC-2026']));
      expect(map['status'], equals('active'));
    });
  });
}
