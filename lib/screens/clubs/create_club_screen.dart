import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/club_model.dart';
import '../../services/auth_service.dart';
import '../../services/club_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';
import '../../utils/validators.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clubService = ClubService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _bannerUrlController = TextEditingController();
  final _presidentIdController = TextEditingController();
  final _presidentNameController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestoreService = FirestoreService();
      final faculty = await firestoreService.getUserById(authService.currentUser!.uid);

      if (faculty == null) throw 'Faculty user not found';

      final clubId = const Uuid().v4();
      final slug = _nameController.text.toLowerCase().replaceAll(' ', '-');

      final newClub = ClubModel(
        clubId: clubId,
        name: _nameController.text.trim(),
        slug: slug,
        description: _descriptionController.text.trim(),
        logoUrl: _logoUrlController.text.trim(),
        bannerUrl: _bannerUrlController.text.trim(),
        category: _categoryController.text.trim(),
        colorCode: '#6200EE', // Default primary color
        collegeName: faculty.collegeName,
        clubMasterId: faculty.uid,
        clubMasterName: faculty.fullName,
        presidentId: _presidentIdController.text.trim(),
        presidentName: _presidentNameController.text.trim(),
        members: [_presidentIdController.text.trim()],
        totalMembers: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _clubService.createClub(newClub);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club created successfully!')),
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
      appBar: AppBar(title: const Text('Create New Club')),
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
                      controller: _nameController,
                      label: 'Club Name',
                      hint: 'Enter club name',
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Enter club description',
                      maxLines: 3,
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _categoryController,
                      label: 'Category',
                      hint: 'e.g. Technical, Cultural, Sports',
                      validator: Validators.validateRequired,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _logoUrlController,
                      label: 'Logo URL',
                      hint: 'Enter image URL for logo',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _bannerUrlController,
                      label: 'Banner URL',
                      hint: 'Enter image URL for banner',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    const Text('President Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _presidentIdController,
                      label: 'President User ID',
                      hint: 'Enter Student UID',
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _presidentNameController,
                      label: 'President Name',
                      hint: 'Enter Student Full Name',
                      validator: Validators.validateRequired,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Create Club',
                onPressed: _createClub,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
