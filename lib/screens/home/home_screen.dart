import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../clubs/club_details_screen.dart';
import '../clubs/club_list_screen.dart';
import '../clubs/create_club_screen.dart';
import '../events/create_event_screen.dart';
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
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final uid = authService.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final user = await _firestoreService.getUserById(uid);
      if (user != null) {
        try {
          await _notificationService.initialize(userId: user.uid);
        } catch (e) {
          debugPrint('Notification init error: $e');
        }
      }

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isFaculty => _currentUser?.userType == AppConstants.userTypeFaculty;

  List<String> get _managedClubIds {
    final user = _currentUser;
    if (user == null) return [];
    return {
      ...user.clubsCreated,
      ...user.isPresidentOf,
      ...user.isOrganizerOf,
    }.toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Profile not found. Please sign in again.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    Provider.of<AuthService>(context, listen: false).signOut(),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          const _DashboardBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadUserData,
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopBar(),
                          const SizedBox(height: 18),
                          _buildHeroPanel(),
                          const SizedBox(height: 18),
                          _buildRoleActionGrid(),
                          const SizedBox(height: 20),
                          _buildSectionHeader(
                            title: _isFaculty
                                ? 'Approval desk'
                                : 'College highlights',
                            actionText: _isFaculty ? 'Calendar' : 'View all',
                            onTap: () => _openCalendar(),
                          ),
                          _isFaculty
                              ? _buildFacultyApprovalDesk()
                              : _buildStudentHighlights(),
                          const SizedBox(height: 20),
                          _buildSectionHeader(
                            title:
                                _isFaculty ? 'Clubs you mentor' : 'Your clubs',
                            actionText: 'Clubs',
                            onTap: () => _openClubs(),
                          ),
                          _buildMyClubs(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    final user = _currentUser!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: const TextStyle(
                  color: AppTheme.lightTextColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.firstName.isEmpty ? 'KlubConnect' : user.firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.darkTextColor,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
        ),
        _IconGlassButton(
          icon: Icons.search_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          ),
        ),
        const SizedBox(width: 10),
        _buildNotificationButton(),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => EditProfileScreen(user: user)),
          ),
          child: CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            backgroundImage: user.profileImageUrl != null
                ? CachedNetworkImageProvider(user.profileImageUrl!)
                : null,
            child: user.profileImageUrl == null
                ? Text(
                    _initials(user),
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationButton() {
    return StreamBuilder<int>(
      stream: _notificationService.getUnreadCount(_currentUser!.uid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _IconGlassButton(
              icon: Icons.notifications_none_rounded,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationScreen()),
              ),
            ),
            if (count > 0)
              Positioned(
                right: -2,
                top: -3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeroPanel() {
    final user = _currentUser!;
    final roleLabel =
        _isFaculty ? 'Faculty mentor workspace' : 'Connect with your Club';
    final primaryAction = _isFaculty ? 'Create club' : 'Explore clubs';
    final primaryIcon =
        _isFaculty ? Icons.add_business_rounded : Icons.explore_rounded;

    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isFaculty ? 'Faculty' : 'Student',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            user.collegeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.secondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: _isFaculty ? 'Created' : 'Joined',
                  value: _isFaculty
                      ? '${user.clubsCreated.length}'
                      : '${user.clubsJoined.length}',
                  icon: Icons.groups_2_rounded,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricPill(
                  label: _isFaculty ? 'Mentoring' : 'Leading',
                  value: _isFaculty
                      ? '${user.clubsCreated.length}'
                      : '${user.isPresidentOf.length + user.isOrganizerOf.length}',
                  icon: _isFaculty
                      ? Icons.school_rounded
                      : Icons.workspace_premium_rounded,
                  color: AppTheme.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isFaculty ? _openCreateClub : _openClubs,
              icon: Icon(primaryIcon),
              label: Text(primaryAction),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.darkTextColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleActionGrid() {
    final actions = <_DashboardAction>[];
    if (_isFaculty) {
      actions.addAll([
        _DashboardAction('Create Club', Icons.add_circle_outline_rounded,
            _openCreateClub, AppTheme.primaryColor),
        _DashboardAction('Review Events', Icons.fact_check_outlined,
            _openCalendar, AppTheme.warningColor),
        _DashboardAction('Announcements', Icons.campaign_outlined, _openClubs,
            AppTheme.accentColor),
        _DashboardAction('Search College', Icons.manage_search_rounded,
            _openSearch, const Color(0xFF334155)),
      ]);
    } else {
      actions.addAll([
        _DashboardAction('Discover Clubs', Icons.travel_explore_rounded,
            _openClubs, AppTheme.primaryColor),
        _DashboardAction('Event Calendar', Icons.calendar_month_rounded,
            _openCalendar, AppTheme.accentColor),
      ]);
      if (_managedClubIds.isNotEmpty) {
        actions.addAll([
          _DashboardAction('Create Event', Icons.add_task_rounded,
              _openCreateEventForManagedClub, AppTheme.warningColor),
          _DashboardAction('Manage Club', Icons.admin_panel_settings_outlined,
              _openClubs, const Color(0xFF334155)),
        ]);
      } else {
        actions.addAll([
          _DashboardAction('My Profile', Icons.person_outline_rounded,
              _openProfile, const Color(0xFF334155)),
          _DashboardAction('Search College', Icons.manage_search_rounded,
              _openSearch, AppTheme.warningColor),
        ]);
      }
    }

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.85,
      ),
      itemBuilder: (context, index) => _ActionTile(action: actions[index]),
    );
  }

  Widget _buildFacultyApprovalDesk() {
    return StreamBuilder<List<EventModel>>(
      stream: _eventService.getPendingEventsForClubs(_managedClubIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPanel(message: 'Checking pending proposals...');
        }

        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const _EmptyPanel(
            icon: Icons.verified_outlined,
            title: 'No pending event approvals',
            message:
                'New event proposals from presidents and organizers will appear here.',
          );
        }

        return Column(
          children: events.take(3).map((event) {
            return _EventCard(
              event: event,
              badge: 'Pending approval',
              badgeColor: AppTheme.warningColor,
              onTap: () => _openEvent(event.eventId),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStudentHighlights() {
    return StreamBuilder<List<EventModel>>(
      stream: _eventService.getApprovedEvents(
        _currentUser!.collegeName,
        institutionId: _currentUser!.institutionId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPanel(message: 'Loading college events...');
        }

        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const _EmptyPanel(
            icon: Icons.event_available_outlined,
            title: 'No approved events yet',
            message:
                'Once clubs publish approved events, they will show up here.',
          );
        }

        return Column(
          children: events.take(4).map((event) {
            return _EventCard(
              event: event,
              badge: event.clubName,
              badgeColor: _clubColor(event.clubColor),
              onTap: () => _openEvent(event.eventId),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMyClubs() {
    final clubIds =
        _isFaculty ? _currentUser!.clubsCreated : _currentUser!.clubsJoined;

    return StreamBuilder<List<ClubModel>>(
      stream: _clubService.getClubsForUser(clubIds),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPanel(message: 'Loading clubs...');
        }

        final clubs = snapshot.data ?? [];
        if (clubs.isEmpty) {
          return _EmptyPanel(
            icon: Icons.groups_2_outlined,
            title: _isFaculty ? 'No clubs created yet' : 'No clubs joined yet',
            message: _isFaculty
                ? 'Create your first club and assign a student president.'
                : 'Explore college clubs and send a join request.',
          );
        }

        return SizedBox(
          height: 178,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: clubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _ClubCard(
              club: clubs[index],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ClubDetailsScreen(clubId: clubs[index].clubId),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.darkTextColor,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
            ),
          ),
          TextButton(
            onPressed: onTap,
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: NavigationBar(
          height: 72,
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'Clubs',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
          onDestinationSelected: (index) {
            if (index == 1) _openClubs();
            if (index == 2) _openCalendar();
            if (index == 3) _openProfile();
          },
        ),
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(UserModel user) {
    final first = user.firstName.isNotEmpty ? user.firstName[0] : '';
    final last = user.lastName.isNotEmpty ? user.lastName[0] : '';
    final value = '$first$last'.trim();
    return value.isEmpty ? 'KC' : value.toUpperCase();
  }

  Color _clubColor(String value) {
    try {
      return Color(int.parse(value.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  void _openClubs() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ClubListScreen()));
  }

  void _openCalendar() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const CalendarScreen()));
  }

  void _openSearch() {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => const SearchScreen()));
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EditProfileScreen(user: _currentUser!)),
    );
  }

  void _openCreateClub() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const CreateClubScreen()));
  }

  Future<void> _openCreateEventForManagedClub() async {
    if (_managedClubIds.isEmpty) return;
    final club = await _clubService.getClubById(_managedClubIds.first);
    if (!mounted || club == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateEventScreen(club: club)),
    );
  }

  void _openEvent(String eventId) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EventDetailsScreen(eventId: eventId)),
    );
  }
}

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEFF6FF),
            Color(0xFFF8FAFC),
            Color(0xFFEFFDF9),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _SoftOrb(
                color: AppTheme.primaryColor.withValues(alpha: 0.16),
                size: 210),
          ),
          Positioned(
            top: 250,
            left: -90,
            child: _SoftOrb(
                color: AppTheme.accentColor.withValues(alpha: 0.12), size: 190),
          ),
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _SoftOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IconGlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconGlassButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.76),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 46,
              width: 46,
              child: Icon(icon, color: AppTheme.darkTextColor),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.secondaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  _DashboardAction(this.label, this.icon, this.onTap, this.color);
}

