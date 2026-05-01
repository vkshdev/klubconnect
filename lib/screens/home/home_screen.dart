import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/club_model.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/club_service.dart';
import '../../services/event_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/glass_card.dart';
import '../clubs/club_details_screen.dart';
import '../clubs/club_list_screen.dart';
import '../events/event_details_screen.dart';
import '../home/calendar_screen.dart';
import '../home/search_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/edit_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  final _clubService = ClubService();
  final _eventService = EventService();
  final _notificationService = NotificationService();

  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;
    if (uid == null) return;

    final user = await _firestoreService.getUserById(uid);
    if (user != null) {
      await _notificationService.initialize(userId: user.uid);
    }
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Provider.of<AuthService>(context, listen: false).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text('Profile not found.')));
    }

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadUserData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildPrimaryActions(),
                const SizedBox(height: 18),
                _buildStats(),
                const SizedBox(height: 24),
                _buildSectionHeader('Upcoming Events', 'View calendar', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen()));
                }),
                const SizedBox(height: 12),
                _buildUpcomingEvents(),
                const SizedBox(height: 24),
                _buildSectionHeader('My Clubs', 'Browse all', () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ClubListScreen()));
                }),
                const SizedBox(height: 12),
                _buildMyClubs(),
                if (_managedClubIds.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader('Pending Approvals', 'Open clubs', () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ClubListScreen()));
                  }),
                  const SizedBox(height: 12),
                  _buildPendingApprovals(),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  List<String> get _managedClubIds {
    final user = _currentUser;
    if (user == null) return [];
    return {...user.clubsCreated, ...user.isPresidentOf, ...user.isOrganizerOf}.toList();
  }

  Widget _buildHeader() {
    final user = _currentUser!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${user.firstName}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                user.collegeName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        StreamBuilder<int>(
          stream: _notificationService.getUnreadCount(user.uid),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationScreen()),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Color(0xFFE11D48), shape: BoxShape.circle),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EditProfileScreen(user: user)),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
            child: user.profileImageUrl == null && user.firstName.isNotEmpty
                ? Text(user.firstName[0].toUpperCase())
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActions() {
    final actions = [
      _HomeAction('Clubs', Icons.groups_outlined, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ClubListScreen()));
      }),
      _HomeAction('Calendar', Icons.calendar_month_outlined, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen()));
      }),
      _HomeAction('Search', Icons.search, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
      }),
      _HomeAction('Profile', Icons.person_outline, () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(user: _currentUser!)));
      }),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 24,
      child: Row(
        children: actions
            .map(
              (action) => Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: action.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(action.icon, color: const Color(0xFF1D4ED8)),
                        ),
                        const SizedBox(height: 8),
                        Text(action.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildStats() {
    final user = _currentUser!;
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Joined', value: '${user.clubsJoined.length}', icon: Icons.group_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'President', value: '${user.isPresidentOf.length}', icon: Icons.verified_outlined)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Organizer', value: '${user.isOrganizerOf.length}', icon: Icons.event_note_outlined)),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String action, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }

  Widget _buildUpcomingEvents() {
    return StreamBuilder<List<EventModel>>(
      stream: _eventService.getApprovedEvents(_currentUser!.collegeName),
      builder: (context, snapshot) {
        final events = (snapshot.data ?? [])
            .where((event) => event.eventDate.isAfter(DateTime.now().subtract(const Duration(days: 1))))
            .take(5)
            .toList();
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (events.isEmpty) {
          return const GlassCard(child: Text('No upcoming events yet.'));
        }
        return Column(
          children: events
              .map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _AccentBar(colorCode: event.clubColor),
                      title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${event.clubName} - ${event.eventDate.day}/${event.eventDate.month} at ${event.eventTime}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EventDetailsScreen(eventId: event.eventId)),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMyClubs() {
    return StreamBuilder<List<ClubModel>>(
      stream: _clubService.getClubsForUser(_currentUser!.clubsJoined),
      builder: (context, snapshot) {
        final clubs = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (clubs.isEmpty) {
          return const GlassCard(child: Text('Join a club to see it here.'));
        }
        return SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: clubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final club = clubs[index];
              return SizedBox(
                width: 220,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ClubDetailsScreen(clubId: club.clubId)),
                  ),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: club.logoUrl.isNotEmpty ? NetworkImage(club.logoUrl) : null,
                              child: club.logoUrl.isEmpty && club.name.isNotEmpty ? Text(club.name[0]) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                club.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(club.category, style: TextStyle(color: Colors.grey.shade700)),
                        Text('${club.totalMembers} members', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPendingApprovals() {
    return StreamBuilder<List<EventModel>>(
      stream: _eventService.getPendingEventsForClubs(_managedClubIds),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const GlassCard(child: Text('No pending event approvals.'));
        }
        return GlassCard(
          child: Column(
            children: events
                .take(3)
                .map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(event.clubName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ClubDetailsScreen(clubId: event.clubId)),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        if (index == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ClubListScreen()));
        } else if (index == 2) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen()));
        } else if (index == 3) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
        } else if (index == 4) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(user: _currentUser!)));
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Clubs'),
        NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
        NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}

class _HomeAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  _HomeAction(this.label, this.icon, this.onTap);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AccentBar extends StatelessWidget {
  final String colorCode;

  const _AccentBar({required this.colorCode});

  @override
  Widget build(BuildContext context) {
    Color color;
    try {
      color = Color(int.parse(colorCode.replaceAll('#', '0xFF')));
    } catch (_) {
      color = Theme.of(context).primaryColor;
    }
    return Container(
      width: 6,
      height: 48,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
    );
  }
}
