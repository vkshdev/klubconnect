class Validators {
  // Email Validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email';
    }

    return null;
  }

  // Phone Validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove spaces and special characters
    final cleanPhone = value.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanPhone.length < 10) {
      return 'Enter a valid phone number';
    }

    return null;
  }

  // Password Validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  // Name Validation
  static String? validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final trimmedValue = value.trim();
    if (trimmedValue.length < 2) {
      return '$fieldName must be at least 2 characters';
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmedValue)) {
      return '$fieldName can only contain letters';
    }

    return null;
  }

  // Required Field
  static String? validateRequired(String? value, [String fieldName = 'Field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Enrollment Number
  static String? validateEnrollment(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enrollment number is required';
    }

    final trimmedValue = value.trim();
    if (trimmedValue.length < 5) {
      return 'Enter a valid enrollment number';
    }

    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmedValue)) {
      return 'Enrollment number can only contain letters and numbers';
    }

    return null;
  }

  // About/Bio Validation
  static String? validateAbout(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'About section is required';
    }

    final trimmedValue = value.trim();
    if (trimmedValue.length < 10) {
      return 'Please write at least 10 characters';
    }

    if (trimmedValue.length > 500) {
      return 'Maximum 500 characters allowed';
    }

    return null;
  }

  // Confirm Password
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }
  
  // Sanitize input
  static String sanitize(String value) {
    return value.trim().replaceAll(RegExp(r'[<>]'), '');
  }
}