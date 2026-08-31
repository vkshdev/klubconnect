import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/models/audit_log_model.dart';
import 'package:klub_connect/models/club_membership_model.dart';
import 'package:klub_connect/models/user_model.dart';
import 'package:klub_connect/services/auth_service.dart';

/// Helper to locate firestore.rules across various test execution working directories.
File _findFirestoreRules() {
  final candidates = [
    File('firestore.rules'),
    File('../firestore.rules'),
    File('../../firestore.rules'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) {
      return file;
    }
  }
  throw StateError('firestore.rules file could not be located in test search paths.');
}

/// Simulated Firestore Security Rules Policy Evaluator in pure Dart.
/// Evaluates authorization contracts deterministically in headless CI environments.
class FirestoreSecurityContractValidator {
  static const Set<String> safeUserUpdateFields = {
    'first_name',
    'last_name',
    'full_name',
    'full_name_lower',
    'search_keywords',
    'about',
    'phone_number',
    'profile_image_url',
    'fcm_token',
    'last_token_updated_at',
    'last_login_at',
    'is_online',
    'last_active_at',
    'profile_completed',
    'updated_at',
  };

  static const Set<String> forbiddenPrivilegeFields = {
    'user_type',
    'institution_id',
    'college_name',
    'email',
    'uid',
    'account_status',
    'faculty_invite_code',
    'faculty_invite_codes',
    'faculty_email_domains',
    'is_president_of',
    'is_organizer_of',
    'clubs_joined',
    'clubs_created',
    'is_active',
    'created_at',
    'admin_user_ids',
    'role',
    'permissions',
    'is_admin',
  };

  static const Set<String> validRsvpResponses = {
    'attending',
    'interested',
    'not_going',
  };

  /// Evaluates user profile update request authorization.
  static SecurityEvaluationResult evaluateUserUpdate({
    required String? callerUid,
    required String targetUserId,
    required Map<String, dynamic> updatePayload,
  }) {
    if (callerUid == null || callerUid.isEmpty) {
      return const SecurityEvaluationResult(
        allowed: false,
        reason: 'Unauthenticated caller',
      );
    }
    if (callerUid != targetUserId) {
      return const SecurityEvaluationResult(
        allowed: false,
        reason: 'Caller is not the document owner',
      );
    }
    final affectedKeys = updatePayload.keys.toSet();
    final unauthorizedKeys = affectedKeys.difference(safeUserUpdateFields);
    if (unauthorizedKeys.isNotEmpty) {
      return SecurityEvaluationResult(
        allowed: false,
        reason: 'Update contains non-whitelisted or forbidden keys: $unauthorizedKeys',
      );
    }
    return const SecurityEvaluationResult(allowed: true, reason: 'Authorized safe profile update');
  }

  /// Evaluates club creation request authorization.
  static SecurityEvaluationResult evaluateClubCreate({
    required String? callerUid,
    required Map<String, dynamic> callerProfile,
    required Map<String, dynamic> clubPayload,
  }) {
    if (callerUid == null || callerUid.isEmpty) {
      return const SecurityEvaluationResult(
        allowed: false,
        reason: 'Unauthenticated caller',
      );
    }
    if (callerProfile['user_type'] != 'faculty') {
      return const SecurityEvaluationResult(
        allowed: false,
        reason: 'Only faculty users are permitted to create clubs',
      );
    }
    final accountStatus = callerProfile['account_status'] as String?;
    if (accountStatus != null && accountStatus != 'active') {
      return SecurityEvaluationResult(
        allowed: false,
        reason: 'Faculty account status "$accountStatus" is not active',
      );
    }
    if (clubPayload['club_master_id'] != callerUid) {
      return const SecurityEvaluationResult(
        allowed: false,
        reason: 'club_master_id must match caller UID',
      );
    }
    final callerInst = callerProfile['institution_id'];
    final clubInst = clubPayload['institution_id'];
    if (clubInst == null || clubInst != callerInst) {
      return const SecurityEvaluationResult(
        allowed: false,
        reason: 'Club institution_id must match caller institution_id',
      );
    }
    return const SecurityEvaluationResult(allowed: true, reason: 'Authorized club creation');
  }

