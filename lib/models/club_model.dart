import 'package:cloud_firestore/cloud_firestore.dart';

class ClubModel {
  final String clubId;
  final String name;
  final String slug;
  final String description;
  final String logoUrl;
  final String bannerUrl;
  final String category;
  final String colorCode;
  final String collegeName;
  final String clubMasterId;
  final String clubMasterName;
  final String presidentId;
  final String presidentName;
  final List<String> organizers;
  final List<String> members;
  final int totalMembers;
  final bool isActive;
  final bool isAcceptingMembers;
  final Map<String, String> socialLinks;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClubModel({
    required this.clubId,
    required this.name,
    required this.slug,
    required this.description,
    required this.logoUrl,
    required this.bannerUrl,
    required this.category,
    required this.colorCode,
    required this.collegeName,
    required this.clubMasterId,
    required this.clubMasterName,
    required this.presidentId,
    required this.presidentName,
    this.organizers = const [],
    this.members = const [],
    this.totalMembers = 0,
    this.isActive = true,
    this.isAcceptingMembers = true,
    this.socialLinks = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClubModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubModel(
      clubId: doc.id,
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      description: data['description'] ?? '',
      logoUrl: data['logo_url'] ?? '',
      bannerUrl: data['banner_url'] ?? '',
      category: data['category'] ?? '',
      colorCode: data['color_code'] ?? '#000000',
      collegeName: data['college_name'] ?? '',
      clubMasterId: data['club_master_id'] ?? '',
      clubMasterName: data['club_master_name'] ?? '',
      presidentId: data['president_id'] ?? '',
      presidentName: data['president_name'] ?? '',
      organizers: List<String>.from(data['organizers'] ?? []),
      members: List<String>.from(data['members'] ?? []),
      totalMembers: data['total_members'] ?? 0,
      isActive: data['is_active'] ?? true,
      isAcceptingMembers: data['is_accepting_members'] ?? true,
      socialLinks: Map<String, String>.from(data['social_links'] ?? {}),
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'logo_url': logoUrl,
      'banner_url': bannerUrl,
      'category': category,
      'color_code': colorCode,
      'college_name': collegeName,
      'club_master_id': clubMasterId,
      'club_master_name': clubMasterName,
      'president_id': presidentId,
      'president_name': presidentName,
      'organizers': organizers,
      'members': members,
      'total_members': totalMembers,
      'is_active': isActive,
      'is_accepting_members': isAcceptingMembers,
      'social_links': socialLinks,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  ClubModel copyWith({
    String? name,
    String? slug,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    String? category,
    String? colorCode,
    String? collegeName,
    String? clubMasterId,
    String? clubMasterName,
    String? presidentId,
    String? presidentName,
    List<String>? organizers,
    List<String>? members,
    int? totalMembers,
    bool? isActive,
    bool? isAcceptingMembers,
    Map<String, String>? socialLinks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClubModel(
      clubId: clubId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      category: category ?? this.category,
      colorCode: colorCode ?? this.colorCode,
      collegeName: collegeName ?? this.collegeName,
      clubMasterId: clubMasterId ?? this.clubMasterId,
      clubMasterName: clubMasterName ?? this.clubMasterName,
      presidentId: presidentId ?? this.presidentId,
      presidentName: presidentName ?? this.presidentName,
      organizers: organizers ?? this.organizers,
      members: members ?? this.members,
      totalMembers: totalMembers ?? this.totalMembers,
      isActive: isActive ?? this.isActive,
      isAcceptingMembers: isAcceptingMembers ?? this.isAcceptingMembers,
      socialLinks: socialLinks ?? this.socialLinks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
