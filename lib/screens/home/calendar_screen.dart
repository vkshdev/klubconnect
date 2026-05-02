import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/glass_card.dart';
import '../events/event_details_screen.dart';

enum _CalendarFilter { all, myClubs, agenda }

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
  DateTime _selectedDay = DateTime.now();
  _CalendarFilter _filter = _CalendarFilter.all;
  List<EventModel> _allEvents = [];
  UserModel? _currentUser;
  StreamSubscription<List<EventModel>>? _eventsSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndEvents();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserAndEvents() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;
    if (uid == null) return;

    final user = await _firestoreService.getUserById(uid);
    await _eventsSubscription?.cancel();
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _eventsSubscription = _eventService.getApprovedEvents(user.collegeName).listen((events) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _allEvents = events;
          _isLoading = false;
        });
      }
    });
  }

  List<EventModel> get _visibleEvents {
    final user = _currentUser;
    if (user == null) return [];
    if (_filter == _CalendarFilter.myClubs) {
      return _allEvents.where((event) => user.clubsJoined.contains(event.clubId)).toList();
    }
    return _allEvents;
  }

  List<EventModel> _eventsForDay(DateTime day) {
    return _visibleEvents.where((event) {
      return event.eventDate.year == day.year &&
          event.eventDate.month == day.month &&
          event.eventDate.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserAndEvents,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  GlassCard(
                    borderRadius: 24,
                    child: Column(
                      children: [
                        SegmentedButton<_CalendarFilter>(
                          segments: const [
                            ButtonSegment(value: _CalendarFilter.all, label: Text('All')),
                            ButtonSegment(value: _CalendarFilter.myClubs, label: Text('My Clubs')),
                            ButtonSegment(value: _CalendarFilter.agenda, label: Text('Agenda')),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (selected) => setState(() => _filter = selected.first),
                        ),
                        const SizedBox(height: 12),
                        if (_filter != _CalendarFilter.agenda)
                          TableCalendar<EventModel>(
                            firstDay: DateTime.utc(2023, 1, 1),
                            lastDay: DateTime.utc(2035, 12, 31),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            eventLoader: _eventsForDay,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) => setState(() => _calendarFormat = format),
                            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                            calendarStyle: CalendarStyle(
                              markerDecoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            headerStyle: const HeaderStyle(titleCentered: true),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEventList(),
                ],
              ),
            ),
    );
  }

  Widget _buildEventList() {
    final events = _filter == _CalendarFilter.agenda
        ? _visibleEvents
            .where((event) => event.eventDate.isAfter(DateTime.now().subtract(const Duration(days: 1))))
            .toList()
        : _eventsForDay(_selectedDay);

    if (events.isEmpty) {
      return const GlassCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('No events for this view.')),
        ),
      );
    }

    return Column(
      children: events
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EventDetailsScreen(eventId: event.eventId)),
                ),
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _parseColor(event.clubColor),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${event.eventTime} - ${event.clubName}'),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Color _parseColor(String value) {
    try {
      return Color(int.parse(value.replaceAll('#', '0xFF')));
    } catch (_) {
      return Theme.of(context).primaryColor;
    }
  }
}
