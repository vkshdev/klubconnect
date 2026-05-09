import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import 'profile_setup_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String userType; // 'student' or 'faculty'

  const RegistrationScreen({
    super.key,
    required this.userType,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Controllers - Common Fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _collegeNameController = TextEditingController();

  // Date of Birth
  DateTime? _selectedDOB;
  String? _selectedGender;

  // Student Specific
  final _enrollmentController = TextEditingController();
  String? _selectedCourse;
  String? _selectedBranch;
  int? _sessionStartYear;
  int? _sessionEndYear;
  final _addressController = TextEditingController();

  // Faculty Specific
  String? _selectedProfession;
  String? _selectedDepartment;
  int? _collegeJoinedYear;

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _collegeNameController.dispose();
    _enrollmentController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get isStudent => widget.userType == AppConstants.userTypeStudent;
  bool get _isFinalPage => _currentPage == (isStudent ? 2 : 1);

  String get _primaryButtonText {
    if (!_isFinalPage) return 'Continue';
    return isStudent ? 'Create Student Account' : 'Create Faculty Account';
  }

  String get _roleTitle => isStudent ? 'Student onboarding' : 'Faculty onboarding';
  String get _roleSubtitle => isStudent
      ? 'Create your college profile, join clubs, and discover events from your college.'
      : 'Create your mentor profile, manage clubs, and guide student-led activities.';

  void _nextPage() {
    if (_formKey.currentState!.validate()) {
      if (_currentPage < (isStudent ? 2 : 1)) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _submitRegistration();
      }
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
    );
    if (picked != null) {
      setState(() {
        _selectedDOB = picked;
      });
    }
  }

  Future<void> _selectYear(BuildContext context, bool isStartYear) async {
    final currentYear = DateTime.now().year;
    final years = List.generate(30, (index) => currentYear - index);

    await showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              isStartYear ? 'Select Start Year' : 'Select Joined Year',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: years.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(years[index].toString()),
                    onTap: () {
                      setState(() {
                        if (isStartYear) {
                          _sessionStartYear = years[index];
                          // Auto calculate end year based on course
                          if (_selectedCourse != null) {
                            _sessionEndYear = _calculateEndYear(
                              years[index],
                              _selectedCourse!,
                            );
                          }
                        } else {
                          _collegeJoinedYear = years[index];
                        }
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateEndYear(int startYear, String course) {
    switch (course) {
      case 'B.Tech':
        return startYear + 4;
      case 'BCA':
      case 'BBA':
        return startYear + 3;
      case 'M.Tech':
      case 'MCA':
      case 'MBA':
        return startYear + 2;
      default:
        return startYear + 4;
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validations
    if (_selectedDOB == null) {
      Fluttertoast.showToast(msg: 'Please select date of birth');
      return;
    }
    if (_selectedGender == null) {
      Fluttertoast.showToast(msg: 'Please select gender');
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);

    // Prepare user data
    final userData = {
      'email': _emailController.text.trim().toLowerCase(),
      'phone_number': '+91${_phoneController.text.trim()}',
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'full_name': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      'user_type': widget.userType,
      'gender': _selectedGender,
      'date_of_birth': _selectedDOB,
      'college_name': _collegeNameController.text.trim(),
    };

    // Add type-specific data
    if (isStudent) {
      userData.addAll({
        'enrollment_number': _enrollmentController.text.trim().toUpperCase(),
        'enrollment_visible': true,
        'course': _selectedCourse,
        'branch': _selectedBranch,
        'session_start_year': _sessionStartYear,
        'session_end_year': _sessionEndYear,
        'address': _addressController.text.trim(),
      });
    } else {
      userData.addAll({
        'profession': _selectedProfession,
        'department': _selectedDepartment,
        'college_joined_year': _collegeJoinedYear,
        'total_clubs_mastered': 0,
      });
    }

    // Register user
    final result = await authService.registerWithEmailPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      userData: userData,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      // Navigate directly to Profile Setup (Skipping OTP)
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const ProfileSetupScreen(),
          ),
          (route) => false,
        );
      }
    } else {
      String msg = result['message'] ?? 'Registration failed';
      if (msg.contains('channel-error')) {
        msg = 'Connection error. Please check your internet or Firebase setup.';
      }
      Fluttertoast.showToast(msg: msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          isStudent ? 'Student Registration' : 'Faculty Registration',
          style: const TextStyle(color: AppTheme.darkTextColor, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.darkTextColor),
      ),
      body: Stack(
        children: [
          const _RegistrationBackground(),
          SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRegistrationHeader(),
                        const SizedBox(height: 16),
                        _buildProgressIndicator(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: GlassCard(
                        borderRadius: 28,
                        padding: EdgeInsets.zero,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                          },
                          children: [
                            _buildPersonalInfoPage(),
                            _buildAcademicInfoPage(),
                            if (isStudent) _buildStudentDetailsPage(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationHeader() {
    return Row(
      children: [
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: (isStudent ? AppTheme.accentColor : AppTheme.primaryColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            isStudent ? Icons.school_rounded : Icons.workspace_premium_rounded,
            color: isStudent ? AppTheme.accentColor : AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _roleTitle,
                style: const TextStyle(
                  color: AppTheme.darkTextColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _roleSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.secondaryColor,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final total = isStudent ? 3 : 2;
    return GlassCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Step ${_currentPage + 1} of $total',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                _stepLabel,
                style: const TextStyle(
                  color: AppTheme.secondaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: (_currentPage + 1) / total,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                isStudent ? AppTheme.accentColor : AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _stepLabel {
    if (_currentPage == 0) return 'Personal';
    if (isStudent && _currentPage == 2) return 'Address';
    return isStudent ? 'Academic' : 'Professional';
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (_currentPage > 0)
              Expanded(
                child: CustomOutlineButton(
                  text: 'Back',
                  onPressed: _previousPage,
                  height: 50,
                  textColor: AppTheme.secondaryColor,
                  borderColor: AppTheme.borderColor,
                ),
              ),
            if (_currentPage > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentPage > 0 ? 1 : 2,
              child: CustomButton(
                text: _primaryButtonText,
                onPressed: _nextPage,
                isLoading: _isLoading,
                height: 50,
                icon: _isFinalPage ? Icons.verified_user_outlined : Icons.arrow_forward_rounded,
                backgroundColor: AppTheme.darkTextColor,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkTextColor,
                ),
          ),
          const SizedBox(height: 24),

          CustomTextField(
            label: 'First Name',
            hint: 'Enter your first name',
            controller: _firstNameController,
            validator: (value) => Validators.validateName(value, 'First name'),
            prefixIcon: Icons.person,
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: 'Last Name',
            hint: 'Enter your last name',
            controller: _lastNameController,
            validator: (value) => Validators.validateName(value, 'Last name'),
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: 'Email Address',
            hint: 'yourname@gmail.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.validateEmail,
            prefixIcon: Icons.email,
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: 'Phone Number',
            hint: '10-digit mobile number',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: Validators.validatePhone,
            prefixIcon: Icons.phone,
            maxLength: 10,
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: 'Password',
            hint: 'Minimum 8 characters',
            controller: _passwordController,
            obscureText: true,
            validator: Validators.validatePassword,
            prefixIcon: Icons.lock,
          ),
          const SizedBox(height: 16),

          CustomTextField(
            label: 'Confirm Password',
            hint: 'Re-enter password',
            controller: _confirmPasswordController,
            obscureText: true,
            validator: (value) => Validators.validateConfirmPassword(
              value,
              _passwordController.text,
            ),
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 16),

          // Date of Birth
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDOB != null
                            ? '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}'
                            : 'Select Date of Birth',
                        style: TextStyle(
                          color: _selectedDOB != null
                              ? AppTheme.darkTextColor
                              : AppTheme.lightTextColor,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.lightTextColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gender Selection
          CustomDropdown(
            label: 'Gender',
            value: _selectedGender,
            items: AppConstants.genderOptions,
            onChanged: (value) {
              setState(() => _selectedGender = value);
            },
            hint: 'Select gender',
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isStudent ? 'Academic Information' : 'Professional Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkTextColor,
                ),
          ),
          const SizedBox(height: 24),

          if (isStudent) ...[
            CustomTextField(
              label: 'Enrollment Number',
              hint: 'Enter enrollment number',
              controller: _enrollmentController,
              validator: Validators.validateEnrollment,
              prefixIcon: Icons.badge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Must match your student ID card exactly',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),

            CustomDropdown(
              label: 'Course',
              value: _selectedCourse,
              items: AppConstants.courses,
              onChanged: (value) {
                setState(() {
                  _selectedCourse = value;
                  _selectedBranch = null; // Reset branch
                  // Auto calculate end year if start year is selected
                  if (_sessionStartYear != null && value != null) {
                    _sessionEndYear = _calculateEndYear(_sessionStartYear!, value);
                  }
                });
              },
              hint: 'Select course',
            ),
            const SizedBox(height: 16),

            if (_selectedCourse != null)
              CustomDropdown(
                label: 'Branch/Specialization',
                value: _selectedBranch,
                items: AppConstants.branches[_selectedCourse] ?? ['General'],
                onChanged: (value) {
                  setState(() => _selectedBranch = value);
                },
                hint: 'Select branch',
              ),
            if (_selectedCourse != null) const SizedBox(height: 16),

            InkWell(
              onTap: () => _selectYear(context, true),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          _sessionStartYear != null
                              ? 'Start Year: $_sessionStartYear'
                              : 'Select Session Start Year',
                          style: TextStyle(
                            color: _sessionStartYear != null
                                ? AppTheme.darkTextColor
                                : AppTheme.lightTextColor,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.lightTextColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_sessionEndYear != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Session End Year: $_sessionEndYear (Auto-calculated)',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            CustomDropdown(
              label: 'Designation',
              value: _selectedProfession,
              items: AppConstants.professions,
              onChanged: (value) {
                setState(() => _selectedProfession = value);
              },
              hint: 'Select designation',
            ),
            const SizedBox(height: 16),

            CustomDropdown(
              label: 'Department',
              value: _selectedDepartment,
              items: AppConstants.departments,
              onChanged: (value) {
                setState(() => _selectedDepartment = value);
              },
              hint: 'Select department',
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _selectYear(context, false),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          _collegeJoinedYear != null
                              ? 'Joined: $_collegeJoinedYear'
                              : 'Year Joined as Faculty',
                          style: TextStyle(
                            color: _collegeJoinedYear != null
                                ? AppTheme.darkTextColor
                                : AppTheme.lightTextColor,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.lightTextColor),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          CustomTextField(
            label: 'College Name',
            hint: 'Enter college name',
            controller: _collegeNameController,
            validator: (value) => Validators.validateRequired(value, 'College name'),
            prefixIcon: Icons.school,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkTextColor,
                ),
          ),
          const SizedBox(height: 24),

          CustomTextField(
            label: 'Residential Address',
            hint: 'Enter your complete address',
            controller: _addressController,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Address is required';
              }
              if (value.length < 10) {
                return 'Please provide a valid address';
              }
              return null;
            },
            prefixIcon: Icons.home,
          ),
        ],
      ),
    );
  }
}

class _RegistrationBackground extends StatelessWidget {
  const _RegistrationBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEFF6FF),
            Color(0xFFF8FAFC),
            Color(0xFFEFFDF9),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -85,
            right: -75,
            child: _SoftOrb(
              color: AppTheme.primaryColor.withOpacity(0.15),
              size: 220,
            ),
          ),
          Positioned(
            bottom: 120,
            left: -115,
            child: _SoftOrb(
              color: AppTheme.accentColor.withOpacity(0.12),
              size: 230,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _SoftOrb({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 90,
            spreadRadius: 24,
          ),
        ],
      ),
    );
  }
}
