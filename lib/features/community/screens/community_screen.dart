import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../announcements/models/announcement.dart';
import '../../announcements/services/announcement_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../events/models/community_event.dart';
import '../../events/services/event_service.dart';
import '../../user/widgets/profile_sheet.dart';
import '../models/community_post.dart';
import '../services/community_post_service.dart';
import '../../notifications/widgets/notification_bell.dart';

enum CommunitySection { announcements, events, posts }

extension on CommunitySection {
  String get label => switch (this) {
        CommunitySection.announcements => 'Announcements',
        CommunitySection.events => 'Events',
        CommunitySection.posts => 'Posts',
      };

  IconData get icon => switch (this) {
        CommunitySection.announcements => Icons.campaign_outlined,
        CommunitySection.events => Icons.event_outlined,
        CommunitySection.posts => Icons.forum_outlined,
      };
}

/// Barangay feed with three sections: official announcements, community
/// events and resident posts. Everything streams from Firestore, so a post
/// made on another phone appears here without refreshing.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  CommunitySection _section = CommunitySection.announcements;

  final _announcements = AnnouncementService();
  final _events = EventService();
  final _posts = CommunityPostService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 18, 4),
              child: Row(
                children: [
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  const NotificationBell(
                    iconSize: 19,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  _HeaderAction(
                    icon: Icons.edit_outlined,
                    onTap: _openComposer,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community',
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Announcements, events and updates from your barangay.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _SectionTabs(
              selected: _section,
              onSelect: (section) => setState(() => _section = section),
            ),
            const SizedBox(height: 12),
            Expanded(child: _body()),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/user');
            case 1:
              context.go('/tracking');
            case 2:
              break;
            case 3:
              showProfileSheet(context);
          }
        },
        onAskAi: () => context.push('/ask-ai'),
      ),
    );
  }

  Widget _body() {
    switch (_section) {
      case CommunitySection.announcements:
        return _AnnouncementsTab(service: _announcements);
      case CommunitySection.events:
        return _EventsTab(service: _events);
      case CommunitySection.posts:
        return _PostsTab(service: _posts, onCompose: _openComposer);
    }
  }

  Future<void> _openComposer() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final draft = await showModalBottomSheet<_PostDraft>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _ComposerSheet(),
    );
    if (draft == null || !mounted) return;
    try {
      await _posts.create(
        authorId: user.uid,
        authorName: user.displayName ?? 'Neighbor',
        authorRole: user.role.name,
        body: draft.body,
        image: draft.image,
      );
      if (!mounted) return;
      setState(() => _section = CommunitySection.posts);
      AppFeedback.success(context, 'Posted to the community');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 19, color: AppColors.inkMuted),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selected, required this.onSelect});

  final CommunitySection selected;
  final ValueChanged<CommunitySection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            for (final section in CommunitySection.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(section),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: selected == section
                          ? AppColors.forest
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          section.icon,
                          size: 14,
                          color: selected == section
                              ? AppColors.creamBright
                              : AppColors.inkMuted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            section.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: selected == section
                                  ? AppColors.creamBright
                                  : AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Announcements
// ---------------------------------------------------------------------------

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab({required this.service});

  final AnnouncementService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: service.watchPublished(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(label: 'Loading announcements');
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              AppFeedback.describe(snapshot.error!),
              style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
            ),
          );
        }
        final items = snapshot.data ?? const <Announcement>[];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.campaign_outlined,
            title: 'No announcements yet',
            message:
                'Barangay announcements will appear here as soon as they are published.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _AnnouncementCard(
            announcement: items[i],
            onTap: () => _openAnnouncement(context, items[i]),
          ),
        );
      },
    );
  }

  void _openAnnouncement(BuildContext context, Announcement item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
          children: [
            StatusBadge(
              label: item.category.label,
              color: item.category.color,
              icon: item.category.icon,
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${item.authorName ?? 'Barangay staff'} · '
              '${dateTimeLabel(item.publishAt ?? item.createdAt)}',
              style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
            ),
            if (item.image != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  _bytes(item.image!.dataUrl),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              item.body,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.65,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement, required this.onTap});

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: announcement.category.shortLabel,
                color: announcement.category.color,
                icon: announcement.category.icon,
                compact: true,
              ),
              const Spacer(),
              Text(
                timeAgo(announcement.publishAt ?? announcement.createdAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (announcement.image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.memory(
                    _bytes(announcement.image!.dataUrl),
                    height: 62,
                    width: 62,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      announcement.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.45,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

class _EventsTab extends StatelessWidget {
  const _EventsTab({required this.service});

  final EventService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityEvent>>(
      stream: service.watchPublished(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(label: 'Loading events');
        }
        final items = snapshot.data ?? const <CommunityEvent>[];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.event_outlined,
            title: 'No events scheduled',
            message: 'Clean-up drives and collection days will show up here.',
          );
        }
        final upcoming = items.where((e) => !e.isCompleted).toList();
        final past = items.where((e) => e.isCompleted).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            if (upcoming.isNotEmpty) ...[
              const _GroupLabel('UPCOMING & ONGOING'),
              const SizedBox(height: 8),
              for (final event in upcoming) ...[
                _EventCard(event: event),
                const SizedBox(height: 12),
              ],
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: 6),
              const _GroupLabel('PAST EVENTS'),
              const SizedBox(height: 8),
              for (final event in past) ...[
                _EventCard(event: event, muted: true),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: AppColors.inkMuted,
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.muted = false});

  final CommunityEvent event;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ongoing = !event.isCompleted && event.startAt.isBefore(now);
    return EcoCard(
      padding: const EdgeInsets.all(14),
      color: muted ? AppColors.cream : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: ongoing ? 'Happening now' : event.category.label,
                color: ongoing ? AppColors.warning : event.category.color,
                icon: ongoing ? Icons.bolt_rounded : event.category.icon,
                compact: true,
              ),
              const Spacer(),
              Text(
                dateLabel(event.startAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            event.title,
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            event.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const Icon(Icons.schedule_rounded,
                  size: 12, color: AppColors.inkMuted),
              const SizedBox(width: 4),
              Text(
                timeLabel(event.startAt),
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Posts
// ---------------------------------------------------------------------------

class _PostsTab extends StatelessWidget {
  const _PostsTab({required this.service, required this.onCompose});

  final CommunityPostService service;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return StreamBuilder<List<CommunityPost>>(
      stream: service.watchFeed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(label: 'Loading community posts');
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              AppFeedback.describe(snapshot.error!),
              style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
            ),
          );
        }
        final posts = snapshot.data ?? const <CommunityPost>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            _ComposerBar(name: user?.firstName ?? 'there', onTap: onCompose),
            const SizedBox(height: 14),
            if (posts.isEmpty)
              const EmptyState(
                icon: Icons.forum_outlined,
                title: 'No posts yet',
                message: 'Share a photo or a quick update with your neighbors.',
                compact: true,
              ),
            for (final post in posts) ...[
              _PostCard(
                post: post,
                currentUserId: user?.uid,
                onTap: () => context.push('/community-post/${post.id}'),
                onLike: () => _toggleLike(context, post),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Future<void> _toggleLike(BuildContext context, CommunityPost post) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    try {
      await service.toggleLike(post: post, userId: user.uid);
    } catch (e) {
      if (context.mounted) {
        AppFeedback.error(context, AppFeedback.describe(e));
      }
    }
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_outlined,
                size: 15, color: AppColors.forest),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Share something with your barangay, $name…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.onTap,
    required this.onLike,
  });

  final CommunityPost post;
  final String? currentUserId;
  final VoidCallback onTap;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final initial = post.authorName.trim().isEmpty
        ? '?'
        : post.authorName.trim()[0].toUpperCase();
    return EcoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (post.isStaffPost) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.mint,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text(
                              'Barangay',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      timeAgo(post.createdAt),
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.body,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.55,
              color: AppColors.textDark,
            ),
          ),
          if (post.image != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _bytes(post.image!.dataUrl),
                width: double.infinity,
                height: 170,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              _PostAction(
                icon: post.likedByUser(currentUserId)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${post.likeCount}',
                active: post.likedByUser(currentUserId),
                onTap: onLike,
              ),
              const SizedBox(width: 16),
              _PostAction(
                icon: Icons.mode_comment_outlined,
                label: '${post.commentCount}',
                onTap: onTap,
              ),
              const Spacer(),
              const Text(
                'Read more',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.error : AppColors.inkMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostDraft {
  const _PostDraft({required this.body, this.image});

  final String body;
  final UploadPayload? image;
}

class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet();

  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final _body = TextEditingController();
  UploadPayload? _image;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, viewInsets + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'New community post',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What is happening in your barangay?',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          ImagePickerField(
            value: _image,
            label: 'Add a photo (optional)',
            helper: 'JPG, PNG or WebP',
            previewHeight: 120,
            onChanged: (value) => setState(() => _image = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: () {
                final text = _body.text.trim();
                if (text.isEmpty) {
                  AppFeedback.error(context, 'Write something first.');
                  return;
                }
                Navigator.of(context).pop(
                  _PostDraft(body: text, image: _image),
                );
              },
              child: const Text('Post to community'),
            ),
          ),
        ],
      ),
    );
  }
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}