class _ActionTile extends StatelessWidget {
  final _DashboardAction action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: action.onTap,
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(action.icon, color: action.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.darkTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${event.eventDate.day}',
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    _monthLabel(event.eventDate.month),
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.darkTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${event.eventTime} - ${event.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.lightTextColor),
          ],
        ),
      ),
    );
  }

  static String _monthLabel(int month) {
    const labels = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return labels[month - 1];
  }
}

class _ClubCard extends StatelessWidget {
  final ClubModel club;
  final VoidCallback onTap;

  const _ClubCard({
    required this.club,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _safeColor(club.colorCode);

    return SizedBox(
      width: 164,
      child: _GlassPanel(
        padding: const EdgeInsets.all(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: color.withValues(alpha: 0.1),
                    backgroundImage: club.logoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(club.logoUrl)
                        : null,
                    child: club.logoUrl.isEmpty
                        ? Text(
                            club.name.isEmpty
                                ? 'K'
                                : club.name[0].toUpperCase(),
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.w900),
                          )
                        : null,
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded, color: color, size: 18),
                ],
              ),
              const Spacer(),
              Text(
                club.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.darkTextColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                club.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.secondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${club.totalMembers} members',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _safeColor(String value) {
    try {
      return Color(int.parse(value.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }
}

class _LoadingPanel extends StatelessWidget {
  final String message;

  const _LoadingPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.secondaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.secondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
