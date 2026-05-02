import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/club_model.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';

class CreateEventScreen extends StatefulWidget {
  final ClubModel club;
  const CreateEventScreen({super.key, required this.club});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventService = EventService();
  final _firestoreService = FirestoreService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _timeController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '100');

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _venueType = 'offline';
  File? _bannerImage;
  UserModel? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _timeController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;
    if (uid == null) return;
    final user = await _firestoreService.getUserById(uid);
    if (mounted) setState(() => _currentUser = user);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      _timeController.text = picked.format(context);
    }
  }

  Future<void> _pickBanner() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 900,
    );
    if (image != null) setState(() => _bannerImage = File(image.path));
  }

  String? get _creatorRole {
    final uid = _currentUser?.uid;
    if (uid == null) return null;
    if (widget.club.clubMasterId == uid) return 'Club Master';
    if (widget.club.presidentId == uid) return 'President';
    if (widget.club.organizers.contains(uid)) return 'Organizer';
    return null;
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentUser == null || _creatorRole == null) {
      Fluttertoast.showToast(msg: 'You do not have permission to create events for this club.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final eventId = const Uuid().v4();
      final status = _creatorRole == 'Club Master' ? EventStatus.approved : EventStatus.pending;
      final event = EventModel(
        eventId: eventId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        clubId: widget.club.clubId,
        clubName: widget.club.name,
        clubColor: widget.club.colorCode,
        collegeName: widget.club.collegeName,
        createdById: _currentUser!.uid,
        createdByName: _currentUser!.fullName,
        createdByRole: _creatorRole!,
        eventDate: _selectedDate,
        eventTime: _timeController.text.trim(),
        location: _locationController.text.trim(),
        venueType: _venueType,
        bannerUrl: null,
        maxParticipants: int.tryParse(_maxParticipantsController.text.trim()) ?? 100,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _eventService.createEvent(event);

      if (_bannerImage != null) {
        final bannerUrl = await _eventService.uploadEventBanner(
          eventId: eventId,
          image: _bannerImage!,
        );
        await _eventService.updateEvent(eventId, {'banner_url': bannerUrl});
      }

      if (mounted) {
        Fluttertoast.showToast(
          msg: status == EventStatus.approved
              ? 'Event published.'
              : 'Event submitted for club master approval.',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Could not create event: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final creatorRole = _creatorRole;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (creatorRole == null)
                      const GlassCard(
                        child: Text('Only the club master, president, or organizers can create events.'),
                      )
                    else ...[
                      GlassCard(
                        child: Column(
                          children: [
                            CustomTextField(
                              controller: _titleController,
                              label: 'Event Title',
                              hint: 'Design Sprint Workshop',
                              validator: (value) => Validators.validateRequired(value, 'Event title'),
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _descriptionController,
                              label: 'Description',
                              hint: 'What should attendees expect?',
                              maxLines: 4,
                              validator: (value) => Validators.validateRequired(value, 'Description'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Event Date'),
                              subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectDate,
                            ),
                            const Divider(),
                            CustomTextField(
                              controller: _timeController,
                              label: 'Event Time',
                              hint: 'Choose a time',
                              validator: (value) => Validators.validateRequired(value, 'Event time'),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.schedule),
                                onPressed: _selectTime,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _venueType,
                              decoration: const InputDecoration(labelText: 'Venue Type'),
                              items: const [
                                DropdownMenuItem(value: 'offline', child: Text('Offline')),
                                DropdownMenuItem(value: 'online', child: Text('Online')),
                              ],
                              onChanged: (value) => setState(() => _venueType = value ?? 'offline'),
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _locationController,
                              label: _venueType == 'online' ? 'Meeting Link' : 'Location',
                              hint: _venueType == 'online' ? 'Paste meeting link' : 'Auditorium, Block A',
                              validator: (value) => Validators.validateRequired(value, 'Location'),
                            ),
                            const SizedBox(height: 16),
                            CustomTextField(
                              controller: _maxParticipantsController,
                              label: 'Max Participants',
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (value) => Validators.validateRequired(value, 'Max participants'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 56,
                              height: 56,
                              color: Colors.white.withOpacity(0.65),
                              child: _bannerImage == null
                                  ? const Icon(Icons.image_outlined)
                                  : Image.file(_bannerImage!, fit: BoxFit.cover),
                            ),
                          ),
                          title: const Text('Event Banner', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(_bannerImage == null ? 'Optional wide image' : 'Banner selected'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _pickBanner,
                        ),
                      ),
                      const SizedBox(height: 28),
                      CustomButton(
                        text: creatorRole == 'Club Master' ? 'Publish Event' : 'Submit for Approval',
                        icon: Icons.event_available_outlined,
                        onPressed: _createEvent,
                        isLoading: _isLoading,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
