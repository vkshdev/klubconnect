import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/club_model.dart';
import '../../models/club_membership_model.dart';
import '../../models/event_model.dart';
import '../../models/membership_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/club_service.dart';
import '../../services/event_service.dart';
import '../../services/firestore_service.dart';
import '../../services/membership_service.dart';
import '../../services/notification_service.dart';
import '../../utils/theme.dart';
import '../../widgets/cached_remote_image.dart';
import '../../widgets/screen_background.dart';
import '../events/create_event_screen.dart';
import '../events/event_details_screen.dart';
import 'announcement_list_screen.dart';

class ClubDetailsScreen extends StatefulWidget {
  final String clubId;
  const ClubDetailsScreen({super.key, required this.clubId});

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  final _clubService = ClubService();
  final _eventService = EventService();
  final _membershipService = MembershipService();
  final _notificationService = NotificationService();
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

  bool _isMember(ClubModel club) =>
      _currentUser != null && club.members.contains(_currentUser!.uid);
  bool _isPresident(ClubModel club) =>
      _currentUser != null && club.presidentId == _currentUser!.uid;
  bool _isOrganizer(ClubModel club) =>
      _currentUser != null && club.organizers.contains(_currentUser!.uid);
  bool _isClubMaster(ClubModel club) =>
      _currentUser != null && club.clubMasterId == _currentUser!.uid;
  bool _canManage(ClubModel club) => _isPresident(club) || _isClubMaster(club);
  bool _canCreateEvent(ClubModel club) =>
      _canManage(club) || _isOrganizer(club);

