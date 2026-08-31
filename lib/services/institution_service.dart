import 'package:cloud_firestore/cloud_firestore.dart';

class InstitutionModel {
  final String institutionId;
  final String name;
  final String slug;
  final List<String> allowedEmailDomains;
  final List<String> facultyEmailDomains;
  final List<String> facultyInviteCodes;
  final String status; // 'active', 'pending', 'suspended'
  final List<String> adminUserIds;
  final DateTime createdAt;

  const InstitutionModel({
    required this.institutionId,
    required this.name,
    required this.slug,
    required this.allowedEmailDomains,
    this.facultyEmailDomains = const [],
    this.facultyInviteCodes = const [],
    required this.status,
    required this.adminUserIds,
    required this.createdAt,
  });

  factory InstitutionModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return InstitutionModel(
      institutionId: doc.id,
      name: data['name']?.toString() ?? '',
      slug: data['slug']?.toString() ?? '',
      allowedEmailDomains: (data['allowed_email_domains'] as List<dynamic>?)
              ?.map((e) => e.toString().toLowerCase().trim())
              .toList() ??
          [],
      facultyEmailDomains: (data['faculty_email_domains'] as List<dynamic>?)
              ?.map((e) => e.toString().toLowerCase().trim())
              .toList() ??
          [],
      facultyInviteCodes: (data['faculty_invite_codes'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .toList() ??
          [],
      status: data['status']?.toString() ?? 'active',
      adminUserIds: (data['admin_user_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: (data['created_at'] is Timestamp)
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'allowed_email_domains': allowedEmailDomains,
      'faculty_email_domains': facultyEmailDomains,
      'faculty_invite_codes': facultyInviteCodes,
      'status': status,
      'admin_user_ids': adminUserIds,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}

class FacultyVerificationResult {
  final String accountStatus;
  final bool isVerified;
  final String? verifiedVia;
  final String reason;

  const FacultyVerificationResult({
    required this.accountStatus,
    required this.isVerified,
    this.verifiedVia,
    required this.reason,
  });
}

class InstitutionService {
  final FirebaseFirestore _firestore;

  InstitutionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static bool isEmailAllowed({
    required String email,
    required List<String> allowedDomains,
  }) {
    if (allowedDomains.isEmpty) return true; // Open if no domain restriction configured
    final cleanEmail = email.trim().toLowerCase();
    final atIndex = cleanEmail.lastIndexOf('@');
    if (atIndex == -1 || atIndex == cleanEmail.length - 1) return false;
    final domain = cleanEmail.substring(atIndex + 1);

    for (final allowed in allowedDomains) {
      final cleanAllowed = allowed.trim().toLowerCase().replaceAll('@', '');
      if (domain == cleanAllowed || domain.endsWith('.$cleanAllowed')) {
        return true;
      }
    }
    return false;
  }

  static bool isFacultyEmailAllowed({
    required String email,
    required List<String> facultyDomains,
  }) {
    if (facultyDomains.isEmpty) return false;
    final cleanEmail = email.trim().toLowerCase();
    final atIndex = cleanEmail.lastIndexOf('@');
    if (atIndex == -1 || atIndex == cleanEmail.length - 1) return false;
    final domain = cleanEmail.substring(atIndex + 1);

    for (final allowed in facultyDomains) {
      final cleanAllowed = allowed.trim().toLowerCase().replaceAll('@', '');
      if (domain == cleanAllowed || domain.endsWith('.$cleanAllowed')) {
        return true;
      }
    }
    return false;
  }

  static bool isFacultyInviteCodeValid({
    required String inviteCode,
    required List<String> validCodes,
  }) {
    final cleanCode = inviteCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;
    return validCodes.any((code) => code.trim().toUpperCase() == cleanCode);
  }

  static FacultyVerificationResult verifyFaculty({
    required String email,
    String? inviteCode,
    required InstitutionModel? institution,
  }) {
    if (institution == null) {
      return const FacultyVerificationResult(
        accountStatus: 'pending_verification',
        isVerified: false,
        reason: 'Institution record not found',
      );
    }

    if (isFacultyEmailAllowed(
      email: email,
      facultyDomains: institution.facultyEmailDomains,
    )) {
      return const FacultyVerificationResult(
        accountStatus: 'active',
        isVerified: true,
        verifiedVia: 'domain',
        reason: 'Verified via institution faculty domain',
      );
    }

    if (inviteCode != null &&
        inviteCode.trim().isNotEmpty &&
        isFacultyInviteCodeValid(
          inviteCode: inviteCode,
          validCodes: institution.facultyInviteCodes,
        )) {
      return const FacultyVerificationResult(
        accountStatus: 'active',
        isVerified: true,
        verifiedVia: 'invite_code',
        reason: 'Verified via authorized invite code',
      );
    }

    return const FacultyVerificationResult(
      accountStatus: 'pending_verification',
      isVerified: false,
      reason: 'Email domain not verified and no valid invite code provided',
    );
  }

  Future<InstitutionModel?> getInstitutionById(String institutionId) async {
    if (institutionId.isEmpty) return null;
    final doc = await _firestore.collection('institutions').doc(institutionId).get();
    if (!doc.exists) return null;
    return InstitutionModel.fromFirestore(doc);
  }

  Stream<InstitutionModel?> streamInstitution(String institutionId) {
    if (institutionId.isEmpty) return Stream.value(null);
    return _firestore
        .collection('institutions')
        .doc(institutionId)
        .snapshots()
        .map((doc) => doc.exists ? InstitutionModel.fromFirestore(doc) : null);
  }
}