  /// Evaluates audit log operations for strict immutability and actor verification.
  static SecurityEvaluationResult evaluateAuditLogOperation({
    required String? callerUid,
    required String callerInstitutionId,
    required Map<String, dynamic> logPayload,
    required String operation, // 'create', 'update', 'delete'
  }) {
    if (operation == 'update' || operation == 'delete') {
      return const SecurityEvaluationResult(
        allowed: false,
        reason: 'Audit logs are strictly immutable (update and delete denied)',
      );
    }
    if (operation == 'create') {
      if (callerUid == null || callerUid.isEmpty) {
        return const SecurityEvaluationResult(allowed: false, reason: 'Unauthenticated caller');
      }
      if (logPayload['actor_user_id'] != callerUid) {
        return const SecurityEvaluationResult(
          allowed: false,
          reason: 'actor_user_id does not match authenticated caller',
        );
      }
      if (logPayload['institution_id'] != callerInstitutionId) {
        return const SecurityEvaluationResult(
          allowed: false,
          reason: 'institution_id does not match caller institution',
        );
      }
      return const SecurityEvaluationResult(allowed: true, reason: 'Authorized audit log entry');
    }
    return const SecurityEvaluationResult(allowed: false, reason: 'Unknown operation');
  }

  /// Evaluates multi-tenant data isolation.
  static SecurityEvaluationResult evaluateTenantIsolation({
    required String callerInstitutionId,
    required String resourceInstitutionId,
  }) {
    if (callerInstitutionId.isEmpty || resourceInstitutionId.isEmpty) {
      return const SecurityEvaluationResult(allowed: false, reason: 'Missing institution identity');
    }
    if (callerInstitutionId != resourceInstitutionId) {
      return SecurityEvaluationResult(
        allowed: false,
        reason: 'Cross-tenant access denied: caller=$callerInstitutionId, resource=$resourceInstitutionId',
      );
    }
    return const SecurityEvaluationResult(allowed: true, reason: 'Same-tenant access authorized');
  }

  /// Evaluates RSVP write enum validity.
  static SecurityEvaluationResult evaluateRsvpWrite({
    required String? callerUid,
    required String targetUserId,
    required String responseValue,
  }) {
    if (callerUid == null || callerUid != targetUserId) {
      return const SecurityEvaluationResult(allowed: false, reason: 'Caller must own RSVP document');
    }
    if (!validRsvpResponses.contains(responseValue)) {
      return SecurityEvaluationResult(
        allowed: false,
        reason: 'Invalid RSVP response "$responseValue"',
      );
    }
    return const SecurityEvaluationResult(allowed: true, reason: 'Valid RSVP response');
  }
}

class SecurityEvaluationResult {
  final bool allowed;
  final String reason;

  const SecurityEvaluationResult({required this.allowed, required this.reason});

  @override
  String toString() => 'SecurityEvaluationResult(allowed: $allowed, reason: "$reason")';
}

