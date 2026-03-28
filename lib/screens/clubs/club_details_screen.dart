import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/user_model.dart';
import '../../services/club_service.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/custom_button.dart';
import '../events/create_event_screen.dart';
import '../events/event_details_screen.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';

class ClubDetailsScreen extends StatefulWidget {
  final String clubId;
  const ClubDetailsScreen({super.key, required this.clubId});

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  final _clubService = ClubService();
  final _eventService = EventService();
  UserModel? _currentUser;
  bool _isMember = false;
  bool _isPresident = false;
  bool _isClubMaster = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = FirestoreService();
    if (authService.currentUser != null) {
      final user = await firestoreService.getUserById(authService.currentUser!.uid);
      if (mounted) setState(() => _currentUser = user);
    }
  }

  void _checkRoles(ClubModel club) {
    if (_currentUser == null) return;
    _isMember = club.members.contains(_currentUser!.uid);
    _isPresident = club.presidentId == _currentUser!.uid;
    _isClubMaster = club.clubMasterId == _currentUser!.uid;
  }

  Future<void> _joinClub(ClubModel club) async {
    if (_currentUser == null) return;
    try {
      await _clubService.sendJoinRequest(
        clubId: club.clubId,
        clubName: club.name,
        userId: _currentUser!.uid,
        userName: _currentUser!.fullName,
        message: "I would like to join this club.",
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClubModel>(
      stream: _clubService.streamClub(widget.clubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: Text('Club not found.')));
        }

        final club = snapshot.data!;
        _checkRoles(club);

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(club.name),
                  background: club.bannerUrl.isNotEmpty
                      ? Image.network(club.bannerUrl, fit: BoxFit.cover)
                      : Container(color: Theme.of(context).primaryColor),
                ),
                actions: [
                  if (_isPresident || _isClubMaster)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // TODO: Implement edit club
                      },
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: club.logoUrl.isNotEmpty
                                ? NetworkImage(club.logoUrl)
                                : null,
                            child: club.logoUrl.isEmpty ? Text(club.name[0]) : null,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  club.category,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${club.totalMembers} Members',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'About',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(club.description),
                      const SizedBox(height: 24),
                      if (!_isMember && !_isPresident && !_isClubMaster)
                        CustomButton(
                          text: 'Request to Join',
                          onPressed: () => _joinClub(club),
                        ),
                      if (_isPresident || _isClubMaster) ...[
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Create Event',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateEventScreen(club: club),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Text(
                        'Upcoming Events',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildEventsList(club.clubId),
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

  Widget _buildEventsList(String clubId) {
    return StreamBuilder<List<EventModel>>(
      stream: _eventService.getEventsByClub(clubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No events scheduled.');
        }

        final events = snapshot.data!;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventDetailsScreen(eventId: event.eventId),
                  ),
                ),
                child: GlassCard(
                  child: ListTile(
                    title: Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${event.eventDate.day}/${event.eventDate.month} at ${event.eventTime}'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
