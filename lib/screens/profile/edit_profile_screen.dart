import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';
import '../../utils/validators.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _aboutController;
  late bool _enrollmentVisible;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _aboutController = TextEditingController(text: widget.user.about);
    _enrollmentVisible = widget.user.enrollmentVisible ?? true;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'full_name': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'about': _aboutController.text.trim(),
        'enrollment_visible': _enrollmentVisible,
      };

      await _firestoreService.updateUserProfile(
        uid: widget.user.uid,
        updates: updates,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GlassCard(
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _aboutController,
                      label: 'About',
                      hint: 'Tell us something about yourself',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (widget.user.userType == 'student')
                GlassCard(
                  child: SwitchListTile(
                    title: const Text('Show Enrollment Number'),
                    subtitle: const Text('Control who can see your enrollment ID'),
                    value: _enrollmentVisible,
                    onChanged: (val) => setState(() => _enrollmentVisible = val),
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Save Changes',
                onPressed: _updateProfile,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
