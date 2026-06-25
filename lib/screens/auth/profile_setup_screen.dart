import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/image_upload_service.dart';
import '../../utils/institution_utils.dart';
import '../../utils/theme.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';
import '../home/home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aboutController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _imageUploadService = ImageUploadService();

  File? _imageFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _imageFile = File(image.path));
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to pick image: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Choose Profile Picture',
                style: TextStyle(
                  color: AppTheme.darkTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              _ImageSourceTile(
                icon: Icons.camera_alt_rounded,
                title: 'Take Photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              _ImageSourceTile(
                icon: Icons.photo_library_rounded,
                title: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _uploadImage(String uid) async {
    if (_imageFile == null) return null;

    try {
      final user = await _firestoreService.getUserById(uid);
      final institutionId = user?.institutionId.isNotEmpty == true
          ? user!.institutionId
          : InstitutionUtils.idFromCollegeName(user?.collegeName ?? '');

      return _imageUploadService.uploadCompressedImage(
        image: _imageFile!,
        storagePath: 'profiles/$uid/profile.jpg',
        ownerId: uid,
        institutionId: institutionId,
        ownerType: 'profile',
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to upload image: $e');
      return null;
    }
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null) {
      Fluttertoast.showToast(msg: 'Please select a profile picture');
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;

    if (uid == null) {
      Fluttertoast.showToast(msg: 'User not found');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final imageUrl = await _uploadImage(uid);
      await _firestoreService.updateUserProfile(
        uid: uid,
        updates: {
          'about': _aboutController.text.trim(),
          'profile_image_url': imageUrl,
        },
      );
      await _firestoreService.markProfileComplete(uid);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Setup failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _skipSetup() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          const _ProfileSetupBackground(),
          SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Complete your profile',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: 34,
                              height: 1.04,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Add a photo and a short intro so clubs and classmates know who you are.',
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Center(child: _buildAvatarPicker()),
                          const SizedBox(height: 26),
                          GlassCard(
                            borderRadius: 28,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'About You',
                                  style: TextStyle(
                                    color: AppTheme.darkTextColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                CustomTextField(
                                  label: 'Profile Bio',
                                  hint:
                                      'Write about your interests, skills, or what you would like others to know...',
                                  controller: _aboutController,
                                  maxLines: 6,
                                  maxLength: 500,
                                  validator: Validators.validateAbout,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${_aboutController.text.length}/500 characters',
                                  style: const TextStyle(
                                    color: AppTheme.lightTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          GlassCard(
                            borderRadius: 22,
                            padding: const EdgeInsets.all(16),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: AppTheme.primaryColor),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This information will be visible on your profile.',
                                    style: TextStyle(
                                      color: AppTheme.secondaryColor,
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildAvatarPicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.86),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9), width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  blurRadius: 34,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: _imageFile != null
                ? ClipOval(
                    child: Image.file(_imageFile!, fit: BoxFit.cover),
                  )
                : const Icon(
                    Icons.add_a_photo_rounded,
                    size: 46,
                    color: AppTheme.primaryColor,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _showImageSourceDialog,
          icon: const Icon(Icons.camera_alt_rounded),
          label: const Text(
            'Add profile picture',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CustomButton(
              text: 'Complete Setup',
              onPressed: _completeSetup,
              isLoading: _isLoading,
              height: 52,
              icon: Icons.check_circle_outline_rounded,
              backgroundColor: AppTheme.darkTextColor,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : _skipSetup,
              child: const Text(
                'Skip for now',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ImageSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.darkTextColor,
          fontWeight: FontWeight.w800,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ProfileSetupBackground extends StatelessWidget {
  const _ProfileSetupBackground();

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
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                size: 220),
          ),
          Positioned(
            bottom: 80,
            left: -115,
            child: _SoftOrb(
                color: AppTheme.accentColor.withValues(alpha: 0.12), size: 230),
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
          BoxShadow(color: color, blurRadius: 90, spreadRadius: 24),
        ],
      ),
    );
  }
}
