import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../announcements/models/announcement.dart';
import '../../announcements/services/announcement_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/role_top_bar.dart';
import '../../events/models/community_event.dart';
import '../../events/services/event_service.dart';
import '../../user/widgets/profile_sheet.dart';
import '../models/community_post.dart';
import '../services/community_post_service.dart';

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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RoleTopBar(
                  actions: [
                    _HeaderAction(
                      icon: Icons.edit_outlined,
                      onTap: _openComposer,
                    ),
                  ],
                ),
                const EcoPageHeader(
                  eyebrow: 'RESIDENT · COMMUNITY',
                  title: 'Community',
                  subtitle:
                      'Announcements, events and updates from your '
                      'barangay.',
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 12),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: DeskSegmented<CommunitySection>(
                    value: _section,
                    onChanged: (section) => setState(() => _section = section),
                    segments: [
                      for (final section in CommunitySection.values)
                        DeskSegment<CommunitySection>(
                          value: section,
                          label: section.label,
                          icon: section.icon,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: EcoSpace.md),
                Expanded(
                  child: Stack(
                    children: [
                      _body(),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: NavScrim(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        onTap: (i) {
          switch (i) {
            case 0:
              context.go('/user');
            case 1:
              context.go('/my-requests');
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
    return Tooltip(
      message: 'Write a post',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        hoverColor: AppColors.lightGreen,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 19, color: AppColors.inkMuted),
        ),
      ),
    );
  }
}

/// Shared footer for every feed card, so the "open" affordance always sits in
/// the same place: lower right, after whatever facts the card carries.
class _CardFooter extends StatelessWidget {
  const _CardFooter({this.leading});

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Expanded rather than a bare child: DeskFact flexes its own text, and
        // a flex inside an unbounded Row throws.
        Expanded(child: leading ?? const SizedBox.shrink()),
        const SizedBox(width: EcoSpace.xs),
        Text(
          'Read more',
          style: EcoType.label(context, color: AppColors.primary),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 15,
          color: AppColors.primary,
        ),
      ],
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
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonCardList(count: 3),
          );
        }
        if (snapshot.hasError) {
          return DeskEmptyQueue(
            icon: Icons.cloud_off_rounded,
            title: 'Announcements are not loading',
            message: AppFeedback.describe(snapshot.error!),
          );
        }
        final items = snapshot.data ?? const <Announcement>[];
        if (items.isEmpty) {
          return const DeskEmptyQueue(
            icon: Icons.campaign_outlined,
            title: 'No announcements yet',
            message:
                'Barangay announcements will appear here as soon as they '
                'are published.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24 + NavScrim.height),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: EcoSpace.sm),
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
      backgroundColor: AppColors.creamBright,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
          children: [
            // No handle of our own: the theme's bottomSheetTheme already draws
            // one, and a second bar under it read as a stray line.
            Row(
              children: [
                StatusBadge(
                  label: item.category.label,
                  color: item.category.color,
                  icon: item.category.icon,
                  compact: true,
                ),
                const Spacer(),
                Text(
                  timeAgo(item.publishAt ?? item.createdAt),
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: EcoSpace.md),
            Text(
              item.title,
              style: EcoType.panelTitle(context, color: AppColors.darkGreen),
            ),
            const SizedBox(height: EcoSpace.xs),
            Text(
              '${item.authorName ?? 'Barangay staff'} · '
              '${dateTimeLabel(item.publishAt ?? item.createdAt)}',
              style: EcoType.meta(context, color: AppColors.inkMuted),
            ),
            if (item.image != null) ...[
              const SizedBox(height: EcoSpace.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(EcoRadius.md),
                child: Image.memory(
                  _bytes(item.image!.dataUrl),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: EcoSpace.md),
            Text(
              item.body,
              style: EcoType.body(context, color: AppColors.textDark),
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
    return DeskRailCard(
      railColor: announcement.category.color,
      onTap: onTap,
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
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (announcement.image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(EcoRadius.sm),
                  child: Image.memory(
                    _bytes(announcement.image!.dataUrl),
                    height: 58,
                    width: 58,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: EcoSpace.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.cardTitle(context),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      announcement.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.bodySmall(
                        context,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          _CardFooter(
            leading: DeskFact(
              icon: Icons.verified_outlined,
              text: announcement.authorName ?? 'Barangay staff',
              color: AppColors.inkMuted,
            ),
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
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonCardList(count: 3),
          );
        }
        if (snapshot.hasError) {
          return DeskEmptyQueue(
            icon: Icons.cloud_off_rounded,
            title: 'Events are not loading',
            message: AppFeedback.describe(snapshot.error!),
          );
        }
        final items = snapshot.data ?? const <CommunityEvent>[];
        if (items.isEmpty) {
          return const DeskEmptyQueue(
            icon: Icons.event_outlined,
            title: 'No events scheduled',
            message: 'Clean-up drives and collection days will show up here.',
          );
        }
        final upcoming = items.where((e) => !e.isCompleted).toList();
        final past = items.where((e) => e.isCompleted).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24 + NavScrim.height),
          children: [
            if (upcoming.isNotEmpty) ...[
              DeskSectionHeader(
                icon: Icons.event_available_outlined,
                title: 'Coming up',
                count: upcoming.length,
              ),
              const SizedBox(height: EcoSpace.sm),
              for (final event in upcoming) ...[
                _EventCard(event: event),
                const SizedBox(height: EcoSpace.sm),
              ],
            ],
            if (past.isNotEmpty) ...[
              const SizedBox(height: EcoSpace.sm),
              DeskSectionHeader(
                icon: Icons.history_rounded,
                title: 'Past events',
                count: past.length,
              ),
              const SizedBox(height: EcoSpace.sm),
              for (final event in past) ...[
                _EventCard(event: event, muted: true),
                const SizedBox(height: EcoSpace.sm),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, this.muted = false});

  final CommunityEvent event;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ongoing =
        !event.isCompleted && event.startAt.isBefore(DateTime.now());
    final accent = muted
        ? AppColors.inkMuted
        : ongoing
        ? AppColors.warning
        : AppColors.primary;

    return DeskRailCard(
      railColor: accent,
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
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(date: event.startAt, muted: muted),
              const SizedBox(width: EcoSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.cardTitle(context),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.bodySmall(
                        context,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    DeskFact(
                      icon: Icons.place_outlined,
                      text: event.location,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(height: 3),
                    DeskFact(
                      icon: Icons.schedule_rounded,
                      text: timeLabel(event.startAt),
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!muted) ...[
            const SizedBox(height: EcoSpace.xs),
            const _CardFooter(),
          ],
        ],
      ),
    );
  }
}

/// Month over day, the way a calendar page reads at a glance.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, this.muted = false});

  final DateTime date;
  final bool muted;

  static const _months = [
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
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final ink = muted ? AppColors.inkMuted : AppColors.forest;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: muted ? AppColors.cream : AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.sm),
      ),
      child: Column(
        children: [
          Text(
            _months[date.month - 1],
            style: EcoType.eyebrow(context, color: ink),
          ),
          const SizedBox(height: 1),
          Text('${date.day}', style: EcoType.metricValue(context, color: ink)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Posts
// ---------------------------------------------------------------------------

class _PostsTab extends StatefulWidget {
  const _PostsTab({required this.service, required this.onCompose});

  final CommunityPostService service;
  final VoidCallback onCompose;

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  int _page = 0;
  int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final service = widget.service;
    return StreamBuilder<List<CommunityPost>>(
      stream: service.watchFeed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonCardList(count: 3),
          );
        }
        if (snapshot.hasError) {
          return DeskEmptyQueue(
            icon: Icons.cloud_off_rounded,
            title: 'Posts are not loading',
            message: AppFeedback.describe(snapshot.error!),
          );
        }
        final posts = snapshot.data ?? const <CommunityPost>[];
        final page = clampPage(_page, posts.length, _pageSize);
        final visible = pageSlice(posts, page, _pageSize);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24 + NavScrim.height),
          children: [
            _ComposerBar(
              name: user?.firstName ?? 'there',
              onTap: widget.onCompose,
            ),
            const SizedBox(height: EcoSpace.md),
            if (posts.isEmpty)
              DeskEmptyQueue(
                icon: Icons.forum_outlined,
                title: 'No posts yet',
                message:
                    'Share a photo or a quick update with your '
                    'neighbors. Everything you post stays inside your '
                    'barangay.',
                actionLabel: 'Write the first post',
                onAction: widget.onCompose,
              )
            else
              for (final post in visible) ...[
                _PostCard(
                  post: post,
                  currentUserId: user?.uid,
                  onTap: () => context.push('/community-post/${post.id}'),
                  onLike: () => _toggleLike(context, post),
                ),
                const SizedBox(height: EcoSpace.sm),
              ],
            if (posts.isNotEmpty)
              EcoPaginationBar(
                page: page,
                pageSize: _pageSize,
                total: posts.length,
                onPageChanged: (next) => setState(() => _page = next),
                onPageSizeChanged: (size) => setState(() {
                  _pageSize = size;
                  _page = 0;
                }),
              ),
          ],
        );
      },
    );
  }

  Future<void> _toggleLike(BuildContext context, CommunityPost post) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    try {
      await widget.service.toggleLike(post: post, userId: user.uid);
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
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Row(
        children: [
          DeskInitialAvatar(name: name, size: 34),
          const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share something, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.cardTitle(context),
                ),
                const SizedBox(height: 1),
                Text(
                  'A photo, a heads-up, a thank you',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: EcoSpace.xs),
          Container(
            height: 32,
            width: 32,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_rounded,
              size: 15,
              color: AppColors.forest,
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
    final staff = post.isStaffPost;
    return DeskRailCard(
      railColor: staff ? AppColors.forest : AppColors.sage,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(17, 13, 13, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DeskInitialAvatar(
                name: post.authorName,
                size: 32,
                tint: staff ? AppColors.mint : null,
              ),
              const SizedBox(width: EcoSpace.sm),
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
                            style: EcoType.cardTitle(context),
                          ),
                        ),
                        if (staff) ...[
                          const SizedBox(width: 5),
                          const _StaffTag(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      timeAgo(post.createdAt),
                      style: EcoType.meta(context, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Text(
            post.body,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            style: EcoType.body(context, color: AppColors.textDark),
          ),
          if (post.image != null) ...[
            const SizedBox(height: EcoSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(EcoRadius.md),
              child: Image.memory(
                _bytes(post.image!.dataUrl),
                width: double.infinity,
                height: 176,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: EcoSpace.sm),
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
              const SizedBox(width: EcoSpace.md),
              _PostAction(
                icon: Icons.mode_comment_outlined,
                label: '${post.commentCount}',
                onTap: onTap,
              ),
              const Spacer(),
              Text(
                'Read more',
                style: EcoType.label(context, color: AppColors.primary),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffTag extends StatelessWidget {
  const _StaffTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, size: 8, color: AppColors.forest),
          const SizedBox(width: 3),
          Text(
            'Barangay',
            style: EcoType.micro(context, color: AppColors.forest),
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
      borderRadius: BorderRadius.circular(EcoRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label, style: EcoType.label(context, color: color)),
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
      padding: EdgeInsets.fromLTRB(20, 4, 20, viewInsets + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'New community post',
                style: EcoType.panelTitle(context, color: AppColors.darkGreen),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
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
          const SizedBox(height: EcoSpace.md),
          ImagePickerField(
            value: _image,
            label: 'Add a photo (optional)',
            helper: 'JPG, PNG or WebP',
            previewHeight: 120,
            onChanged: (value) => setState(() => _image = value),
          ),
          const SizedBox(height: EcoSpace.md),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: () {
                final text = _body.text.trim();
                if (text.isEmpty) {
                  AppFeedback.error(context, 'Write something first.');
                  return;
                }
                Navigator.of(
                  context,
                ).pop(_PostDraft(body: text, image: _image));
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
