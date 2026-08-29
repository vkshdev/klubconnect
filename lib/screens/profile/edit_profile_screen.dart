import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/image_upload_service.dart';
import '../../utils/institution_utils.dart';
import '../../utils/theme.dart';
import '../../widgets/screen_background.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firestoreService = FirestoreService();
  final _imageUploadService = ImageUploadService();
  final _aboutController = TextEditingController();
  bool _isLoading = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _aboutController.text = widget.user.about ?? '';
  }

  @override
  void dispose() {
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      String? imageUrl = widget.user.profileImageUrl;
      if (_imageFile != null) {
        imageUrl = await _imageUploadService.uploadCompressedImage(
          image: _imageFile!,
          storagePath: 'profiles/${widget.user.uid}/avatar.jpg',
          ownerId: widget.user.uid,
          institutionId: widget.user.institutionId.isNotEmpty
              ? widget.user.institutionId
              : InstitutionUtils.idFromCollegeName(widget.user.collegeName),
          ownerType: 'profile',
          maxWidth: 1024,
          maxHeight: 1024,
        );
      }

      await _firestoreService.updateUserProfile(
        uid: widget.user.uid,
        updates: {
          'about': _aboutController.text.trim(),
          'profile_image_url': imageUrl,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign out',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Are you sure you want to sign out of KlubConnect?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              Provider.of<AuthService>(context, listen: false).signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isFaculty = user.userType == 'faculty';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          const ScreenBackground(),
          SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScreenHeader(
                          title: 'Profile & Settings',
                          subtitle: 'Account Hub',
                          actions: [
                            FilledButton.icon(
                              onPressed: _isLoading ? null : _updateProfile,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: _isLoading
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded, size: 18),
                              label: const Text(
                                'Save',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildAvatarHero(user, isFaculty),
                        const SizedBox(height: 18),
                        _buildInstitutionalDetails(user, isFaculty),
                        const SizedBox(height: 18),
                        _buildAboutCard(),
                        const SizedBox(height: 24),
                        _buildAccountActions(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarHero(UserModel user, bool isFaculty) {
    final roleBadgeColor =
        isFaculty ? AppTheme.accentColor : AppTheme.primaryColor;
    final roleLabel = isFaculty ? 'FACULTY MENTOR' : 'STUDENT';

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        roleBadgeColor.withValues(alpha: 0.8),
                        roleBadgeColor.withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white,
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (user.profileImageUrl != null
                            ? CachedNetworkImageProvider(user.profileImageUrl!)
                                as ImageProvider
                            : null),
                    child: (_imageFile == null && user.profileImageUrl == null)
                        ? Text(
                            user.firstName.isNotEmpty
                                ? user.firstName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: roleBadgeColor,
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkTextColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.fullName,
            style: const TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleBadgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              roleLabel,
              style: TextStyle(
                color: roleBadgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.collegeName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionalDetails(UserModel user, bool isFaculty) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Institutional Details',
            style: TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          _buildDetailRow(
            icon: Icons.alternate_email_rounded,
            label: 'Email',
            value: user.email,
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Not set',
          ),
          if (!isFaculty && (user.course ?? '').isNotEmpty) ...[
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.school_outlined,
              label: 'Program',
              value: '${user.course} (${user.branch ?? ''})',
            ),
          ],
          if (!isFaculty && (user.enrollmentNumber ?? '').isNotEmpty) ...[
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.badge_outlined,
              label: 'Enrollment No.',
              value: user.enrollmentNumber!,
            ),
          ],
          if (isFaculty && (user.department ?? '').isNotEmpty) ...[
            const Divider(height: 20, color: Color(0xFFF1F5F9)),
            _buildDetailRow(
              icon: Icons.domain_rounded,
              label: 'Department',
              value: user.department!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.lightTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.darkTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard() {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About Me',
            style: TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share your passions, interests, and club goals.',
            style: TextStyle(
              color: AppTheme.lightTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aboutController,
            maxLines: 4,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkTextColor,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Lead robotics builder, hackathon enthusiast...',
              hintStyle: const TextStyle(
                color: AppTheme.lightTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              fillColor: Colors.white.withValues(alpha: 0.7),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActions() {
    return GlassPanel(
      padding: const EdgeInsets.all(8),
      borderRadius: 18,
      child: ListTile(
        leading: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: AppTheme.errorColor,
            size: 20,
          ),
        ),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            color: AppTheme.errorColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.errorColor,
          size: 20,
        ),
        onTap: _confirmSignOut,
      ),
    );
  }
}
