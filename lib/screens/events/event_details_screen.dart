import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import '../../widgets/cached_remote_image.dart';
import '../../widgets/screen_background.dart';

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

  Color _safeColor(String value) {
    try {
      return Color(int.parse(value.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EventModel?>(
      stream: _eventService.streamEvent(widget.eventId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }
        final event = snapshot.data;
        if (event == null) {
          return const Scaffold(
            body: Center(child: Text('Event not found.')),
          );
        }

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
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ScreenHeader(
                              title: event.title,
                              subtitle: event.clubName,
                            ),
                            const SizedBox(height: 18),
                            if ((event.bannerUrl ?? '').isNotEmpty) ...[
                              CachedRemoteImage(
                                imageUrl: event.bannerUrl!,
                                height: 200,
                                width: double.infinity,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildEventMetaCard(event),
                            const SizedBox(height: 16),
                            _buildRsvpHub(event),
                            const SizedBox(height: 16),
                            _buildAboutCard(event),
                            const SizedBox(height: 16),
                            _buildParticipantsList(event.eventId),
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
      },
    );
  }

  Widget _buildEventMetaCard(EventModel event) {
    final color = _safeColor(event.clubColor);
    final isOnline = event.venueType == 'online';

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  event.clubName,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                      : AppTheme.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOnline
                          ? Icons.videocam_rounded
                          : Icons.location_on_rounded,
                      size: 13,
                      color: isOnline
                          ? const Color(0xFF8B5CF6)
                          : AppTheme.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Online' : 'In-Person',
                      style: TextStyle(
                        color: isOnline
                            ? const Color(0xFF8B5CF6)
                            : AppTheme.accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildMetaRow(
            icon: Icons.calendar_month_rounded,
            label: 'Date',
            value:
                '${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year}',
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildMetaRow(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: event.eventTime,
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildMetaRow(
            icon: isOnline ? Icons.link_rounded : Icons.place_rounded,
            label: isOnline ? 'Access Link' : 'Venue',
            value: event.location,
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildMetaRow(
            icon: Icons.groups_rounded,
            label: 'Capacity',
            value:
                '${event.currentParticipants} attending (max ${event.maxParticipants})',
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 17),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.lightTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRsvpHub(EventModel event) {
    if (_currentUser == null || event.status != EventStatus.approved) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<EventRSVP?>(
      stream: _eventService.getUserRSVP(event.eventId, _currentUser!.uid),
      builder: (context, snapshot) {
        final userRSVP = snapshot.data?.response;

        return GlassPanel(
          padding: const EdgeInsets.all(18),
          borderRadius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your RSVP',
                style: TextStyle(
                  color: AppTheme.darkTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Let the organizers and mentors know if you are coming.',
                style: TextStyle(
                  color: AppTheme.lightTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ModernRSVPButton(
                      label: 'Going',
                      icon: Icons.check_circle_rounded,
                      color: AppTheme.successColor,
                      isSelected: userRSVP == 'attending',
                      onTap: () =>
                          _handleRSVP(event, 'attending', userRSVP),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModernRSVPButton(
                      label: 'Interested',
                      icon: Icons.star_rounded,
                      color: AppTheme.warningColor,
                      isSelected: userRSVP == 'interested',
                      onTap: () =>
                          _handleRSVP(event, 'interested', userRSVP),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ModernRSVPButton(
                      label: "Can't Go",
                      icon: Icons.cancel_rounded,
                      color: AppTheme.errorColor,
                      isSelected: userRSVP == 'not_going',
                      onTap: () =>
                          _handleRSVP(event, 'not_going', userRSVP),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: AppTheme.lightTextColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${event.interestedCount} interested • ${event.notGoingCount} not going',
                    style: const TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutCard(EventModel event) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About This Event',
            style: TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event.description,
            style: const TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Hosted by ${event.createdByName} (${event.createdByRole.toUpperCase()})',
            style: const TextStyle(
              color: AppTheme.lightTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(String eventId) {
    return StreamBuilder<List<EventRSVP>>(
      stream: _eventService.getEventRsvps(eventId),
      builder: (context, snapshot) {
        final rsvps = (snapshot.data ?? [])
            .where((rsvp) => rsvp.response == 'attending')
            .toList();

        return GlassPanel(
          padding: const EdgeInsets.all(18),
          borderRadius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Attendees',
                    style: TextStyle(
                      color: AppTheme.darkTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${rsvps.length} confirmed',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (rsvps.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No confirmed attendees yet. Be the first to RSVP!',
                    style: TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                ...rsvps.take(15).map(
                      (rsvp) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              child: Text(
                                rsvp.userName.isNotEmpty
                                    ? rsvp.userName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                rsvp.userName,
                                style: const TextStyle(
                                  color: AppTheme.darkTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleRSVP(
    EventModel event,
    String response,
    String? previousResponse,
  ) async {
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
      Fluttertoast.showToast(
        msg: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

class _ModernRSVPButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModernRSVPButton({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 18,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