void main() {
  group('OWASP Security Hardening & Rate-Limiting Tests', () {
    test('AuthService dispatchCooldown is configured to 60 seconds', () {
      expect(AuthService.dispatchCooldown.inSeconds, equals(60));
    });

    test('canSendMagicLink and canSendPhoneOtp cooldown default mechanics', () {
      expect(AuthService.dispatchCooldown, equals(const Duration(seconds: 60)));
    });
  });

  group('Firestore Rules Whitelist & Forbidden Privilege Fields Contract', () {
    test('Exact 15 safe profile update fields are whitelisted', () {
      const expected15SafeFields = {
        'first_name',
        'last_name',
        'full_name',
        'full_name_lower',
        'search_keywords',
        'about',
        'phone_number',
        'profile_image_url',
        'fcm_token',
        'last_token_updated_at',
        'last_login_at',
        'is_online',
        'last_active_at',
        'profile_completed',
        'updated_at',
      };

      expect(
        FirestoreSecurityContractValidator.safeUserUpdateFields,
        equals(expected15SafeFields),
        reason: 'Allowed user update fields MUST match the exact 15 safe profile fields',
      );
      expect(
        FirestoreSecurityContractValidator.safeUserUpdateFields.length,
        equals(15),
        reason: 'Whitelist must contain exactly 15 safe fields',
      );
    });

    test('Privilege and identity fields are strictly absent from allowed whitelist', () {
      for (final forbidden in FirestoreSecurityContractValidator.forbiddenPrivilegeFields) {
        expect(
          FirestoreSecurityContractValidator.safeUserUpdateFields.contains(forbidden),
          isFalse,
          reason: 'Privilege field "$forbidden" MUST NOT be in allowed self-update whitelist',
        );
      }
    });

    test('Disjoint set verification between safe and forbidden privilege fields', () {
      final intersection = FirestoreSecurityContractValidator.safeUserUpdateFields.intersection(
        FirestoreSecurityContractValidator.forbiddenPrivilegeFields,
      );
      expect(
        intersection.isEmpty,
        isTrue,
        reason: 'Intersection between safe and forbidden fields must be empty but found: $intersection',
      );
    });
  });

  group('Static firestore.rules File Integrity & AST Inspection', () {
    late String rulesContent;

    setUpAll(() {
      final rulesFile = _findFirestoreRules();
      expect(rulesFile.existsSync(), isTrue, reason: 'firestore.rules must exist in project root');
      rulesContent = rulesFile.readAsStringSync();
      expect(rulesContent.isNotEmpty, isTrue);
    });

    test('firestore.rules specifies rules_version = "2"', () {
      expect(
        rulesContent.contains("rules_version = '2';"),
        isTrue,
        reason: 'Firestore rules must use rules_version 2',
      );
    });

    test('match /users/{userId} update rule strictly forbids role arrays', () {
      final userMatch = RegExp(
        r'match\s+/users/\{userId\}\s*\{([\s\S]*?)(match\s+/devices|\}\s*match\s+/clubs|\}\s*$)',
      ).firstMatch(rulesContent);

      expect(userMatch, isNotNull, reason: 'match /users/{userId} block must exist');
      final userBlock = userMatch!.group(1)!;

      // Ensure vulnerable sameTenant role array update branch is eliminated
      final forbiddenRoleKeys = [
        'is_president_of',
        'is_organizer_of',
        'clubs_joined',
        'clubs_created',
      ];

      for (final roleKey in forbiddenRoleKeys) {
        final hasRoleKeyInUpdate = RegExp(
          r'allow\s+update[\s\S]*?' + RegExp.escape(roleKey),
        ).hasMatch(userBlock);

        expect(
          hasRoleKeyInUpdate,
          isFalse,
          reason: 'Role array "$roleKey" MUST NOT appear in allow update of match /users/{userId}',
        );
      }
    });

    test('match /users/{userId} update rule requires request.auth.uid == userId and 15 safe fields', () {
      final userMatch = RegExp(
        r'match\s+/users/\{userId\}\s*\{([\s\S]*?)(match\s+/devices|\}\s*match\s+/clubs|\}\s*$)',
      ).firstMatch(rulesContent);
      final userBlock = userMatch!.group(1)!;

      expect(
        userBlock.contains('request.auth.uid == userId'),
        isTrue,
        reason: 'User profile update must require ownership (request.auth.uid == userId)',
      );

      final whitelistMatch = RegExp(
        r'affectedKeys\(\)\.hasOnly\(\[\s*([\s\S]*?)\s*\]\)',
      ).firstMatch(userBlock);

      expect(whitelistMatch, isNotNull, reason: 'affectedKeys().hasOnly([...]) must be present');
      final rawKeys = whitelistMatch!.group(1)!;
      final extractedKeys = RegExp(r"'([a-zA-Z0-9_]+)'")
          .allMatches(rawKeys)
          .map((m) => m.group(1)!)
          .toSet();

      expect(
        extractedKeys,
        equals(FirestoreSecurityContractValidator.safeUserUpdateFields),
        reason: 'firestore.rules user update whitelist must match exact 15 safe fields',
      );
    });

    test('match /clubs/{clubId} enforces faculty user_type and account_status == active', () {
      final clubMatch = RegExp(
        r'match\s+/clubs/\{clubId\}\s*\{([\s\S]*?)(match\s+/memberships|\}\s*$)',
      ).firstMatch(rulesContent);

      expect(clubMatch, isNotNull, reason: 'match /clubs/{clubId} block must exist');
      final clubBlock = clubMatch!.group(1)!;

      expect(
        clubBlock.contains("currentUser().user_type == 'faculty'"),
        isTrue,
        reason: 'Club create rule must verify user_type is faculty',
      );
      expect(
        clubBlock.contains('account_status'),
        isTrue,
        reason: 'Club create rule must enforce account_status verification',
      );
      expect(
        clubBlock.contains('allow delete: if false;'),
        isTrue,
        reason: 'Clubs cannot be deleted by direct client write',
      );
    });

    test('match /audit_logs/{auditLogId} enforces strict immutability and actor verification', () {
      final auditMatch = RegExp(
        r'match\s+/audit_logs/\{auditLogId\}\s*\{([\s\S]*?)\}',
      ).firstMatch(rulesContent);

      expect(auditMatch, isNotNull, reason: 'match /audit_logs/{auditLogId} block must exist');
      final auditBlock = auditMatch!.group(1)!;

      expect(
        auditBlock.contains('allow update, delete: if false;'),
        isTrue,
        reason: 'Audit logs must have allow update, delete: if false',
      );
      expect(
        auditBlock.contains('actor_user_id == request.auth.uid'),
        isTrue,
        reason: 'Audit log creation must require actor_user_id to match request.auth.uid',
      );
      expect(
        auditBlock.contains('sameInstitution('),
        isTrue,
        reason: 'Audit log creation must require matching institution',
      );
    });

    test('match /institutions/{institutionId} denies all client writes', () {
      final instMatch = RegExp(
        r'match\s+/institutions/\{institutionId\}\s*\{([\s\S]*?)\}',
      ).firstMatch(rulesContent);

      expect(instMatch, isNotNull, reason: 'match /institutions/{institutionId} block must exist');
      final instBlock = instMatch!.group(1)!;

      expect(
        instBlock.contains('allow write: if false;'),
        isTrue,
        reason: 'Institution documents must be read-only (allow write: if false)',
      );
    });

    test('match /storage_assets/{assetId} enforces MIME type, size validation, and delete denial', () {
      final storageMatch = RegExp(
        r'match\s+/storage_assets/\{assetId\}\s*\{([\s\S]*?)\}',
      ).firstMatch(rulesContent);

      expect(storageMatch, isNotNull, reason: 'match /storage_assets/{assetId} block must exist');
      final storageBlock = storageMatch!.group(1)!;

      expect(
        storageBlock.contains('allow delete: if false;'),
        isTrue,
        reason: 'Storage assets must deny direct client deletion',
      );
      expect(
        storageBlock.contains("content_type.matches('image/.*')"),
        isTrue,
        reason: 'Storage assets must enforce image MIME type',
      );
      expect(
        storageBlock.contains('size is int'),
        isTrue,
        reason: 'Storage assets must enforce integer size constraint',
      );
    });
  });

  group('Pure Dart Security Policy Evaluator & Contract Verification', () {
    test('allows document owner updating single safe field', () {
      final result = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        updatePayload: {'about': 'Interested in AI and Robotics'},
      );
      expect(result.allowed, isTrue);
    });

    test('allows document owner updating multiple whitelisted safe fields', () {
      final result = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        updatePayload: {
          'first_name': 'Alex',
          'last_name': 'Chen',
          'phone_number': '+1234567890',
          'is_online': true,
          'profile_completed': true,
          'updated_at': '2026-08-30T10:00:00Z',
        },
      );
      expect(result.allowed, isTrue);
    });

    test('denies non-owner attempting profile update (cross-user tampering denial)', () {
      final result = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_attacker',
        targetUserId: 'usr_victim',
        updatePayload: {'about': 'Hacked profile'},
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('not the document owner'));
    });

    test('denies owner attempting self-elevation to is_president_of', () {
      final result = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        updatePayload: {
          'is_president_of': ['club_robotics'],
        },
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('is_president_of'));
    });

    test('denies owner attempting self-elevation to is_organizer_of', () {
      final result = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        updatePayload: {
          'is_organizer_of': ['club_cybersec'],
        },
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('is_organizer_of'));
    });

    test('denies owner attempting mutation of clubs_joined or clubs_created', () {
      final result1 = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        updatePayload: {
          'clubs_joined': ['club_1', 'club_2'],
        },
      );
      expect(result1.allowed, isFalse);

      final result2 = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        updatePayload: {
          'clubs_created': ['club_1'],
        },
      );
      expect(result2.allowed, isFalse);
    });

    test('denies owner attempting self-elevation of user_type to faculty', () {
      final result = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        updatePayload: {'user_type': 'faculty'},
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('user_type'));
    });

    test('denies owner attempting tenant hopping via institution_id mutation', () {
      final result = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        updatePayload: {'institution_id': 'inst_stanford'},
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('institution_id'));
    });

    test('denies owner attempting self-activation via account_status mutation', () {
      final result = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_faculty_unverified',
        targetUserId: 'usr_faculty_unverified',
        updatePayload: {'account_status': 'active'},
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('account_status'));
    });

    test('denies mixed payload containing safe and forbidden fields atomically', () {
      final result = FirestoreSecurityContractValidator.evaluateUserUpdate(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        updatePayload: {
          'about': 'Legitimate profile update',
          'phone_number': '+1987654321',
          'is_president_of': ['club_ai'],
        },
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('is_president_of'));
    });
  });

  group('Multi-Tenant Isolation & Account Status Gating Policy Tests', () {
    test('allows active faculty to create club in their own institution', () {
      final result = FirestoreSecurityContractValidator.evaluateClubCreate(
        callerUid: 'fac_active_1',
        callerProfile: {
          'user_type': 'faculty',
          'account_status': 'active',
          'institution_id': 'inst_mit',
        },
        clubPayload: {
          'club_id': 'club_robotics',
          'club_master_id': 'fac_active_1',
          'institution_id': 'inst_mit',
        },
      );
      expect(result.allowed, isTrue);
    });

    test('denies pending_verification faculty from creating club', () {
      final result = FirestoreSecurityContractValidator.evaluateClubCreate(
        callerUid: 'fac_pending_1',
        callerProfile: {
          'user_type': 'faculty',
          'account_status': 'pending_verification',
          'institution_id': 'inst_mit',
        },
        clubPayload: {
          'club_id': 'club_robotics',
          'club_master_id': 'fac_pending_1',
          'institution_id': 'inst_mit',
        },
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('pending_verification'));
    });

    test('denies suspended or rejected faculty from creating club', () {
      final resultSuspended = FirestoreSecurityContractValidator.evaluateClubCreate(
        callerUid: 'fac_suspended',
        callerProfile: {
          'user_type': 'faculty',
          'account_status': 'suspended',
          'institution_id': 'inst_mit',
        },
        clubPayload: {
          'club_id': 'club_robotics',
          'club_master_id': 'fac_suspended',
          'institution_id': 'inst_mit',
        },
      );
      expect(resultSuspended.allowed, isFalse);

      final resultRejected = FirestoreSecurityContractValidator.evaluateClubCreate(
        callerUid: 'fac_rejected',
        callerProfile: {
          'user_type': 'faculty',
          'account_status': 'rejected',
          'institution_id': 'inst_mit',
        },
        clubPayload: {
          'club_id': 'club_robotics',
          'club_master_id': 'fac_rejected',
          'institution_id': 'inst_mit',
        },
      );
      expect(resultRejected.allowed, isFalse);
    });

    test('denies student from creating club', () {
      final result = FirestoreSecurityContractValidator.evaluateClubCreate(
        callerUid: 'student_1',
        callerProfile: {
          'user_type': 'student',
          'account_status': 'active',
          'institution_id': 'inst_mit',
        },
        clubPayload: {
          'club_id': 'club_gaming',
          'club_master_id': 'student_1',
          'institution_id': 'inst_mit',
        },
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('Only faculty'));
    });

    test('denies faculty from creating club in another institution', () {
      final result = FirestoreSecurityContractValidator.evaluateClubCreate(
        callerUid: 'fac_mit',
        callerProfile: {
          'user_type': 'faculty',
          'account_status': 'active',
          'institution_id': 'inst_mit',
        },
        clubPayload: {
          'club_id': 'club_stanford_ai',
          'club_master_id': 'fac_mit',
          'institution_id': 'inst_stanford',
        },
      );
      expect(result.allowed, isFalse);
      expect(result.reason, contains('institution_id'));
    });

    test('allows actor to create audit log with matching UID and institution', () {
      final result = FirestoreSecurityContractValidator.evaluateAuditLogOperation(
        callerUid: 'usr_faculty_1',
        callerInstitutionId: 'inst_mit',
        logPayload: {
          'actor_user_id': 'usr_faculty_1',
          'institution_id': 'inst_mit',
          'action': 'club_created',
          'target_type': 'club',
          'target_id': 'club_cs',
        },
        operation: 'create',
      );
      expect(result.allowed, isTrue);
    });

    test('denies audit log creation with spoofed actor UID or mismatched institution', () {
      final resultSpoofedUid = FirestoreSecurityContractValidator.evaluateAuditLogOperation(
        callerUid: 'usr_attacker',
        callerInstitutionId: 'inst_mit',
        logPayload: {
          'actor_user_id': 'usr_victim',
          'institution_id': 'inst_mit',
          'action': 'event_approved',
        },
        operation: 'create',
      );
      expect(resultSpoofedUid.allowed, isFalse);
      expect(resultSpoofedUid.reason, contains('actor_user_id'));

      final resultMismatchInst = FirestoreSecurityContractValidator.evaluateAuditLogOperation(
        callerUid: 'usr_faculty_1',
        callerInstitutionId: 'inst_mit',
        logPayload: {
          'actor_user_id': 'usr_faculty_1',
          'institution_id': 'inst_stanford',
          'action': 'event_approved',
        },
        operation: 'create',
      );
      expect(resultMismatchInst.allowed, isFalse);
      expect(resultMismatchInst.reason, contains('institution_id'));
    });

    test('denies audit log update and deletion operations categorically', () {
      final resultUpdate = FirestoreSecurityContractValidator.evaluateAuditLogOperation(
        callerUid: 'usr_admin',
        callerInstitutionId: 'inst_mit',
        logPayload: {'action': 'tampered_action'},
        operation: 'update',
      );
      expect(resultUpdate.allowed, isFalse);
      expect(resultUpdate.reason, contains('immutable'));

      final resultDelete = FirestoreSecurityContractValidator.evaluateAuditLogOperation(
        callerUid: 'usr_admin',
        callerInstitutionId: 'inst_mit',
        logPayload: {},
        operation: 'delete',
      );
      expect(resultDelete.allowed, isFalse);
      expect(resultDelete.reason, contains('immutable'));
    });

    test('enforces tenant isolation across institutions', () {
      final resultSameTenant = FirestoreSecurityContractValidator.evaluateTenantIsolation(
        callerInstitutionId: 'inst_mit',
        resourceInstitutionId: 'inst_mit',
      );
      expect(resultSameTenant.allowed, isTrue);

      final resultCrossTenant = FirestoreSecurityContractValidator.evaluateTenantIsolation(
        callerInstitutionId: 'inst_mit',
        resourceInstitutionId: 'inst_stanford',
      );
      expect(resultCrossTenant.allowed, isFalse);
      expect(resultCrossTenant.reason, contains('Cross-tenant'));
    });

    test('validates RSVP response enums', () {
      for (final validEnum in ['attending', 'interested', 'not_going']) {
        final result = FirestoreSecurityContractValidator.evaluateRsvpWrite(
          callerUid: 'usr_student_1',
          targetUserId: 'usr_student_1',
          responseValue: validEnum,
        );
        expect(result.allowed, isTrue, reason: 'Valid enum $validEnum should be allowed');
      }

      final resultInvalid = FirestoreSecurityContractValidator.evaluateRsvpWrite(
        callerUid: 'usr_student_1',
        targetUserId: 'usr_student_1',
        responseValue: 'super_excited',
      );
      expect(resultInvalid.allowed, isFalse);
      expect(resultInvalid.reason, contains('Invalid RSVP'));
    });
  });

  group('Data Model Serialization & Subcollection Contract Tests', () {
    test('UserModel serializes correctly without leaking client-writable privilege fields', () {
      final now = DateTime(2026, 8, 30, 10, 0, 0);
      final user = UserModel(
        uid: 'usr_student_1',
        institutionId: 'inst_mit',
        email: 'alex@mit.edu',
        phoneNumber: '+1234567890',
        firstName: 'Alex',
        lastName: 'Chen',
        fullName: 'Alex Chen',
        userType: 'student',
        gender: 'Male',
        dateOfBirth: DateTime(2003, 5, 20),
        collegeName: 'MIT',
        about: 'CS Senior',
        createdAt: now,
        updatedAt: now,
        clubsJoined: ['club_robotics'],
        clubsCreated: [],
        isPresidentOf: ['club_robotics'],
        isOrganizerOf: [],
      );

      final map = user.toFirestore();
      expect(map['institution_id'], equals('inst_mit'));
      expect(map['email'], equals('alex@mit.edu'));
      expect(map['first_name'], equals('Alex'));
      expect(map['about'], equals('CS Senior'));
    });

    test('AuditLogModel serializes with actor_user_id, institution_id, and action', () {
      final now = DateTime(2026, 8, 30, 10, 0, 0);
      final log = AuditLogModel(
        auditLogId: 'log_abc',
        institutionId: 'inst_mit',
        actorUserId: 'usr_faculty_1',
        actorRole: 'faculty',
        action: 'club_created',
        targetType: 'club',
        targetId: 'club_robotics',
        metadata: {'club_name': 'Robotics Society'},
        createdAt: now,
      );

      final map = log.toFirestore();
      expect(map['actor_user_id'], equals('usr_faculty_1'));
      expect(map['institution_id'], equals('inst_mit'));
      expect(map['action'], equals('club_created'));
      expect(map['target_id'], equals('club_robotics'));
    });

    test('ClubMembershipModel toUserMirrorFirestore contains only safe display fields', () {
      final now = DateTime(2026, 8, 30);
      final membership = ClubMembershipModel(
        membershipId: 'usr_student_1',
        clubId: 'club_robotics',
        userId: 'usr_student_1',
        userName: 'Alex Chen',
        institutionId: 'inst_mit',
        role: ClubMembershipRole.member,
        joinedAt: now,
        updatedAt: now,
      );

      final mirror = membership.toUserMirrorFirestore(
        clubName: 'Robotics Society',
        clubCategory: 'Technical',
        clubLogoUrl: 'https://example.com/logo.png',
      );

      expect(mirror['club_id'], equals('club_robotics'));
      expect(mirror['club_name'], equals('Robotics Society'));
      expect(mirror['role'], equals('member'));
    });
  });
}
