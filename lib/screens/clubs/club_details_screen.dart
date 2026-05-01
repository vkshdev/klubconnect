import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../models/club_model.dart';
import '../../models/event_model.dart';
import '../../models/membership_request_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/club_service.dart';
import '../../services/event_service.dart';
import '../../services/firestore_service.dart';
import '../../services/membership_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
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

  bool _isMember(ClubModel club) => _currentUser != null && club.members.contains(_currentUser!.uid);
  bool _isPresident(ClubModel club) => _currentUser != null && club.presidentId == _currentUser!.uid;
  bool _isOrganizer(ClubModel club) => _currentUser != null && club.organizers.contains(_currentUser!.uid);
  bool _isClubMaster(ClubModel club) => _currentUser != null && club.clubMasterId == _currentUser!.uid;
  bool _canManage(ClubModel club) => _isPresident(club) || _isClubMaster(club);
  bool _canCreateEvent(ClubModel club) => _canManage(club) || _isOrganizer(club);

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
        type: 'membership_request',
        title: 'New membership request',
        message: '${_currentUser!.fullName} requested to join ${club.name}.',
        fromUserId: _currentUser!.uid,
        relatedClubId: club.clubId,
      );
      if (club.clubMasterId != club.presidentId) {
        await _notificationService.sendNotification(
          userId: club.clubMasterId,
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
      type: status == RequestStatus.approved ? 'membership_approved' : 'membership_rejected',
      title: status == RequestStatus.approved ? 'Membership approved' : 'Membership rejected',
      message: status == RequestStatus.approved
          ? 'Your request to join ${request.clubName} was approved.'
          : 'Your request to join ${request.clubName} was rejected.',
      fromUserId: _currentUser!.uid,
      relatedClubId: request.clubId,
    );
    Fluttertoast.showToast(
      msg: status == RequestStatus.approved ? 'Request approved.' : 'Request rejected.',
    );
  }

  Future<void> _updateEventStatus(EventModel event, EventStatus status) async {
    await _eventService.updateEventStatus(event.eventId, status);
    await _notificationService.sendNotification(
      userId: event.createdById,
      type: status == EventStatus.approved ? 'event_approved' : 'event_rejected',
      title: status == EventStatus.approved ? 'Event approved' : 'Event rejected',
      message: '${event.title} was ${status == EventStatus.approved ? 'approved' : 'rejected'}.',
      relatedClubId: event.clubId,
      relatedEventId: event.eventId,
    );
    Fluttertoast.showToast(
      msg: status == EventStatus.approved ? 'Event approved.' : 'Event rejected.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClubModel?>(
      stream: _clubService.streamClub(widget.clubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _currentUser == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final club = snapshot.data;
        if (club == null) {
          return const Scaffold(body: Center(child: Text('Club not found.')));
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
            body: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  title: Text(club.name),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _ClubHero(club: club),
                  ),
                  bottom: TabBar(
                    tabs: tabs,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
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
          ),
        );
      },
    );
  }

  Widget _buildOverview(ClubModel club) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ClubLogo(club: club, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(club.category, style: TextStyle(color: Theme.of(context).primaryColor)),
                        Text(
                          '${club.totalMembers} members',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('Master: ${club.clubMasterName}'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(club.description),
              const SizedBox(height: 18),
              _buildMembershipAction(club),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Announcements',
                icon: Icons.campaign_outlined,
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
                child: CustomButton(
                  text: 'Create Event',
                  icon: Icons.add_circle_outline,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateEventScreen(club: club)),
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
      return const _StatusPill(label: 'Club Master', icon: Icons.workspace_premium_outlined);
    }
    if (_isPresident(club)) {
      return const _StatusPill(label: 'President', icon: Icons.verified_outlined);
    }
    if (_isOrganizer(club)) {
      return const _StatusPill(label: 'Organizer', icon: Icons.event_available_outlined);
    }
    if (_isMember(club)) {
      return CustomButton(
        text: 'Leave Club',
        icon: Icons.logout,
        backgroundColor: Colors.red.shade600,
        onPressed: () => _leaveClub(club),
      );
    }
    return StreamBuilder<MembershipRequestModel?>(
      stream: _membershipService.streamUserRequest(clubId: club.clubId, userId: _currentUser!.uid),
      builder: (context, snapshot) {
        final request = snapshot.data;
        if (request?.status == RequestStatus.pending) {
          return const _StatusPill(label: 'Request Pending', icon: Icons.hourglass_top_outlined);
        }
        return CustomButton(
          text: 'Request to Join',
          icon: Icons.person_add_alt_1,
          onPressed: () => _sendJoinRequest(club),
        );
      },
    );
  }

  Widget _buildEvents(ClubModel club) {
    return StreamBuilder<List<EventModel>>(
      stream: _eventService.getEventsByClub(club.clubId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final events = (snapshot.data ?? []).where((event) {
          return _canManage(club) || _isOrganizer(club) || event.status == EventStatus.approved;
        }).toList();
        if (events.isEmpty) return const Center(child: Text('No events yet.'));

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year} at ${event.eventTime}'),
                        trailing: _EventStatusChip(status: event.status),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => EventDetailsScreen(eventId: event.eventId)),
                        ),
                      ),
                      if (_isClubMaster(club) && event.status == EventStatus.pending) ...[
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close),
                                label: const Text('Reject'),
                                onPressed: () => _updateEventStatus(event, EventStatus.rejected),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text('Approve'),
                                onPressed: () => _updateEventStatus(event, EventStatus.approved),
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
          ),
        );
      },
    );
  }

  Widget _buildMembers(ClubModel club) {
    return StreamBuilder<List<UserModel>>(
      stream: _clubService.streamClubMembers(club.members),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (members.isEmpty) return const Center(child: Text('No members yet.'));
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final isPresident = club.presidentId == member.uid;
            final isOrganizer = club.organizers.contains(member.uid);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: member.profileImageUrl != null ? NetworkImage(member.profileImageUrl!) : null,
                    child: member.profileImageUrl == null && member.firstName.isNotEmpty
                        ? Text(member.firstName[0].toUpperCase())
                        : null,
                  ),
                  title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(isPresident ? 'President' : isOrganizer ? 'Organizer' : 'Member'),
                  trailing: _canManage(club) && !isPresident && member.uid != _currentUser?.uid
                      ? PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'organizer') {
                              await _membershipService.setOrganizerRole(
                                clubId: club.clubId,
                                userId: member.uid,
                                isOrganizer: !isOrganizer,
                              );
                            } else if (value == 'president') {
                              await _membershipService.assignPresident(
                                clubId: club.clubId,
                                oldPresidentId: club.presidentId,
                                newPresidentId: member.uid,
                                newPresidentName: member.fullName,
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'organizer',
                              child: Text(isOrganizer ? 'Remove organizer' : 'Make organizer'),
                            ),
                            const PopupMenuItem(
                              value: 'president',
                              child: Text('Make president'),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequests(ClubModel club) {
    return StreamBuilder<List<MembershipRequestModel>>(
      stream: _membershipService.getPendingRequests(club.clubId),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (requests.isEmpty) return const Center(child: Text('No pending requests.'));
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if ((request.message ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(request.message!),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                            onPressed: () => _respondToRequest(request, RequestStatus.rejected),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            onPressed: () => _respondToRequest(request, RequestStatus.approved),
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

class _ClubHero extends StatelessWidget {
  final ClubModel club;

  const _ClubHero({required this.club});

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(club.colorCode.replaceAll('#', '0xFF')));
    return Stack(
      fit: StackFit.expand,
      children: [
        if (club.bannerUrl.isNotEmpty)
          Image.network(club.bannerUrl, fit: BoxFit.cover)
        else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.95), const Color(0xFF111827)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        Container(color: Colors.black.withOpacity(0.28)),
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 64),
            child: Row(
              children: [
                _ClubLogo(club: club, size: 72),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    club.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClubLogo extends StatelessWidget {
  final ClubModel club;
  final double size;

  const _ClubLogo({required this.club, required this.size});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundImage: club.logoUrl.isNotEmpty ? NetworkImage(club.logoUrl) : null,
      child: club.logoUrl.isEmpty && club.name.isNotEmpty ? Text(club.name[0].toUpperCase()) : null,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatusPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EventStatusChip extends StatelessWidget {
  final EventStatus status;

  const _EventStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      EventStatus.approved => Colors.green,
      EventStatus.rejected => Colors.red,
      EventStatus.draft => Colors.grey,
      EventStatus.pending => Colors.orange,
    };
    return Chip(
      label: Text(status.name),
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}
