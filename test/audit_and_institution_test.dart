import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/services/institution_service.dart';
import 'package:klub_connect/models/audit_log_model.dart';

void main() {
  group('InstitutionService Domain Verification Tests', () {
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

    test('InstitutionModel serializes correctly', () {
      final now = DateTime(2026, 8, 30, 10, 0, 0);
      final inst = InstitutionModel(
        institutionId: 'inst_mit',
        name: 'Massachusetts Institute of Technology',
        slug: 'mit',
        allowedEmailDomains: ['mit.edu', 'csail.mit.edu'],
        status: 'active',
        adminUserIds: ['admin_usr_1'],
        createdAt: now,
      );

      final map = inst.toFirestore();
      expect(map['name'], equals('Massachusetts Institute of Technology'));
      expect(map['slug'], equals('mit'));
      expect(map['allowed_email_domains'], equals(['mit.edu', 'csail.mit.edu']));
      expect(map['status'], equals('active'));
    });
  });
}
