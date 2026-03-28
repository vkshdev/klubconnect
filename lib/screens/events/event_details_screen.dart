import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';


class EventDetailsScreen extends StatefulWidget {
  final String eventId;
  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _eventService = EventService();
  String? _currentRSVP;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    return StreamBuilder<EventModel>(
      stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots().map((doc) => EventModel.fromFirestore(doc)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: Text('Event not found.')));
        }

        final event = snapshot.data!;

        return Scaffold(
          appBar: AppBar(title: Text(event.title)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.bannerUrl != null && event.bannerUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      event.bannerUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.calendar_today, 'Date', '${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year}'),
                      const Divider(),
                      _buildInfoRow(Icons.access_time, 'Time', event.eventTime),
                      const Divider(),
                      _buildInfoRow(Icons.location_on, 'Location', event.location),
                      const Divider(),
                      _buildInfoRow(Icons.groups, 'Participants', '${event.currentParticipants} / ${event.maxParticipants}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'About Event',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(event.description),
                const SizedBox(height: 32),
                if (userId != null)
                  StreamBuilder<EventRSVP?>(
                    stream: _eventService.getUserRSVP(event.eventId, userId),
                    builder: (context, rsvpSnapshot) {
                      final userRSVP = rsvpSnapshot.data?.response;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Are you going?',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _RSVPButton(
                                  label: 'Yes',
                                  icon: Icons.check,
                                  color: Colors.green,
                                  isSelected: userRSVP == 'attending',
                                  onTap: () => _handleRSVP(event, 'attending', userRSVP),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RSVPButton(
                                  label: 'Interested',
                                  icon: Icons.star,
                                  color: Colors.orange,
                                  isSelected: userRSVP == 'interested',
                                  onTap: () => _handleRSVP(event, 'interested', userRSVP),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _RSVPButton(
                                  label: 'No',
                                  icon: Icons.close,
                                  color: Colors.red,
                                  isSelected: userRSVP == 'not_going',
                                  onTap: () => _handleRSVP(event, 'not_going', userRSVP),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _handleRSVP(EventModel event, String response, String? previousResponse) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser == null) return;

    try {
      await _eventService.updateRSVP(
        eventId: event.eventId,
        userId: authService.currentUser!.uid,
        userName: authService.currentUser!.displayName ?? 'User',
        response: response,
        previousResponse: previousResponse,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _RSVPButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _RSVPButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

