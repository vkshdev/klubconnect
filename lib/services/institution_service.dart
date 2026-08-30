import 'package:cloud_firestore/cloud_firestore.dart';

class InstitutionModel {
  final String institutionId;
  final String name;
  final String slug;
  final List<String> allowedEmailDomains;
  final String status; // 'active', 'pending', 'suspended'
  final List<String> adminUserIds;
  final DateTime createdAt;

  const InstitutionModel({
    required this.institutionId,
    required this.name,
    required this.slug,
    required this.allowedEmailDomains,
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
      'status': status,
      'admin_user_ids': adminUserIds,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
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
