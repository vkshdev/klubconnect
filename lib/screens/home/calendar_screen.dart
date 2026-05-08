import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';

import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/glass_card.dart';
import '../../utils/theme.dart';
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
  String? _collegeName;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final uid = authService.currentUser?.uid;
      if (uid == null) return;

      final user = await _firestoreService.getUserById(uid);
      if (user == null) return;
      _collegeName = user.collegeName;

      // Stream events and convert to map
      _eventService.getApprovedEvents(user.collegeName).listen((eventList) {
        final Map<DateTime, List<EventModel>> eventMap = {};
        for (var event in eventList) {
          final date = DateTime(event.eventDate.year, event.eventDate.month, event.eventDate.day);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Event Calendar'),
        backgroundColor: AppTheme.surfaceColor,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildCalendar(),
            const SizedBox(height: 16),
            Expanded(child: _buildEventList()),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
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
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkTextColor),
        ),
        calendarStyle: CalendarStyle(
          markersMaxCount: 1,
          markerDecoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.15), shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
          selectedDecoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(color: AppTheme.darkTextColor),
          weekendTextStyle: const TextStyle(color: AppTheme.errorColor),
        ),
      ),
    );
  }

  Widget _buildEventList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            selectedEvents.isEmpty ? 'No events scheduled' : 'Events for this day',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkTextColor),
          ),
        ),
        ...selectedEvents.map((event) => _CalendarEventItem(event: event)),
      ],
    );
  }
}

class _CalendarEventItem extends StatelessWidget {
  final EventModel event;

  const _CalendarEventItem({required this.event});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: Color(int.parse(event.clubColor.replaceAll('#', '0xFF'))),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.darkTextColor)),
        subtitle: Text('${event.clubName} • ${event.eventTime}', style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 13)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.borderColor),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventDetailsScreen(eventId: event.eventId)),
        ),
      ),
    );
  }
}
