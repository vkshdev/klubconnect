import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/models/user_model.dart';
import 'package:klub_connect/models/club_model.dart';
import 'package:klub_connect/services/institution_service.dart';
import 'package:klub_connect/utils/constants.dart';

void main() {
  group('Empirical Challenger M2: Dual-Mode Domain & Subdomain Edge Cases', () {
    test('Standard domain exact match is permitted', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'professor@mit.edu',
          facultyDomains: ['mit.edu'],
        ),
        isTrue,
      );
    });

    test('Single-level subdomain (cs.mit.edu) is permitted', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'alan@cs.mit.edu',
          facultyDomains: ['mit.edu'],
        ),
        isTrue,
      );
    });

    test('Multi-level nested subdomain (eecs.cs.mit.edu) is permitted', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'dean@eecs.cs.mit.edu',
          facultyDomains: ['mit.edu'],
        ),
        isTrue,
      );
    });

    test('Subdomain matching rejects spoofed domain suffix (fake-mit.edu)', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'attacker@fake-mit.edu',
          facultyDomains: ['mit.edu'],
        ),
        isFalse,
      );
    });

    test('Subdomain matching rejects attacker domain ending with target (notmit.edu)', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'attacker@notmit.edu',
          facultyDomains: ['mit.edu'],
        ),
        isFalse,
      );
    });

    test('Subdomain matching rejects domain used as subdomain of attacker (mit.edu.attacker.com)', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'attacker@mit.edu.attacker.com',
          facultyDomains: ['mit.edu'],
        ),
        isFalse,
      );
    });

    test('Domain matching handles uppercase, whitespace, and leading @ in both email and domain list', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: '  PROFESSOR@CS.MIT.EDU  \n',
          facultyDomains: ['  @MIT.EDU  '],
        ),
        isTrue,
      );
    });

    test('Rejects invalid email format without @ or missing domain', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'professor-mit.edu',
          facultyDomains: ['mit.edu'],
        ),
        isFalse,
      );
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'professor@',
          facultyDomains: ['mit.edu'],
        ),
        isFalse,
      );
    });

    test('Rejects when faculty domain list is empty', () {
      expect(
        InstitutionService.isFacultyEmailAllowed(
          email: 'prof@mit.edu',
          facultyDomains: [],
        ),
        isFalse,
      );
    });
  });

  group('Empirical Challenger M2: Invite Code Whitespace & Case Stress Tests', () {
    const validCodes = ['MIT-FAC-2026', 'DEAN-VIP-77'];

    test('Validates exact uppercase match', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: 'MIT-FAC-2026',
          validCodes: validCodes,
        ),
        isTrue,
      );
    });

    test('Validates lowercase match', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: 'mit-fac-2026',
          validCodes: validCodes,
        ),
        isTrue,
      );
    });

    test('Validates mixed case match', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: 'Mit-Fac-2026',
          validCodes: validCodes,
        ),
        isTrue,
      );
    });

    test('Validates code surrounded by leading/trailing whitespace and tabs', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: '\t  MIT-FAC-2026  \n',
          validCodes: validCodes,
        ),
        isTrue,
      );
    });

    test('Validates code when institution list itself has whitespace and lowercase', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: 'MIT-FAC-2026',
          validCodes: ['  mit-fac-2026  '],
        ),
        isTrue,
      );
    });

    test('Rejects empty or whitespace-only invite code', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: '',
          validCodes: validCodes,
        ),
        isFalse,
      );
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: '    ',
          validCodes: validCodes,
        ),
        isFalse,
      );
    });

    test('Rejects unauthorized / wrong invite codes', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: 'MIT-STUDENT-2026',
          validCodes: validCodes,
        ),
        isFalse,
      );
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: 'DEAN-VIP-78',
          validCodes: validCodes,
        ),
        isFalse,
      );
    });

    test('Rejects any invite code when validCodes list is empty', () {
      expect(
        InstitutionService.isFacultyInviteCodeValid(
          inviteCode: 'MIT-FAC-2026',
          validCodes: [],
        ),
        isFalse,
      );
    });
  });

  group('Empirical Challenger M2: verifyFaculty Dual-Mode & Fallback Scenarios', () {
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

    test('Faculty with verified domain and no invite code -> active (domain mode)', () {
      final res = InstitutionService.verifyFaculty(
        email: 'prof@mit.edu',
        inviteCode: null,
        institution: institution,
      );
      expect(res.accountStatus, equals('active'));
      expect(res.isVerified, isTrue);
      expect(res.verifiedVia, equals('domain'));
    });

    test('Faculty with verified subdomain and no invite code -> active (domain mode)', () {
      final res = InstitutionService.verifyFaculty(
        email: 'prof@cs.mit.edu',
        inviteCode: null,
        institution: institution,
      );
      expect(res.accountStatus, equals('active'));
      expect(res.isVerified, isTrue);
      expect(res.verifiedVia, equals('domain'));
    });

    test('Faculty with unlisted domain (@gmail.com) and valid invite code -> active (invite_code mode)', () {
      final res = InstitutionService.verifyFaculty(
        email: 'prof.adjunct@gmail.com',
        inviteCode: '  mit-fac-2026  ',
        institution: institution,
      );
      expect(res.accountStatus, equals('active'));
      expect(res.isVerified, isTrue);
      expect(res.verifiedVia, equals('invite_code'));
    });

    test('Faculty with unlisted domain and NO invite code (null) -> pending_verification', () {
      final res = InstitutionService.verifyFaculty(
        email: 'prof.adjunct@gmail.com',
        inviteCode: null,
        institution: institution,
      );
      expect(res.accountStatus, equals('pending_verification'));
      expect(res.isVerified, isFalse);
      expect(res.verifiedVia, isNull);
    });

    test('Faculty with unlisted domain and empty invite code ("") -> pending_verification', () {
      final res = InstitutionService.verifyFaculty(
        email: 'prof.adjunct@gmail.com',
        inviteCode: '',
        institution: institution,
      );
      expect(res.accountStatus, equals('pending_verification'));
      expect(res.isVerified, isFalse);
      expect(res.verifiedVia, isNull);
    });

    test('Faculty with unlisted domain and whitespace invite code ("   ") -> pending_verification', () {
      final res = InstitutionService.verifyFaculty(
        email: 'prof.adjunct@gmail.com',
        inviteCode: '   ',
        institution: institution,
      );
      expect(res.accountStatus, equals('pending_verification'));
      expect(res.isVerified, isFalse);
      expect(res.verifiedVia, isNull);
    });

    test('Faculty with unlisted domain and invalid invite code -> pending_verification', () {
      final res = InstitutionService.verifyFaculty(
        email: 'prof.adjunct@gmail.com',
        inviteCode: 'INVALID-CODE',
        institution: institution,
      );
      expect(res.accountStatus, equals('pending_verification'));
      expect(res.isVerified, isFalse);
      expect(res.verifiedVia, isNull);
    });

    test('Faculty with verified domain and invalid invite code still activates via domain', () {
      final res = InstitutionService.verifyFaculty(
        email: 'prof@mit.edu',
        inviteCode: 'INVALID-CODE',
        institution: institution,
      );
      expect(res.accountStatus, equals('active'));
      expect(res.isVerified, isTrue);
      expect(res.verifiedVia, equals('domain'));
    });

    test('Null institution fallback -> pending_verification', () {
      final res = InstitutionService.verifyFaculty(
        email: 'prof@mit.edu',
        inviteCode: 'MIT-FAC-2026',
        institution: null,
      );
      expect(res.accountStatus, equals('pending_verification'));
      expect(res.isVerified, isFalse);
    });
  });

  group('Empirical Challenger M2: Account Status Gating Stress Tests', () {
    final activeFaculty = UserModel(
      uid: 'fac_active_1',
      email: 'active@mit.edu',
      phoneNumber: '+919876543210',
      firstName: 'Active',
      lastName: 'Faculty',
      fullName: 'Active Faculty',
      userType: AppConstants.userTypeFaculty,
      gender: 'Female',
      dateOfBirth: DateTime(1985, 1, 1),
      collegeName: 'Massachusetts Institute of Technology',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      accountStatus: 'active',
    );

    final pendingFaculty = UserModel(
      uid: 'fac_pending_1',
      email: 'pending@gmail.com',
      phoneNumber: '+919876543211',
      firstName: 'Pending',
      lastName: 'Faculty',
      fullName: 'Pending Faculty',
      userType: AppConstants.userTypeFaculty,
      gender: 'Male',
      dateOfBirth: DateTime(1985, 1, 1),
      collegeName: 'Massachusetts Institute of Technology',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      accountStatus: 'pending_verification',
    );

    final suspendedFaculty = UserModel(
      uid: 'fac_suspended_1',
      email: 'suspended@mit.edu',
      phoneNumber: '+919876543212',
      firstName: 'Suspended',
      lastName: 'Faculty',
      fullName: 'Suspended Faculty',
      userType: AppConstants.userTypeFaculty,
      gender: 'Other',
      dateOfBirth: DateTime(1985, 1, 1),
      collegeName: 'Massachusetts Institute of Technology',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      accountStatus: 'suspended',
    );

    final student = UserModel(
      uid: 'student_1',
      email: 'student@mit.edu',
      phoneNumber: '+919876543213',
      firstName: 'Student',
      lastName: 'User',
      fullName: 'Student User',
      userType: AppConstants.userTypeStudent,
      gender: 'Female',
      dateOfBirth: DateTime(2002, 1, 1),
      collegeName: 'Massachusetts Institute of Technology',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      accountStatus: 'active',
    );

    test('isFacultyVerified is true ONLY for faculty with active status', () {
      expect(activeFaculty.isFacultyVerified, isTrue);
      expect(pendingFaculty.isFacultyVerified, isFalse);
      expect(suspendedFaculty.isFacultyVerified, isFalse);
      expect(student.isFacultyVerified, isFalse);
    });

    test('isPendingVerification is true ONLY for pending_verification accounts', () {
      expect(activeFaculty.isPendingVerification, isFalse);
      expect(pendingFaculty.isPendingVerification, isTrue);
      expect(suspendedFaculty.isPendingVerification, isFalse);
      expect(student.isPendingVerification, isFalse);
    });

    test('Club Master gating strictly rejects pending and suspended faculty', () {
      final club = ClubModel(
        clubId: 'club_ai',
        institutionId: 'inst_mit',
        name: 'AI Society',
        slug: 'ai-society',
        description: 'Artificial Intelligence Research',
        logoUrl: '',
        bannerUrl: '',
        category: 'Technical',
        colorCode: '#2563EB',
        collegeName: 'Massachusetts Institute of Technology',
        clubMasterId: 'fac_pending_1',
        clubMasterName: 'Pending Faculty',
        presidentId: 'student_1',
        presidentName: 'Student User',
        organizers: const [],
        members: const ['student_1'],
        totalMembers: 1,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // Club master check matching HomeScreen and ClubDetailsScreen logic
      bool isAuthorizedClubMaster(UserModel user, ClubModel c) {
        return c.clubMasterId == user.uid &&
            (user.userType != AppConstants.userTypeFaculty || user.isFacultyVerified);
      }

      expect(isAuthorizedClubMaster(pendingFaculty, club), isFalse);
      expect(isAuthorizedClubMaster(suspendedFaculty, club), isFalse);

      final clubWithActiveMaster = ClubModel(
        clubId: 'club_ai',
        institutionId: 'inst_mit',
        name: 'AI Society',
        slug: 'ai-society',
        description: 'Artificial Intelligence Research',
        logoUrl: '',
        bannerUrl: '',
        category: 'Technical',
        colorCode: '#2563EB',
        collegeName: 'Massachusetts Institute of Technology',
        clubMasterId: 'fac_active_1',
        clubMasterName: 'Active Faculty',
        presidentId: 'student_1',
        presidentName: 'Student User',
        organizers: const [],
        members: const ['student_1'],
        totalMembers: 1,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(isAuthorizedClubMaster(activeFaculty, clubWithActiveMaster), isTrue);
    });
  });
}