  Color _safeColor(String value) {
    try {
      return Color(int.parse(value.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  Future<void> _sendJoinRequest(ClubModel club) async {
    if (_currentUser == null) return;
    try {
      await _membershipService.sendJoinRequest(
        club: club,
        userId: _currentUser!.uid,
        userName: _currentUser!.fullName,
        message: 'I would like to join ${club.name}.',
      );
      await _notificationService.sendNotification(
        userId: club.presidentId,
        institutionId: club.institutionId,
        type: 'membership_request',
        title: 'New membership request',
        message: '${_currentUser!.fullName} requested to join ${club.name}.',
        fromUserId: _currentUser!.uid,
        relatedClubId: club.clubId,
      );
      if (club.clubMasterId != club.presidentId) {
        await _notificationService.sendNotification(
          userId: club.clubMasterId,
          institutionId: club.institutionId,
          type: 'membership_request',
          title: 'New membership request',
          message: '${_currentUser!.fullName} requested to join ${club.name}.',
          fromUserId: _currentUser!.uid,
          relatedClubId: club.clubId,
        );
      }
      Fluttertoast.showToast(msg: 'Join request sent.');
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _leaveClub(ClubModel club) async {
    if (_currentUser == null) return;
    try {
      await _membershipService.leaveClub(club: club, userId: _currentUser!.uid);
      Fluttertoast.showToast(msg: 'You left ${club.name}.');
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _respondToRequest(
    MembershipRequestModel request,
    RequestStatus status,
  ) async {
    if (_currentUser == null) return;
    await _membershipService.respondToRequest(
      request: request,
      status: status,
      respondedById: _currentUser!.uid,
    );
    await _notificationService.sendNotification(
      userId: request.userId,
      institutionId: request.institutionId,
      type: status == RequestStatus.approved
          ? 'membership_approved'
          : 'membership_rejected',
      title: status == RequestStatus.approved
          ? 'Membership approved'
          : 'Membership rejected',
      message: status == RequestStatus.approved
          ? 'Your request to join ${request.clubName} was approved.'
          : 'Your request to join ${request.clubName} was rejected.',
      fromUserId: _currentUser!.uid,
      relatedClubId: request.clubId,
    );
    Fluttertoast.showToast(
      msg: status == RequestStatus.approved
          ? 'Request approved.'
          : 'Request rejected.',
    );
  }

  Future<void> _updateEventStatus(EventModel event, EventStatus status) async {
    await _eventService.updateEventStatus(
      event.eventId,
      status,
      actorUserId: _currentUser!.uid,
      institutionId: event.institutionId,
    );
    await _notificationService.sendNotification(
      userId: event.createdById,
      institutionId: event.institutionId,
      type:
          status == EventStatus.approved ? 'event_approved' : 'event_rejected',
      title:
          status == EventStatus.approved ? 'Event approved' : 'Event rejected',
      message:
          '${event.title} was ${status == EventStatus.approved ? 'approved' : 'rejected'}.',
      fromUserId: _currentUser!.uid,
      relatedClubId: event.clubId,
      relatedEventId: event.eventId,
    );
    Fluttertoast.showToast(
      msg: status == EventStatus.approved
          ? 'Event approved.'
          : 'Event rejected.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClubModel?>(
      stream: _clubService.streamClub(widget.clubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _currentUser == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          );
        }
        final club = snapshot.data;
        if (club == null) {
          return const Scaffold(
            body: Center(child: Text('Club not found.')),
          );
        }

        final tabs = [
          const Tab(text: 'Overview'),
          const Tab(text: 'Events'),
          const Tab(text: 'Members'),
          if (_canManage(club)) const Tab(text: 'Requests'),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Stack(
              children: [
                const ScreenBackground(),
                NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverAppBar(
                      expandedHeight: 250,
                      pinned: true,
                      backgroundColor: AppTheme.surfaceColor,
                      elevation: 0,
                      leading: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Center(
                          child: IconGlassButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: _ClubHeroBanner(club: club),
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(48),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.92),
                          child: TabBar(
                            tabs: tabs,
                            labelColor: AppTheme.primaryColor,
                            unselectedLabelColor: AppTheme.secondaryColor,
                            indicatorColor: AppTheme.primaryColor,
                            indicatorWeight: 3,
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    children: [
                      _buildOverview(club),
                      _buildEvents(club),
                      _buildMembers(club),
                      if (_canManage(club)) _buildRequests(club),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverview(ClubModel club) {
    final color = _safeColor(club.colorCode);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        GlassPanel(
          padding: const EdgeInsets.all(18),
          borderRadius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: color.withValues(alpha: 0.12),
                    backgroundImage: club.logoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(club.logoUrl)
                        : null,
                    child: club.logoUrl.isEmpty && club.name.isNotEmpty
                        ? Text(
                            club.name[0].toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club.name,
                          style: const TextStyle(
                            color: AppTheme.darkTextColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                club.category,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${club.totalMembers} members',
                              style: const TextStyle(
                                color: AppTheme.secondaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              const Text(
                'About the Club',
                style: TextStyle(
                  color: AppTheme.darkTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                club.description,
                style: const TextStyle(
                  color: AppTheme.secondaryColor,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.school_rounded,
                    size: 16,
                    color: AppTheme.lightTextColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Faculty Mentor: ${club.clubMasterName}',
                      style: const TextStyle(
                        color: AppTheme.secondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildMembershipAction(club),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.darkTextColor,
                  side: const BorderSide(color: AppTheme.borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.campaign_rounded,
                    color: AppTheme.primaryColor),
                label: const Text(
                  'Announcements',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnnouncementListScreen(
                      clubId: club.clubId,
                      clubName: club.name,
                      canPost: _canManage(club),
                    ),
                  ),
                ),
              ),
            ),
            if (_canCreateEvent(club)) ...[
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Create Event',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateEventScreen(club: club),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMembershipAction(ClubModel club) {
    if (_isClubMaster(club)) {
      return _buildRoleBadge('FACULTY MENTOR', Icons.workspace_premium_rounded,
          AppTheme.accentColor);
    }
    if (_isPresident(club)) {
      return _buildRoleBadge(
          'PRESIDENT', Icons.verified_rounded, AppTheme.primaryColor);
    }
    if (_isOrganizer(club)) {
      return _buildRoleBadge('ORGANIZER', Icons.event_available_rounded,
          const Color(0xFF8B5CF6));
    }
    if (_isMember(club)) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
          side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          'Leave Club',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: () => _leaveClub(club),
      );
    }
    return StreamBuilder<MembershipRequestModel?>(
      stream: _membershipService.streamUserRequest(
        clubId: club.clubId,
        userId: _currentUser!.uid,
      ),
      builder: (context, snapshot) {
        final request = snapshot.data;
        if (request?.status == RequestStatus.pending) {
          return _buildRoleBadge(
            'JOIN REQUEST PENDING',
            Icons.hourglass_top_rounded,
            AppTheme.warningColor,
          );
        }
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text(
            'Request to Join',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          onPressed: () => _sendJoinRequest(club),
        );
      },
    );
  }

  Widget _buildRoleBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvents(ClubModel club) {
    return StreamBuilder<List<EventModel>>(
      stream: _eventService.getEventsByClub(club.clubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }
        final events = (snapshot.data ?? []).where((event) {
          return _canManage(club) ||
              _isOrganizer(club) ||
              event.status == EventStatus.approved;
        }).toList();

        if (events.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 52,
                    width: 52,
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
                    'No events scheduled yet',
                    style: TextStyle(
                      color: AppTheme.darkTextColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassPanel(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EventDetailsScreen(eventId: event.eventId),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              const SizedBox(height: 3),
                              Text(
                                '${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year} at ${event.eventTime}',
                                style: const TextStyle(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _EventStatusBadge(status: event.status),
                      ],
                    ),
                    if (_isClubMaster(club) &&
                        event.status == EventStatus.pending) ...[
                      const Divider(height: 20, color: Color(0xFFF1F5F9)),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                side: const BorderSide(
                                    color: AppTheme.errorColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _updateEventStatus(
                                event,
                                EventStatus.rejected,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Approve'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _updateEventStatus(
                                event,
                                EventStatus.approved,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMembers(ClubModel club) {
    return StreamBuilder<List<ClubMembershipModel>>(
      stream: _clubService.streamClubMemberships(club.clubId),
      builder: (context, snapshot) {
        final memberships = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }
        if (memberships.isEmpty) {
          return const Center(child: Text('No members yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          itemCount: memberships.length,
          itemBuilder: (context, index) {
            return _buildMembershipTile(club, memberships[index]);
          },
        );
      },
    );
  }

  Widget _buildMembershipTile(ClubModel club, ClubMembershipModel membership) {
    final isPresident = membership.role == ClubMembershipRole.president ||
        club.presidentId == membership.userId;
    final isOrganizer = membership.role == ClubMembershipRole.organizer ||
        club.organizers.contains(membership.userId);
    final displayName =
        membership.userName.isEmpty ? 'Member' : membership.userName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        borderRadius: 18,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              backgroundImage: membership.userProfileImageUrl != null
                  ? CachedNetworkImageProvider(membership.userProfileImageUrl!)
                  : null,
              child: membership.userProfileImageUrl == null &&
                      displayName.isNotEmpty
                  ? Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: AppTheme.darkTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    isPresident
                        ? 'President'
                        : isOrganizer
                            ? 'Organizer'
                            : 'Member',
                    style: TextStyle(
                      color: isPresident
                          ? AppTheme.primaryColor
                          : isOrganizer
                              ? const Color(0xFF8B5CF6)
                              : AppTheme.secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_canManage(club) &&
                !isPresident &&
                membership.userId != _currentUser?.uid)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppTheme.lightTextColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) async {
                  if (value == 'organizer') {
                    await _membershipService.setOrganizerRole(
                      clubId: club.clubId,
                      userId: membership.userId,
                      actorUserId: _currentUser!.uid,
                      isOrganizer: !isOrganizer,
                    );
                  } else if (value == 'president') {
                    await _membershipService.assignPresident(
                      clubId: club.clubId,
                      oldPresidentId: club.presidentId,
                      newPresidentId: membership.userId,
                      newPresidentName: displayName,
                      actorUserId: _currentUser!.uid,
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'organizer',
                    child: Text(
                        isOrganizer ? 'Remove organizer' : 'Make organizer'),
                  ),
                  const PopupMenuItem(
                    value: 'president',
                    child: Text('Make president'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequests(ClubModel club) {
    return StreamBuilder<List<MembershipRequestModel>>(
      stream: _membershipService.getPendingRequests(club.clubId),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
        }
        if (requests.isEmpty) {
          return const Center(child: Text('No pending requests.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassPanel(
                padding: const EdgeInsets.all(16),
                borderRadius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppTheme.darkTextColor,
                      ),
                    ),
                    if ((request.message ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        request.message!,
                        style: const TextStyle(
                          color: AppTheme.secondaryColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                              side:
                                  const BorderSide(color: AppTheme.errorColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _respondToRequest(
                              request,
                              RequestStatus.rejected,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Approve'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _respondToRequest(
                              request,
                              RequestStatus.approved,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ClubHeroBanner extends StatelessWidget {
  final ClubModel club;

  const _ClubHeroBanner({required this.club});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(club.colorCode.replaceAll('#', '0xFF')));
    return Stack(
      fit: StackFit.expand,
      children: [
        if (club.bannerUrl.isNotEmpty)
          CachedRemoteImage(imageUrl: club.bannerUrl)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.95),
                  const Color(0xFF0F172A)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.70),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
            child: Text(
              club.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventStatusBadge extends StatelessWidget {
  final EventStatus status;

  const _EventStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      EventStatus.approved => (AppTheme.successColor, 'Approved'),
      EventStatus.rejected => (AppTheme.errorColor, 'Rejected'),
      EventStatus.draft => (AppTheme.secondaryColor, 'Draft'),
      EventStatus.pending => (AppTheme.warningColor, 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
