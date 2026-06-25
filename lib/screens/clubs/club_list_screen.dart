import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/club_model.dart';
import '../../models/user_model.dart';
import '../../services/club_service.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/cached_remote_image.dart';
import '../../widgets/glass_card.dart';
import 'club_details_screen.dart';
import 'create_club_screen.dart';

class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});

  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  final _clubService = ClubService();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = FirestoreService();
    if (authService.currentUser != null) {
      final user =
          await firestoreService.getUserById(authService.currentUser!.uid);
      if (mounted) setState(() => _currentUser = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs'),
        actions: [
          if (_currentUser!.userType == 'faculty')
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CreateClubScreen()),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<ClubModel>>(
        stream: _clubService.getClubsByCollege(
          _currentUser!.collegeName,
          institutionId: _currentUser!.institutionId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No clubs found in your college.'));
          }

          final clubs = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ClubDetailsScreen(clubId: club.clubId),
                    ),
                  ),
                  child: GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (club.bannerUrl.isNotEmpty)
                          CachedRemoteImage(
                            imageUrl: club.bannerUrl,
                            height: 120,
                            width: double.infinity,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: club.logoUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(club.logoUrl)
                                    : null,
                                child: club.logoUrl.isEmpty
                                    ? Text(club.name[0])
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
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      club.category,
                                      style: TextStyle(
                                          color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${club.totalMembers} Members',
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
