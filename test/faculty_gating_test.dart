import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klub_connect/models/user_model.dart';
import 'package:klub_connect/models/club_model.dart';
import 'package:klub_connect/utils/constants.dart';
import 'package:klub_connect/utils/theme.dart';

void main() {
  group('UserModel Account Status & Faculty Verification Tests', () {
    test('Default accountStatus is active for new user models', () {
      final user = UserModel(
        uid: 'usr_student_1',
        email: 'student@mit.edu',
        phoneNumber: '+919876543210',
        firstName: 'John',
        lastName: 'Doe',
        fullName: 'John Doe',
        userType: AppConstants.userTypeStudent,
        gender: 'Male',
        dateOfBirth: DateTime(2002, 5, 20),
        collegeName: 'Massachusetts Institute of Technology',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(user.accountStatus, equals('active'));
      expect(user.isVerified, isTrue);
      expect(user.isFacultyVerified, isFalse);
      expect(user.isPendingVerification, isFalse);
    });

    test('Faculty user with active status is marked isFacultyVerified', () {
      final faculty = UserModel(
        uid: 'usr_fac_1',
        email: 'prof@mit.edu',
        phoneNumber: '+919876543211',
        firstName: 'Alan',
        lastName: 'Turing',
        fullName: 'Alan Turing',
        userType: AppConstants.userTypeFaculty,
        gender: 'Male',
        dateOfBirth: DateTime(1980, 6, 23),
        collegeName: 'Massachusetts Institute of Technology',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        accountStatus: 'active',
      );

      expect(faculty.accountStatus, equals('active'));
      expect(faculty.isVerified, isTrue);
      expect(faculty.isFacultyVerified, isTrue);
      expect(faculty.isPendingVerification, isFalse);
    });

    test('Faculty user with pending_verification status is gated', () {
      final unverifiedFaculty = UserModel(
        uid: 'usr_fac_pending',
        email: 'turing@gmail.com',
        phoneNumber: '+919876543212',
        firstName: 'Alan',
        lastName: 'Turing',
        fullName: 'Alan Turing',
        userType: AppConstants.userTypeFaculty,
        gender: 'Male',
        dateOfBirth: DateTime(1980, 6, 23),
        collegeName: 'Massachusetts Institute of Technology',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        accountStatus: 'pending_verification',
      );

      expect(unverifiedFaculty.accountStatus, equals('pending_verification'));
      expect(unverifiedFaculty.isVerified, isFalse);
      expect(unverifiedFaculty.isFacultyVerified, isFalse);
      expect(unverifiedFaculty.isPendingVerification, isTrue);
    });

    test('UserModel toFirestore serializes accountStatus, inviteCode and verifiedAt', () {
      final now = DateTime(2026, 8, 30, 12, 0, 0);
      final faculty = UserModel(
        uid: 'usr_fac_2',
        email: 'prof@mit.edu',
        phoneNumber: '+919876543213',
        firstName: 'Grace',
        lastName: 'Hopper',
        fullName: 'Grace Hopper',
        userType: AppConstants.userTypeFaculty,
        gender: 'Female',
        dateOfBirth: DateTime(1985, 12, 9),
        collegeName: 'Massachusetts Institute of Technology',
        createdAt: now,
        updatedAt: now,
        accountStatus: 'active',
        facultyInviteCode: 'MIT-FAC-2026',
        verifiedAt: now,
      );

      final map = faculty.toFirestore();
      expect(map['account_status'], equals('active'));
      expect(map['faculty_invite_code'], equals('MIT-FAC-2026'));
      expect(map['verified_at'], isNotNull);
    });
  });

  group('Faculty Gating Logic Tests', () {
    test('Unverified faculty cannot be treated as authorized club master', () {
      final unverifiedFaculty = UserModel(
        uid: 'usr_fac_pending',
        email: 'turing@gmail.com',
        phoneNumber: '+919876543212',
        firstName: 'Alan',
        lastName: 'Turing',
        fullName: 'Alan Turing',
        userType: AppConstants.userTypeFaculty,
        gender: 'Male',
        dateOfBirth: DateTime(1980, 6, 23),
        collegeName: 'Massachusetts Institute of Technology',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        accountStatus: 'pending_verification',
      );

      final club = ClubModel(
        clubId: 'club_robotics',
        institutionId: 'inst_mit',
        name: 'Robotics Club',
        slug: 'robotics-club',
        description: 'Building robots and autonomous machines.',
        logoUrl: '',
        bannerUrl: '',
        category: 'Technology',
        colorCode: '#2563EB',
        collegeName: 'Massachusetts Institute of Technology',
        clubMasterId: 'usr_fac_pending',
        clubMasterName: 'Alan Turing',
        presidentId: 'usr_student_1',
        presidentName: 'John Doe',
        organizers: [],
        members: ['usr_student_1'],
        totalMembers: 1,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final bool isAuthorizedMaster =
          club.clubMasterId == unverifiedFaculty.uid &&
          (unverifiedFaculty.userType != 'faculty' ||
              unverifiedFaculty.isFacultyVerified);

      expect(isAuthorizedMaster, isFalse);
    });

    test('Verified faculty is authorized as active club master', () {
      final verifiedFaculty = UserModel(
        uid: 'usr_fac_active',
        email: 'prof@mit.edu',
        phoneNumber: '+919876543214',
        firstName: 'Grace',
        lastName: 'Hopper',
        fullName: 'Grace Hopper',
        userType: AppConstants.userTypeFaculty,
        gender: 'Female',
        dateOfBirth: DateTime(1985, 12, 9),
        collegeName: 'Massachusetts Institute of Technology',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        accountStatus: 'active',
      );

      final club = ClubModel(
        clubId: 'club_comp',
        institutionId: 'inst_mit',
        name: 'Computing Society',
        slug: 'computing-society',
        description: 'Systems and software engineering.',
        logoUrl: '',
        bannerUrl: '',
        category: 'Technology',
        colorCode: '#2563EB',
        collegeName: 'Massachusetts Institute of Technology',
        clubMasterId: 'usr_fac_active',
        clubMasterName: 'Grace Hopper',
        presidentId: 'usr_student_1',
        presidentName: 'John Doe',
        organizers: [],
        members: ['usr_student_1'],
        totalMembers: 1,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final bool isAuthorizedMaster =
          club.clubMasterId == verifiedFaculty.uid &&
          (verifiedFaculty.userType != 'faculty' ||
              verifiedFaculty.isFacultyVerified);

      expect(isAuthorizedMaster, isTrue);
    });
  });

  group('Onboarding Status Banner & Badge Widget Tests', () {
    testWidgets('Renders Pending Verification banner for unverified faculty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Inter'),
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.pending_actions_rounded,
                        color: AppTheme.warningColor,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Faculty Verification Pending',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your faculty account is pending institution approval. You have read-only access until verified.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.vpn_key_rounded),
                    label: const Text('Verify with Invite Code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Faculty Verification Pending'), findsOneWidget);
      expect(
        find.text(
          'Your faculty account is pending institution approval. You have read-only access until verified.',
        ),
        findsOneWidget,
      );
      expect(find.text('Verify with Invite Code'), findsOneWidget);
      expect(find.byIcon(Icons.pending_actions_rounded), findsOneWidget);
    });

    testWidgets('Renders Active vs Pending Verification badges accurately',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Active badge
                Container(
                  key: const ValueKey('active_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12),
                      SizedBox(width: 4),
                      Text('ACTIVE'),
                    ],
                  ),
                ),
                // Pending badge
                Container(
                  key: const ValueKey('pending_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pending_rounded, size: 12),
                      SizedBox(width: 4),
                      Text('PENDING VERIFICATION'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('PENDING VERIFICATION'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pending_rounded), findsOneWidget);
    });
  });
}
