import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/announcement_model.dart';
import '../../services/announcement_service.dart';
import '../../services/auth_service.dart';
import '../../services/club_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/glass_card.dart';
import 'package:intl/intl.dart';

class AnnouncementListScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  final bool canPost;

  const AnnouncementListScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    this.canPost = false,
  });

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  final ClubService _clubService = ClubService();
  final NotificationService _notificationService = NotificationService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isPosting = false;

  void _showPostAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isPosting ? null : _postAnnouncement,
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _postAnnouncement() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      return;
    }

    setState(() => _isPosting = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = FirestoreService();
    final user =
        await firestoreService.getUserById(authService.currentUser!.uid);

    if (user != null) {
      final announcement = AnnouncementModel(
        announcementId: '', // Service handles ID
        institutionId: user.institutionId,
        clubId: widget.clubId,
        clubName: widget.clubName,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        postedById: user.uid,
        postedByName: user.fullName,
        postedByRole: user.userType == 'faculty' ? 'Club Master' : 'President',
        createdAt: DateTime.now(),
      );

      await _announcementService.postAnnouncement(announcement);
      final club = await _clubService.getClubById(widget.clubId);
      if (club != null) {
        for (final memberId in club.members) {
          if (memberId == user.uid) continue;
          await _notificationService.sendNotification(
            userId: memberId,
            institutionId: user.institutionId,
            type: 'announcement',
            title: 'New announcement in ${widget.clubName}',
            message: _titleController.text.trim(),
            fromUserId: user.uid,
            relatedClubId: widget.clubId,
          );
        }
      }
      _titleController.clear();
      _contentController.clear();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement posted!')),
        );
      }
    }
    if (mounted) setState(() => _isPosting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          if (widget.canPost)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showPostAnnouncementDialog,
            ),
        ],
      ),
      body: StreamBuilder<List<AnnouncementModel>>(
        stream: _announcementService.streamClubAnnouncements(widget.clubId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }

          final announcements = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              announcement.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (announcement.isPinned)
                            const Icon(Icons.push_pin,
                                size: 16, color: Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(announcement.content),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'By ${announcement.postedByName} (${announcement.postedByRole})',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy')
                                .format(announcement.createdAt),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
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
      ),
    );
  }
}
