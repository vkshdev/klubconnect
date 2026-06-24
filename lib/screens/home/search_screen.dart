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
import '../../widgets/glass_card.dart';
import '../clubs/club_details_screen.dart';
import '../events/event_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _clubService = ClubService();
  final _eventService = EventService();

  UserModel? _currentUser;
  String _query = '';
  String _selectedFilter = 'Clubs';
  String _selectedCategory = 'All';

  static const _filters = ['Clubs', 'Events', 'Users'];
  static const _categories = [
    'All',
    'Technical',
    'Cultural',
    'Sports',
    'Entrepreneurship',
    'Literary',
    'Social Impact',
    'Arts',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final uid = authService.currentUser?.uid;
    if (uid == null) return;
    final user = await _firestoreService.getUserById(uid);
    if (mounted) setState(() => _currentUser = user);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFF6FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context)),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        borderRadius: 20,
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Search clubs, events, or users',
                            border: InputBorder.none,
                            icon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildFilters(),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ..._filters.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter),
                selected: _selectedFilter == filter,
                onSelected: (_) => setState(() => _selectedFilter = filter),
              ),
            );
          }),
          if (_selectedFilter == 'Clubs')
            DropdownButton<String>(
              value: _selectedCategory,
              items: _categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedCategory = value ?? 'All'),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_query.trim().isEmpty) {
      return Center(
        child: Text(
          'Start typing to search ${_currentUser!.collegeName}.',
          style: TextStyle(color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_selectedFilter == 'Clubs') {
      return StreamBuilder<List<ClubModel>>(
        stream: _clubService.searchClubs(
          collegeName: _currentUser!.collegeName,
          institutionId: _currentUser!.institutionId,
          query: _query,
          category: _selectedCategory,
        ),
        builder: (context, snapshot) =>
            _buildClubResults(snapshot.data ?? [], snapshot.connectionState),
      );
    }

    if (_selectedFilter == 'Events') {
      return StreamBuilder<List<EventModel>>(
        stream: _eventService.searchEvents(
          collegeName: _currentUser!.collegeName,
          institutionId: _currentUser!.institutionId,
          query: _query,
          status: EventStatus.approved,
        ),
        builder: (context, snapshot) =>
            _buildEventResults(snapshot.data ?? [], snapshot.connectionState),
      );
    }

    return StreamBuilder<List<UserModel>>(
      stream: _firestoreService.searchUsersByCollege(
        collegeName: _currentUser!.collegeName,
        institutionId: _currentUser!.institutionId,
        query: _query,
      ),
      builder: (context, snapshot) =>
          _buildUserResults(snapshot.data ?? [], snapshot.connectionState),
    );
  }

  Widget _buildClubResults(List<ClubModel> clubs, ConnectionState state) {
    if (state == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (clubs.isEmpty) return const Center(child: Text('No matching clubs.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: clubs.length,
      itemBuilder: (context, index) {
        final club = clubs[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: club.logoUrl.isNotEmpty
                    ? CachedNetworkImageProvider(club.logoUrl)
                    : null,
                child: club.logoUrl.isEmpty && club.name.isNotEmpty
                    ? Text(club.name[0])
                    : null,
              ),
              title: Text(club.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(club.category),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ClubDetailsScreen(clubId: club.clubId)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventResults(List<EventModel> events, ConnectionState state) {
    if (state == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events.isEmpty) return const Center(child: Text('No matching events.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(event.title,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(event.clubName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        EventDetailsScreen(eventId: event.eventId)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserResults(List<UserModel> users, ConnectionState state) {
    if (state == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) return const Center(child: Text('No matching users.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: user.profileImageUrl != null
                    ? CachedNetworkImageProvider(user.profileImageUrl!)
                    : null,
                child: user.profileImageUrl == null && user.firstName.isNotEmpty
                    ? Text(user.firstName[0])
                    : null,
              ),
              title: Text(user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(user.userType),
            ),
          ),
        );
      },
    );
  }
}
