import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/institution_utils.dart';
import '../utils/search_index_utils.dart';

class UserModel {
  final String uid;
  final String institutionId;
  final String email;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String fullName;
  final String userType; // 'student' or 'faculty'
  final String gender;
  final DateTime dateOfBirth;
  final String collegeName;
  final String? profileImageUrl;
  final String? about;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final bool profileCompleted;

  // Student specific
  final String? enrollmentNumber;
  final bool? enrollmentVisible;
  final String? course;
  final String? branch;
  final int? sessionStartYear;
  final int? sessionEndYear;
  final int? currentYear;
  final String? currentYearLabel;
  final String? address;

  // Faculty specific
  final String? profession;
  final String? department;
  final int? collegeJoinedYear;
  final List<String>? specialization;

  // Arrays
  final List<String> clubsJoined;
  final List<String> clubsCreated;
  final List<String> isPresidentOf;
  final List<String> isOrganizerOf;

  UserModel({
    required this.uid,
    this.institutionId = '',
    required this.email,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.userType,
    required this.gender,
    required this.dateOfBirth,
    required this.collegeName,
    this.profileImageUrl,
    this.about,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.profileCompleted = false,
    this.enrollmentNumber,
    this.enrollmentVisible = true,
    this.course,
    this.branch,
    this.sessionStartYear,
    this.sessionEndYear,
    this.currentYear,
    this.currentYearLabel,
    this.address,
    this.profession,
    this.department,
    this.collegeJoinedYear,
    this.specialization,
    this.clubsJoined = const [],
    this.clubsCreated = const [],
    this.isPresidentOf = const [],
    this.isOrganizerOf = const [],
  });

  // From Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      uid: doc.id,
      institutionId: data['institution_id'] ??
          InstitutionUtils.idFromCollegeName(data['college_name'] ?? ''),
      email: data['email'] ?? '',
      phoneNumber: data['phone_number'] ?? '',
      firstName: data['first_name'] ?? '',
      lastName: data['last_name'] ?? '',
      fullName: data['full_name'] ?? '',
      userType: data['user_type'] ?? '',
      gender: data['gender'] ?? '',
      dateOfBirth: _dateFrom(data['date_of_birth']),
      collegeName: data['college_name'] ?? '',
      profileImageUrl: data['profile_image_url'],
      about: data['about'],
      createdAt: _dateFrom(data['created_at']),
      updatedAt: _dateFrom(data['updated_at']),
      isActive: data['is_active'] ?? true,
      profileCompleted: data['profile_completed'] ?? false,
      enrollmentNumber: data['enrollment_number'],
      enrollmentVisible: data['enrollment_visible'] ?? true,
      course: data['course'],
      branch: data['branch'],
      sessionStartYear: data['session_start_year'],
      sessionEndYear: data['session_end_year'],
      currentYear: data['current_year'],
      currentYearLabel: data['current_year_label'],
      address: data['address'],
      profession: data['profession'],
      department: data['department'],
      collegeJoinedYear: data['college_joined_year'],
      specialization: data['specialization'] != null
          ? List<String>.from(data['specialization'])
          : null,
      clubsJoined: data['clubs_joined'] != null
          ? List<String>.from(data['clubs_joined'])
          : [],
      clubsCreated: data['clubs_created'] != null
          ? List<String>.from(data['clubs_created'])
          : [],
      isPresidentOf: data['is_president_of'] != null
          ? List<String>.from(data['is_president_of'])
          : [],
      isOrganizerOf: data['is_organizer_of'] != null
          ? List<String>.from(data['is_organizer_of'])
          : [],
    );
  }

  static DateTime _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    final data = {
      'email': email,
      'institution_id': institutionId.isNotEmpty
          ? institutionId
          : InstitutionUtils.idFromCollegeName(collegeName),
      'phone_number': phoneNumber,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'full_name_lower': SearchIndexUtils.normalize(fullName),
      'search_keywords': SearchIndexUtils.keywords([
        fullName,
        email,
        enrollmentNumber,
        course,
        branch,
        department,
      ]),
      'user_type': userType,
      'gender': gender,
      'date_of_birth': Timestamp.fromDate(dateOfBirth),
      'college_name': collegeName,
      'profile_image_url': profileImageUrl,
      'about': about,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'is_active': isActive,
      'profile_completed': profileCompleted,
      'clubs_joined': clubsJoined,
      'clubs_created': clubsCreated,
      'is_president_of': isPresidentOf,
      'is_organizer_of': isOrganizerOf,
    };

    // Add student specific fields
    if (userType == 'student') {
      data['enrollment_number'] = enrollmentNumber;
      data['enrollment_visible'] = enrollmentVisible;
      data['course'] = course;
      data['branch'] = branch;
      data['session_start_year'] = sessionStartYear;
      data['session_end_year'] = sessionEndYear;
      data['current_year'] = currentYear;
      data['current_year_label'] = currentYearLabel;
      data['address'] = address;
    }

    // Add faculty specific fields
    if (userType == 'faculty') {
      data['profession'] = profession;
      data['department'] = department;
      data['college_joined_year'] = collegeJoinedYear;
      data['specialization'] = specialization;
    }

    return data;
  }

  // Calculate current year label
  static String calculateYearLabel(int sessionStartYear, int sessionEndYear) {
    final currentYear = DateTime.now().year;
    final yearNumber = (currentYear - sessionStartYear) + 1;
    final maxYear = sessionEndYear - sessionStartYear + 1;

    if (yearNumber > maxYear) {
      return 'Alumni';
    }

    String suffix;
    switch (yearNumber) {
      case 1:
        suffix = 'st';
        break;
      case 2:
        suffix = 'nd';
        break;
      case 3:
        suffix = 'rd';
        break;
      default:
        suffix = 'th';
    }

    return '$yearNumber$suffix Year';
  }
}
