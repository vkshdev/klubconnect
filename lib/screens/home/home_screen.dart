import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../widgets/glass_card.dart';
import '../../utils/constants.dart';
import '../clubs/club_list_screen.dart';
import '../clubs/create_club_screen.dart';
import '../events/event_details_screen.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
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
  final _eventService = EventService();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;

    if (uid != null) {
      final user = await _firestoreService.getUserById(uid);
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                backgroundColor: Theme.of(context).primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    AppConstants.appName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationScreen()));
                    },
                  ),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Profile Card
                      if (_currentUser != null) _buildProfileCard(_currentUser!),

                      const SizedBox(height: 24),

                      // Welcome Message
                      Text(
                        'Welcome ${_currentUser?.firstName ?? ""}! 👋',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _currentUser?.userType == AppConstants.userTypeStudent
                            ? 'Explore clubs and connect with your peers'
                            : 'Manage your clubs and mentor students',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Quick Actions
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildQuickActions(),

                      const SizedBox(height: 32),

                      // Featured Events Section
                      Text(
                        'Featured Events',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_currentUser != null) _buildEventsList(),

                      const SizedBox(height: 24),

                      // Logout Button
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserModel user) {
    return GlassCard(
      child: Row(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 40,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            backgroundImage: user.profileImageUrl != null
                ? NetworkImage(user.profileImageUrl!)
                : null,
            child: user.profileImageUrl == null
                ? Text(
              user.firstName[0].toUpperCase(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            )
                : null,
          ),

          const SizedBox(width: 16),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                if (user.userType == AppConstants.userTypeStudent) ...[
                  Text(
                    '${user.course} - ${user.branch}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (user.currentYearLabel != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user.currentYearLabel!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.profession ?? 'Faculty',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    user.department ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                Text(
                  user.collegeName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Edit Button
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(user: user)));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = _currentUser?.userType == AppConstants.userTypeStudent
        ? [
      _QuickAction(
        icon: Icons.groups,
        label: 'Browse Clubs',
        color: const Color(0xFF4CAF50),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ClubListScreen()));
        },
      ),
      _QuickAction(
        icon: Icons.event,
        label: 'Events',
        color: const Color(0xFFFF9800),
        onTap: () {
           // TODO: Navigate to events list screen if needed
        },
      ),
      _QuickAction(
        icon: Icons.calendar_today,
        label: 'Calendar',
        color: const Color(0xFF2196F3),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarScreen()));
        },
      ),
      _QuickAction(
        icon: Icons.person,
        label: 'My Profile',
        color: const Color(0xFF9C27B0),
        onTap: () {
          // TODO: Navigate to profile
        },
      ),
    ]
        : [
      _QuickAction(
        icon: Icons.add_circle,
        label: 'Create Club',
        color: const Color(0xFF4CAF50),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateClubScreen()));
        },
      ),
      _QuickAction(
        icon: Icons.dashboard,
        label: 'My Clubs',
        color: const Color(0xFF2196F3),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ClubListScreen()));
        },
      ),
      _QuickAction(
        icon: Icons.pending_actions,
        label: 'Approvals',
        color: const Color(0xFFFF9800),
        onTap: () {
          // TODO: Navigate to approvals
        },
      ),
      _QuickAction(
        icon: Icons.analytics,
        label: 'Analytics',
        color: const Color(0xFF9C27B0),
        onTap: () {
          // TODO: Navigate to analytics
        },
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: actions.map((action) {
        return GestureDetector(
          onTap: action.onTap,
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: action.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    action.icon,
                    size: 32,
                    color: action.color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEventsList() {
    return StreamBuilder<List<EventModel>>(
      stream: _eventService.getApprovedEvents(_currentUser!.collegeName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No featured events.');
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
                    subtitle: Text('${event.eventDate.day}/${event.eventDate.month} · ${event.clubName}'),
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

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
