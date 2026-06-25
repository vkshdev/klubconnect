import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/cached_remote_image.dart';
import '../../widgets/glass_card.dart';

class EventDetailsScreen extends StatefulWidget {
  final String eventId;
  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _eventService = EventService();
  final _firestoreService = FirestoreService();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;
    if (uid == null) return;
    final user = await _firestoreService.getUserById(uid);
    if (mounted) setState(() => _currentUser = user);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EventModel?>(
      stream: _eventService.streamEvent(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final event = snapshot.data;
        if (event == null) {
          return const Scaffold(body: Center(child: Text('Event not found.')));
        }

        return Scaffold(
          appBar: AppBar(title: Text(event.title)),
          body: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if ((event.bannerUrl ?? '').isNotEmpty)
                  CachedRemoteImage(
                    imageUrl: event.bannerUrl!,
                    height: 210,
                    width: double.infinity,
                    borderRadius: BorderRadius.circular(18),
                  ),
                const SizedBox(height: 18),
                GlassCard(
                  child: Column(
                    children: [
                      _buildInfoRow(
                          Icons.apartment_outlined, 'Club', event.clubName),
                      const Divider(),
                      _buildInfoRow(Icons.calendar_today, 'Date',
                          '${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year}'),
                      const Divider(),
                      _buildInfoRow(Icons.access_time, 'Time', event.eventTime),
                      const Divider(),
                      _buildInfoRow(
                        event.venueType == 'online'
                            ? Icons.link
                            : Icons.location_on_outlined,
                        event.venueType == 'online' ? 'Link' : 'Location',
                        event.location,
                      ),
                      const Divider(),
                      _buildInfoRow(Icons.groups_outlined, 'Attending',
                          '${event.currentParticipants} / ${event.maxParticipants}'),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'About Event',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(event.description),
                const SizedBox(height: 22),
                _buildRsvpSection(event),
                const SizedBox(height: 22),
                _buildParticipants(event.eventId),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRsvpSection(EventModel event) {
    if (_currentUser == null || event.status != EventStatus.approved) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<EventRSVP?>(
      stream: _eventService.getUserRSVP(event.eventId, _currentUser!.uid),
      builder: (context, snapshot) {
        final userRSVP = snapshot.data?.response;
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your RSVP',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _RSVPButton(
                      label: 'Going',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      isSelected: userRSVP == 'attending',
                      onTap: () => _handleRSVP(event, 'attending', userRSVP),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RSVPButton(
                      label: 'Interested',
                      icon: Icons.star_border,
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
              const SizedBox(height: 12),
              Text(
                '${event.interestedCount} interested - ${event.notGoingCount} not going',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParticipants(String eventId) {
    return StreamBuilder<List<EventRSVP>>(
      stream: _eventService.getEventRsvps(eventId),
      builder: (context, snapshot) {
        final rsvps = (snapshot.data ?? [])
            .where((rsvp) => rsvp.response == 'attending')
            .toList();
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Participants',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (rsvps.isEmpty)
                Text('No confirmed participants yet.',
                    style: TextStyle(color: Colors.grey.shade700))
              else
                ...rsvps.take(20).map(
                      (rsvp) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                            child: Icon(Icons.person_outline)),
                        title: Text(rsvp.userName),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRSVP(
      EventModel event, String response, String? previousResponse) async {
    if (_currentUser == null) return;

    try {
      await _eventService.updateRSVP(
        event: event,
        userId: _currentUser!.uid,
        userName: _currentUser!.fullName,
        response: response,
        previousResponse: previousResponse,
      );
      Fluttertoast.showToast(msg: 'RSVP updated.');
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString().replaceFirst('Exception: ', ''));
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
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.55)),
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
