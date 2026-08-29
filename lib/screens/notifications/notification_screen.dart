import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../widgets/screen_background.dart';
import '../clubs/club_details_screen.dart';
import '../events/event_details_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  String _filter = 'All'; // 'All' | 'Unread'

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view notifications.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          const ScreenBackground(),
          SafeArea(
            child: StreamBuilder<List<NotificationModel>>(
              stream: _notificationService.streamNotifications(userId),
              builder: (context, snapshot) {
                final allNotifications = snapshot.data ?? [];
                final unreadCount =
                    allNotifications.where((n) => !n.isRead).length;

                final displayedNotifications = _filter == 'Unread'
                    ? allNotifications.where((n) => !n.isRead).toList()
                    : allNotifications;

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ScreenHeader(
                              title: 'Notifications',
                              subtitle: unreadCount > 0
                                  ? '$unreadCount unread updates'
                                  : 'Activity & Updates',
                              actions: [
                                if (unreadCount > 0)
                                  IconGlassButton(
                                    icon: Icons.done_all_rounded,
                                    iconColor: AppTheme.primaryColor,
                                    onTap: () => _notificationService
                                        .markAllAsRead(userId),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildFilterChip('All', allNotifications.length),
                                const SizedBox(width: 8),
                                _buildFilterChip('Unread', unreadCount),
                              ],
                            ),
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
                    else if (displayedNotifications.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildEmptyState(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final notification =
                                  displayedNotifications[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _NotificationCard(
                                  notification: notification,
                                  onTap: () {
                                    _notificationService.markAsRead(
                                      notification.notificationId,
                                    );
                                    _openNotification(notification);
                                  },
                                ),
                              );
                            },
                            childCount: displayedNotifications.length,
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

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.borderColor.withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.24),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.darkTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppTheme.secondaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.secondaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
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
                Icons.notifications_none_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'All caught up!',
              style: TextStyle(
                color: AppTheme.darkTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No new notifications or alerts for your account.',
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

  void _openNotification(NotificationModel notification) {
    if (notification.relatedEventId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              EventDetailsScreen(eventId: notification.relatedEventId!),
        ),
      );
      return;
    }
    if (notification.relatedClubId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ClubDetailsScreen(clubId: notification.relatedClubId!),
        ),
      );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _getNotificationMeta(notification.type);

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      borderRadius: 18,
      border: !notification.isRead
          ? Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.4),
              width: 1.4,
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(meta.icon, color: meta.color, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.darkTextColor,
                          fontSize: 14,
                          fontWeight: notification.isRead
                              ? FontWeight.w700
                              : FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(notification.createdAt),
                      style: const TextStyle(
                        color: AppTheme.lightTextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: notification.isRead
                        ? AppTheme.secondaryColor
                        : AppTheme.darkTextColor,
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: notification.isRead
                        ? FontWeight.w500
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!notification.isRead) ...[
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 8,
              width: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  _NotificationMeta _getNotificationMeta(String type) {
    switch (type) {
      case 'membership_request':
        return const _NotificationMeta(
          icon: Icons.person_add_alt_1_rounded,
          color: AppTheme.primaryColor,
        );
      case 'membership_approved':
        return const _NotificationMeta(
          icon: Icons.verified_rounded,
          color: AppTheme.successColor,
        );
      case 'event_approved':
        return const _NotificationMeta(
          icon: Icons.event_available_rounded,
          color: AppTheme.accentColor,
        );
      case 'announcement':
        return const _NotificationMeta(
          icon: Icons.campaign_rounded,
          color: Color(0xFF8B5CF6),
        );
      default:
        return const _NotificationMeta(
          icon: Icons.notifications_rounded,
          color: AppTheme.primaryColor,
        );
    }
  }
}

class _NotificationMeta {
  final IconData icon;
  final Color color;

  const _NotificationMeta({required this.icon, required this.color});
}
