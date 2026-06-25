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
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';
import '../../utils/theme.dart';

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
            const SnackBar(content: Text('Profile updated successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Profile Settings'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateProfile,
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAvatarSection(),
            const SizedBox(height: 24),
            _buildProfileInfo(),
            const SizedBox(height: 24),
            _buildAboutSection(),
            const SizedBox(height: 32),
            _buildAccountActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.borderColor,
              backgroundImage: _imageFile != null
                  ? FileImage(_imageFile!)
                  : (widget.user.profileImageUrl != null
                      ? CachedNetworkImageProvider(widget.user.profileImageUrl!)
                          as ImageProvider
                      : null),
              child: (_imageFile == null && widget.user.profileImageUrl == null)
                  ? Text(widget.user.firstName[0],
                      style: const TextStyle(fontSize: 32))
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(widget.user.fullName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(widget.user.userType.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildInfoTile(Icons.email_outlined, 'Email', widget.user.email),
          const Divider(height: 1, indent: 56),
          _buildInfoTile(
              Icons.school_outlined, 'College', widget.user.collegeName),
          const Divider(height: 1, indent: 56),
          _buildInfoTile(
            Icons.phone_outlined,
            'Phone',
            widget.user.phoneNumber.isEmpty
                ? 'Not set'
                : widget.user.phoneNumber,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.secondaryColor, size: 22),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: AppTheme.secondaryColor)),
      subtitle: Text(value,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkTextColor)),
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('About Me',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        TextField(
          controller: _aboutController,
          maxLines: 4,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Share a little about yourself...',
            fillColor: Colors.white,
            filled: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderColor)),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountActions() {
    return Column(
      children: [
        CustomOutlineButton(
          text: 'Log Out',
          textColor: Colors.red,
          borderColor: Colors.red.withValues(alpha: 0.3),
          onPressed: () =>
              Provider.of<AuthService>(context, listen: false).signOut(),
        ),
      ],
    );
  }
}
