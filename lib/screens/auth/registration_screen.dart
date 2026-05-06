import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../utils/constants.dart';
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileSetupScreen(),
          ),
        );
      }
    } else {
      Fluttertoast.showToast(msg: result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isStudent ? 'Student Registration' : 'Faculty Registration',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.8),
              Theme.of(context).primaryColor.withOpacity(0.4),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Progress Indicator
                LinearProgressIndicator(
                  value: (_currentPage + 1) / (isStudent ? 3 : 2),
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),

                // Page View
                Expanded(
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

                // Navigation Buttons
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: CustomOutlineButton(
                            text: 'Back',
                            onPressed: _previousPage,
                            height: 50,
                            textColor: Colors.white,
                            borderColor: Colors.white,
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 16),
                      Expanded(
                        flex: _currentPage > 0 ? 1 : 2,
                        child: CustomButton(
                          text: _currentPage == (isStudent ? 2 : 1) ? 'Register' : 'Next',
                          onPressed: _nextPage,
                          isLoading: _isLoading,
                          height: 50,
                          backgroundColor: Colors.white,
                          textColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
                      Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDOB != null
                            ? '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}'
                            : 'Select Date of Birth',
                        style: TextStyle(
                          color: _selectedDOB != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
                '⚠️ Must match your student ID card exactly',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
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
                        Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          _sessionStartYear != null
                              ? 'Start Year: $_sessionStartYear'
                              : 'Select Session Start Year',
                          style: TextStyle(
                            color: _sessionStartYear != null
                                ? Colors.black87
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_sessionEndYear != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Session End Year: $_sessionEndYear (Auto-calculated)',
                        style: TextStyle(
                          color: Colors.blue.shade700,
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
                        Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 12),
                        Text(
                          _collegeJoinedYear != null
                              ? 'Joined: $_collegeJoinedYear'
                              : 'Year Joined as Faculty',
                          style: TextStyle(
                            color: _collegeJoinedYear != null
                                ? Colors.black87
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
