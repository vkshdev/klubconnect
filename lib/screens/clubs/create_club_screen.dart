import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/club_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/club_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clubService = ClubService();
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  UserModel? _faculty;
  String? _category;
  String? _presidentId;
  String? _presidentName;
  String _colorCode = '#2563EB';
  File? _logoImage;
  File? _bannerImage;
  bool _isLoading = false;

  static const _categories = [
    'Technical',
    'Cultural',
    'Sports',
    'Entrepreneurship',
    'Literary',
    'Social Impact',
    'Arts',
    'Other',
  ];

  static const _clubColors = {
    'Blue': '#2563EB',
    'Teal': '#0F766E',
    'Graphite': '#334155',
    'Green': '#16A34A',
    'Rose': '#E11D48',
  };

  @override
  void initState() {
    super.initState();
    _loadFaculty();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFaculty() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;
    if (uid == null) return;
    final user = await _firestoreService.getUserById(uid);
    if (mounted) setState(() => _faculty = user);
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: isLogo ? 720 : 1600,
      maxHeight: isLogo ? 720 : 900,
    );
    if (image == null) return;
    setState(() {
      if (isLogo) {
        _logoImage = File(image.path);
      } else {
        _bannerImage = File(image.path);
      }
    });
  }

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;
    if (_faculty == null) {
      Fluttertoast.showToast(msg: 'Faculty profile not loaded yet.');
      return;
    }
    if (_faculty!.userType != AppConstants.userTypeFaculty) {
      Fluttertoast.showToast(msg: 'Only faculty can create clubs.');
      return;
    }
    if (_presidentId == null || _presidentName == null) {
      Fluttertoast.showToast(msg: 'Please select a student president.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final clubId = const Uuid().v4();
      final slug = _nameController.text
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');

      final club = ClubModel(
        clubId: clubId,
        name: _nameController.text.trim(),
        slug: slug,
        description: _descriptionController.text.trim(),
        logoUrl: '',
        bannerUrl: '',
        category: _category!,
        colorCode: _colorCode,
        collegeName: _faculty!.collegeName,
        clubMasterId: _faculty!.uid,
        clubMasterName: _faculty!.fullName,
        presidentId: _presidentId!,
        presidentName: _presidentName!,
        members: [_presidentId!],
        totalMembers: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _clubService.createClub(club);

      final imageUpdates = <String, dynamic>{};
      if (_logoImage != null) {
        imageUpdates['logo_url'] = await _clubService.uploadClubImage(
          clubId: clubId,
          image: _logoImage!,
          fileName: 'logo.jpg',
        );
      }
      if (_bannerImage != null) {
        imageUpdates['banner_url'] = await _clubService.uploadClubImage(
          clubId: clubId,
          image: _bannerImage!,
          fileName: 'banner.jpg',
        );
      }
      if (imageUpdates.isNotEmpty) {
        await _clubService.updateClub(clubId, imageUpdates);
      }

      if (mounted) {
        Fluttertoast.showToast(msg: 'Club created successfully.');
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Could not create club: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_faculty == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Club')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      label: 'Club Name',
                      hint: 'Robotics Society',
                      validator: (value) => Validators.validateRequired(value, 'Club name'),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'What does this club do?',
                      maxLines: 4,
                      validator: (value) => Validators.validateRequired(value, 'Description'),
                    ),
                    const SizedBox(height: 16),
                    CustomDropdown(
                      label: 'Category',
                      value: _category,
                      items: _categories,
                      hint: 'Select category',
                      validator: (value) => Validators.validateRequired(value, 'Category'),
                      onChanged: (value) => setState(() => _category = value),
                    ),
                    const SizedBox(height: 16),
                    _buildColorPicker(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    _ImagePickerTile(
                      title: 'Club Logo',
                      subtitle: _logoImage == null ? 'Optional square image' : 'Logo selected',
                      image: _logoImage,
                      icon: Icons.badge_outlined,
                      onTap: () => _pickImage(isLogo: true),
                    ),
                    const Divider(),
                    _ImagePickerTile(
                      title: 'Club Banner',
                      subtitle: _bannerImage == null ? 'Optional wide header image' : 'Banner selected',
                      image: _bannerImage,
                      icon: Icons.image_outlined,
                      onTap: () => _pickImage(isLogo: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: StreamBuilder<List<UserModel>>(
                  stream: _clubService.streamCollegeStudents(_faculty!.collegeName),
                  builder: (context, snapshot) {
                    final students = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _presidentId,
                      decoration: const InputDecoration(
                        labelText: 'President',
                        hintText: 'Select a student president',
                      ),
                      items: students
                          .map(
                            (student) => DropdownMenuItem(
                              value: student.uid,
                              child: Text(student.fullName),
                            ),
                          )
                          .toList(),
                      validator: (value) => Validators.validateRequired(value, 'President'),
                      onChanged: (value) {
                        UserModel? selected;
                        for (final student in students) {
                          if (student.uid == value) {
                            selected = student;
                            break;
                          }
                        }
                        setState(() {
                          _presidentId = value;
                          _presidentName = selected?.fullName;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              CustomButton(
                text: 'Create Club',
                icon: Icons.add_circle_outline,
                onPressed: _createClub,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Club Accent',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: _clubColors.entries.map((entry) {
            final selected = _colorCode == entry.value;
            final color = Color(int.parse(entry.value.replaceAll('#', '0xFF')));
            return ChoiceChip(
              label: Text(entry.key),
              selected: selected,
              avatar: CircleAvatar(backgroundColor: color, radius: 8),
              onSelected: (_) => setState(() => _colorCode = entry.value),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final File? image;
  final IconData icon;
  final VoidCallback onTap;

  const _ImagePickerTile({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 54,
          height: 54,
          color: Colors.white.withOpacity(0.6),
          child: image == null
              ? Icon(icon, color: Theme.of(context).primaryColor)
              : Image.file(image!, fit: BoxFit.cover),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
