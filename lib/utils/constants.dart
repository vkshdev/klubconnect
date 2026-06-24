class AppConstants {
  // App Info
  static const String appName = 'KlubConnect';
  static const String appTagline =
      'Connect Through Clubs - Your College, Your Community';

  // User Types
  static const String userTypeStudent = 'student';
  static const String userTypeFaculty = 'faculty';

  // Roles
  static const String rolePresident = 'president';
  static const String roleOrganizer = 'organizer';
  static const String roleMember = 'member';
  static const String roleClubMaster = 'club_master';

  // Collections
  static const String usersCollection = 'users';
  static const String clubsCollection = 'clubs';
  static const String eventsCollection = 'events';
  static const String notificationsCollection = 'notifications';

  // Validation
  static const int minPasswordLength = 8;
  static const int minAboutLength = 20;
  static const int maxAboutLength = 500;

  // Courses
  static const List<String> courses = [
    'B.Tech',
    'M.Tech',
    'BCA',
    'MCA',
    'MBA',
    'BBA',
    'Other',
  ];

  // Branches by Course
  static const Map<String, List<String>> branches = {
    'B.Tech': [
      'CSE',
      'IT',
      'ECE',
      'Mechanical',
      'Civil',
      'EEE',
      'AIML',
      'Cyber Security',
      'AIDS'
    ],
    'M.Tech': ['CSE', 'IT', 'ECE', 'Mechanical', 'Civil', 'Other'],
    'BCA': ['Computer Applications'],
    'MCA': ['Computer Applications'],
    'MBA': ['Finance', 'Marketing', 'HR', 'Operations', 'Other'],
    'BBA': ['General', 'Finance', 'Marketing', 'Other'],
  };

  // Faculty Professions
  static const List<String> professions = [
    'Principal',
    'Vice Principal',
    'Dean',
    'HOD',
    'Professor',
    'Associate Professor',
    'Assistant Professor',
    'Lecturer',
    'Faculty Staff',
  ];

  // Departments
  static const List<String> departments = [
    'Computer Science',
    'Information Technology',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
    'Management',
    'Commerce',
    'Other',
  ];

  // Gender Options
  static const List<String> genderOptions = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];
}
