import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/club_model.dart';
import '../../models/user_model.dart';
import '../../services/club_service.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../widgets/cached_remote_image.dart';
import '../../widgets/screen_background.dart';
import '../home/search_screen.dart';
import '../../utils/app_snackbar.dart';
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
  String _selectedCategory = 'All';

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

  void _loadUser() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = FirestoreService();
    if (authService.currentUser != null) {
      final user =
          await firestoreService.getUserById(authService.currentUser!.uid);
      if (mounted) setState(() => _currentUser = user);
    }
  }

  Color _safeColor(String value) {
    try {
      return Color(int.parse(value.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final isFaculty = _currentUser!.userType == 'faculty';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          const ScreenBackground(),
          SafeArea(
            child: StreamBuilder<List<ClubModel>>(
              stream: _clubService.getClubsByCollege(
                _currentUser!.collegeName,
                institutionId: _currentUser!.institutionId,
              ),
              builder: (context, snapshot) {
                final allClubs = snapshot.data ?? [];
                final filteredClubs = _selectedCategory == 'All'
                    ? allClubs
                    : allClubs
                        .where((c) => c.category == _selectedCategory)
                        .toList();

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ScreenHeader(
                              title: 'College Clubs',
                              subtitle: _currentUser!.collegeName,
                              actions: [
                                IconGlassButton(
                                  icon: Icons.search_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SearchScreen(),
                                    ),
                                  ),
                                ),
                                if (isFaculty) ...[
                                  const SizedBox(width: 10),
                                  IconGlassButton(
                                    icon: Icons.add_rounded,
                                    iconColor: AppTheme.primaryColor,
                                    onTap: () {
                                      if (_currentUser?.isFacultyVerified !=
                                          true) {
                                        AppSnackBar.showWarning(
                                          context,
                                          'Faculty verification is required to create clubs.',
                                        );
                                        return;
                                      }
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const CreateClubScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildCategorySelector(),
                          ],
                        ),
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      )
                    else if (filteredClubs.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildEmptyState(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final club = filteredClubs[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _buildClubCard(club),
                              );
                            },
                            childCount: filteredClubs.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.secondaryColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
              selectedColor: AppTheme.primaryColor,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor.withValues(alpha: 0.8),
                ),
              ),
              onSelected: (_) => setState(() => _selectedCategory = category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClubCard(ClubModel club) {
    final color = _safeColor(club.colorCode);

    return GlassPanel(
      padding: EdgeInsets.zero,
      borderRadius: 22,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubDetailsScreen(clubId: club.clubId),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (club.bannerUrl.isNotEmpty)
            CachedRemoteImage(
              imageUrl: club.bannerUrl,
              height: 110,
              width: double.infinity,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withValues(alpha: 0.12),
                  backgroundImage: club.logoUrl.isNotEmpty
                      ? CachedNetworkImageProvider(club.logoUrl)
                      : null,
                  child: club.logoUrl.isEmpty && club.name.isNotEmpty
                      ? Text(
                          club.name[0].toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.darkTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
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
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppTheme.lightTextColor,
                  size: 15,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      child: Center(
        child: Column(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No clubs found',
              style: TextStyle(
                color: AppTheme.darkTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'There are no registered clubs in this category yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.secondaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
