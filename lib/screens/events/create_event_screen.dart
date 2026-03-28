import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/club_model.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/glass_card.dart';
import '../../utils/validators.dart';

class CreateEventScreen extends StatefulWidget {
  final ClubModel club;
  const CreateEventScreen({super.key, required this.club});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventService = EventService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _timeController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _bannerUrlController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String _venueType = 'offline';
  bool _isLoading = false;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final eventId = const Uuid().v4();
      final newEvent = EventModel(
        eventId: eventId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        clubId: widget.club.clubId,
        clubName: widget.club.name,
        clubColor: widget.club.colorCode,
        createdById: widget.club.clubMasterId, // Simplified for now
        createdByName: widget.club.clubMasterName,
        createdByRole: 'Club Master',
        eventDate: _selectedDate,
        eventTime: _timeController.text.trim(),
        location: _locationController.text.trim(),
        venueType: _venueType,
        bannerUrl: _bannerUrlController.text.trim(),
        maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 100,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _eventService.createEvent(newEvent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created and pending approval!')),
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
      appBar: AppBar(title: const Text('Create New Event')),
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
                      controller: _titleController,
                      label: 'Event Title',
                      hint: 'Enter event title',
                      validator: Validators.validateRequired,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'What is the event about?',
                      maxLines: 4,
                      validator: Validators.validateRequired,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Event Date'),
                      subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _selectDate,
                    ),
                    const Divider(),
                    CustomTextField(
                      controller: _timeController,
                      label: 'Event Time',
                      hint: 'e.g. 2:00 PM',
                      validator: Validators.validateRequired,
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
                      items: ['offline', 'online'].map((type) {
                        return DropdownMenuItem(value: type, child: Text(type.toUpperCase()));
                      }).toList(),
                      onChanged: (val) => setState(() => _venueType = val!),
                      decoration: const InputDecoration(labelText: 'Venue Type'),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _locationController,
                      label: 'Location / Link',
                      hint: 'Enter venue or online link',
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
                      controller: _maxParticipantsController,
                      label: 'Max Participants',
                      hint: 'Enter a number',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _bannerUrlController,
                      label: 'Banner Image URL',
                      hint: 'Enter URL for event banner',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              CustomButton(
                text: 'Propose Event',
                onPressed: _createEvent,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
