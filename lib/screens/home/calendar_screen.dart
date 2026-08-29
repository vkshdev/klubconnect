import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import '../../widgets/screen_background.dart';
import '../events/event_details_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _eventService = EventService();
  final _firestoreService = FirestoreService();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<EventModel>> _events = {};
  bool _isLoading = true;
  StreamSubscription<List<EventModel>>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final uid = authService.currentUser?.uid;
      if (uid == null) return;

      final user = await _firestoreService.getUserById(uid);
      if (user == null) return;

      await _eventsSubscription?.cancel();
      _eventsSubscription = _eventService
          .getApprovedEvents(
        user.collegeName,
        institutionId: user.institutionId,
      )
          .listen((eventList) {
        final Map<DateTime, List<EventModel>> eventMap = {};
        for (var event in eventList) {
          final date = DateTime(
            event.eventDate.year,
            event.eventDate.month,
            event.eventDate.day,
          );
          if (eventMap[date] == null) eventMap[date] = [];
          eventMap[date]!.add(event);
        }
        if (mounted) {
          setState(() {
            _events = eventMap;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint('Error loading calendar events: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<EventModel> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = now;
      _focusedDay = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayEvents = _getEventsForDay(_selectedDay ?? _focusedDay);
    final formattedSelectedDate =
        DateFormat('EEEE, MMM d').format(_selectedDay ?? _focusedDay);

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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ScreenHeader(
                          title: 'Event Calendar',
                          subtitle: 'Campus Schedule',
                          actions: [
                            IconGlassButton(
                              icon: Icons.today_rounded,
                              iconColor: AppTheme.primaryColor,
                              onTap: _jumpToToday,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildCalendar(),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Text(
                              formattedSelectedDate,
                              style: const TextStyle(
                                color: AppTheme.darkTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${selectedDayEvents.length} ${selectedDayEvents.length == 1 ? 'event' : 'events'}',
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
                      ],
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                else if (selectedDayEvents.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildEmptyState(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = selectedDayEvents[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CalendarEventCard(event: event),
                          );
                        },
                        childCount: selectedDayEvents.length,
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

  Widget _buildCalendar() {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
      borderRadius: 24,
      child: TableCalendar<EventModel>(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        eventLoader: _getEventsForDay,
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppTheme.darkTextColor,
            letterSpacing: -0.3,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: AppTheme.darkTextColor,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.darkTextColor,
          ),
        ),
        calendarStyle: CalendarStyle(
          markersMaxCount: 1,
          markerDecoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryColor, width: 1.5),
          ),
          todayTextStyle: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w900,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(
            color: AppTheme.darkTextColor,
            fontWeight: FontWeight.w600,
          ),
          weekendTextStyle: const TextStyle(
            color: AppTheme.errorColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Center(
        child: Column(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppTheme.primaryColor,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No events scheduled',
              style: TextStyle(
                color: AppTheme.darkTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'There are no approved events on this date.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarEventCard extends StatelessWidget {
  final EventModel event;

  const _CalendarEventCard({required this.event});

  Color _safeColor(String value) {
    try {
      return Color(int.parse(value.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _safeColor(event.clubColor);

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailsScreen(eventId: event.eventId),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              event.venueType == 'online'
                  ? Icons.videocam_rounded
                  : Icons.location_on_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        event.clubName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      event.eventTime,
                      style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: AppTheme.lightTextColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.secondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${event.currentParticipants} attending',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.lightTextColor,
            size: 20,
          ),
        ],
      ),
    );
  }
}
