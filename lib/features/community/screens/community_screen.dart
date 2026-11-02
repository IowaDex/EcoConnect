import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../user/widgets/profile_sheet.dart';
import '../widgets/video_source.dart';

/// Barangay feed: residents post updates, photos and videos, then react,
/// comment and share.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  _Category _filter = _Category.all;

  final _posts = <_Post>[
    _Post(
      author: 'Barangay EcoConnect',
      time: '2 hours ago',
      body: 'Bring sorted plastics and paper. Tell your neighbors!',
      category: _Category.announcements,
      official: true,
      location: 'Sat · 8 AM · Barangay hall',
      reactions: {'👍': 12, '❤️': 3, '♻️': 5},
      comments: [
        _Comment('Marites D.', 'Sige po, dadalhin namin ang mga bote!'),
        _Comment('Jun P.', 'May plastic cups din po ba?'),
      ],
      shares: 3,
    ),
    _Post(
      author: 'Marites D.',
      time: '5 hours ago',
      body: 'Thank you to the crew who picked up the extra sacks along '
          'Sampaguita Street. Ang bilis ngayon!',
      category: _Category.questions,
      location: 'Sampaguita St.',
      reactions: {'👍': 18, '❤️': 6},
      comments: [_Comment('Jun P.', 'Buti pa kayo, samin mamaya pa.')],
      shares: 1,
    ),
    _Post(
      author: 'Jun P.',
      time: 'Yesterday',
      body: 'Does anyone know if the drop-off station still accepts old '
          'newspapers? I have two bundles to donate.',
      category: _Category.donations,
      reactions: {'👍': 9},
      shares: 0,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_Post> get _visiblePosts {
    final query = _searchController.text.trim().toLowerCase();
    return _posts.where((p) {
      final matchesFilter = _filter == _Category.all || p.category == _filter;
      final matchesQuery = query.isEmpty ||
          p.body.toLowerCase().contains(query) ||
          p.author.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  Future<void> _openComposer({bool pickImageFirst = false}) async {
    final post = await showModalBottomSheet<_Post>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ComposeSheet(pickImageFirst: pickImageFirst),
    );
    if (post == null) return;
    setState(() => _posts.insert(0, post));
  }

  void _react(_Post post, String emoji) {
    setState(() {
      final previous = post.myReaction;
      if (previous == emoji) {
        final left = (post.reactions[emoji] ?? 1) - 1;
        if (left <= 0) {
          post.reactions.remove(emoji);
        } else {
          post.reactions[emoji] = left;
        }
        post.myReaction = null;
        return;
      }
      if (previous != null) {
        final left = (post.reactions[previous] ?? 1) - 1;
        if (left <= 0) {
          post.reactions.remove(previous);
        } else {
          post.reactions[previous] = left;
        }
      }
      post.myReaction = emoji;
      post.reactions[emoji] = (post.reactions[emoji] ?? 0) + 1;
    });
  }

  Future<void> _share(_Post post) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _ShareSheet(),
    );
    if (choice == null || !mounted) return;

    final link = 'https://ecoconnect.app/community/${post.id}';
    await Clipboard.setData(
      ClipboardData(text: choice == 'link' ? link : post.body),
    );
    if (!mounted) return;
    setState(() => post.shares += 1);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(choice == 'link' ? 'Link copied' : 'Post copied'),
        ),
      );
  }

  Future<void> _openComments(_Post post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CommentsSheet(
        post: post,
        onAdd: (text) => setState(
          () => post.comments.add(_Comment('You', text)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final posts = _visiblePosts;

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
                  _SearchButton(
                    active: _searching,
                    onTap: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _searchController.clear();
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Community',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_searching) ...[
                    _SearchField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _FilterRow(
                    selected: _filter,
                    onSelect: (c) => setState(() => _filter = c),
                  ),
                  const SizedBox(height: 12),
                  _Composer(
                    name: user?.firstName ?? 'there',
                    onTap: () => _openComposer(),
                    onPickImage: () => _openComposer(pickImageFirst: true),
                  ),
                  const SizedBox(height: 14),
                  if (posts.isEmpty)
                    const _EmptyFeed()
                  else
                    for (final post in posts) ...[
                      _PostCard(
                        post: post,
                        onReact: (emoji) => _react(post, emoji),
                        onComment: () => _openComments(post),
                        onShare: () => _share(post),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
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
}

enum _Category { all, announcements, questions, donations }

extension on _Category {
  String get label => switch (this) {
        _Category.all => 'All',
        _Category.announcements => 'Announcements',
        _Category.questions => 'Questions',
        _Category.donations => 'Donations',
      };
}

class _Media {
  const _Media({this.imageBytes, this.video});

  final Uint8List? imageBytes;
  final XFile? video;

  bool get isVideo => video != null;
}

class _Comment {
  const _Comment(this.author, this.text);

  final String author;
  final String text;
}

class _Post {
  _Post({
    required this.author,
    required this.time,
    required this.body,
    required this.category,
    this.official = false,
    this.location,
    this.media,
    Map<String, int>? reactions,
    List<_Comment>? comments,
    this.shares = 0,
  })  : reactions = reactions ?? {},
        comments = comments ?? [];

  static int _nextId = 1000;

  final int id = _nextId++;
  final String author;
  final String time;
  final String body;
  final _Category category;
  final bool official;
  final String? location;
  final _Media? media;
  final Map<String, int> reactions;
  final List<_Comment> comments;
  int shares;
  String? myReaction;

  int get reactionTotal => reactions.values.fold(0, (a, b) => a + b);
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: active ? AppColors.forest : AppColors.mint,
          shape: BoxShape.circle,
        ),
        child: Icon(
          active ? Icons.close_rounded : Icons.search_rounded,
          size: 19,
          color: active ? AppColors.creamBright : AppColors.forest,
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12, color: AppColors.forest),
        decoration: const InputDecoration(
          hintText: 'Search posts or neighbors',
          hintStyle: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelect});

  final _Category selected;
  final ValueChanged<_Category> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _Category.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = _Category.values[i];
          final active = category == selected;
          return GestureDetector(
            onTap: () => onSelect(category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.forest : AppColors.cream,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: active
                      ? AppColors.forest
                      : AppColors.sage.withValues(alpha: 0.9),
                ),
              ),
              child: Text(
                category.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.creamBright : AppColors.forest,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.name,
    required this.onTap,
    required this.onPickImage,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 17,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AppColors.creamBright,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.sage.withValues(alpha: 0.9),
                  ),
                ),
                child: Text(
                  "What's on your mind, $name?",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onPickImage,
            child: const Padding(
              padding: EdgeInsets.all(7),
              child: Icon(
                Icons.photo_library_outlined,
                size: 20,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  const _PostCard({
    required this.post,
    required this.onReact,
    required this.onComment,
    required this.onShare,
  });

  final _Post post;
  final ValueChanged<String> onReact;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _pickerOpen = false;

  static const _emojis = ['👍', '❤️', '♻️', '😮', '😢'];

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor:
                    post.official ? AppColors.forest : AppColors.mint,
                child: Icon(
                  post.official ? Icons.campaign_rounded : Icons.person,
                  size: 17,
                  color: post.official
                      ? AppColors.creamBright
                      : AppColors.forest,
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
                            post.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                        if (post.official)
                          const Text(
                            ' · Official',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.moss,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      post.time,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.body,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: AppColors.forest,
            ),
          ),
          if (post.media != null) ...[
            const SizedBox(height: 12),
            _MediaBlock(media: post.media!, tag: post.location),
          ] else if (post.location != null) ...[
            const SizedBox(height: 10),
            _LocationPill(label: post.location!),
          ],
          const SizedBox(height: 12),
          _ReactionSummary(post: post, onComment: widget.onComment),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            color: AppColors.sage.withValues(alpha: 0.7),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: post.myReaction ?? '👍',
                      emoji: post.myReaction != null,
                      label: post.myReaction == null ? 'Like' : 'Reacted',
                      active: post.myReaction != null,
                      onTap: () => widget.onReact(post.myReaction ?? '👍'),
                      onLongPress: () =>
                          setState(() => _pickerOpen = !_pickerOpen),
                    ),
                  ),
                  Expanded(
                    child: _ActionButton(
                      icon: 'comment',
                      label: 'Comment',
                      onTap: widget.onComment,
                    ),
                  ),
                  Expanded(
                    child: _ActionButton(
                      icon: 'share',
                      label: 'Share',
                      onTap: widget.onShare,
                    ),
                  ),
                ],
              ),
              if (_pickerOpen)
                Positioned(
                  left: 0,
                  bottom: 40,
                  child: _ReactionBar(
                    emojis: _emojis,
                    selected: post.myReaction,
                    onPick: (emoji) {
                      widget.onReact(emoji);
                      setState(() => _pickerOpen = false);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.active = false,
    this.emoji = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool active;
  final bool emoji;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.forest : AppColors.inkMuted;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (emoji)
              Text(icon, style: const TextStyle(fontSize: 13))
            else
              Icon(
                icon == 'comment'
                    ? Icons.mode_comment_outlined
                    : Icons.share_outlined,
                size: 15,
                color: color,
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
    required this.emojis,
    required this.selected,
    required this.onPick,
  });

  final List<String> emojis;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sage),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final emoji in emojis)
            GestureDetector(
              onTap: () => onPick(emoji),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: selected == emoji
                      ? AppColors.mint
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 19)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReactionSummary extends StatelessWidget {
  const _ReactionSummary({required this.post, required this.onComment});

  final _Post post;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final entries = post.reactions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      children: [
        for (final entry in entries.take(3))
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Text(entry.key, style: const TextStyle(fontSize: 13)),
          ),
        if (post.reactionTotal > 0) ...[
          const SizedBox(width: 5),
          Text(
            '${post.reactionTotal}',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
        ],
        const Spacer(),
        GestureDetector(
          onTap: onComment,
          child: Text(
            '${post.comments.length} Comments',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
        ),
        const Text(
          ' · ',
          style: TextStyle(fontSize: 9, color: AppColors.inkMuted),
        ),
        Text(
          '${post.shares} shares',
          style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_rounded,
            size: 11,
            color: AppColors.creamBright,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: AppColors.creamBright,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaBlock extends StatelessWidget {
  const _MediaBlock({required this.media, this.tag});

  final _Media media;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          if (media.isVideo)
            _VideoView(file: media.video!)
          else
            Image.memory(
              media.imageBytes!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          if (tag != null)
            Positioned(
              left: 10,
              bottom: 10,
              child: _LocationPill(label: tag!),
            ),
        ],
      ),
    );
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.file});

  final XFile file;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = createVideoController(widget.file.path);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
    }).catchError((Object _) {
      if (mounted) setState(() => _ready = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(
        height: 200,
        color: AppColors.forest.withValues(alpha: 0.08),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.forest,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
            if (!_controller.value.isPlaying)
              Container(
                color: Colors.black.withValues(alpha: 0.18),
                child: Center(
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 24,
                      color: AppColors.creamBright,
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

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.forum_outlined, size: 30, color: AppColors.sage),
          SizedBox(height: 10),
          Text(
            'Nothing here yet. Start the conversation!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Share this post',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 14),
          _ShareOption(
            icon: Icons.link_rounded,
            label: 'Copy link',
            onTap: () => Navigator.of(context).pop('link'),
          ),
          const SizedBox(height: 10),
          _ShareOption(
            icon: Icons.content_copy_rounded,
            label: 'Copy post text',
            onTap: () => Navigator.of(context).pop('text'),
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.forest),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, required this.onAdd});

  final _Post post;
  final ValueChanged<String> onAdd;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    _controller.clear();
    setState(() {});
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final comments = widget.post.comments;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
              child: Text(
                '${comments.length} Comments',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
            ),
            Expanded(
              child: comments.isEmpty
                  ? const Center(
                      child: Text(
                        'No comments yet. Be the first to reply.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final comment = comments[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.mint,
                              child: Icon(
                                Icons.person,
                                size: 14,
                                color: AppColors.forest,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.author,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    comment.text,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.4,
                                      color: AppColors.forest,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.creamBright,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.sage.withValues(alpha: 0.9),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.forest,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.forest,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: AppColors.creamBright,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({this.pickImageFirst = false});

  final bool pickImageFirst;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  _Category _category = _Category.questions;
  _Media? _media;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.pickImageFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    var bytes = await picked.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null && decoded.width > 1080) {
      final resized = img.copyResize(decoded, width: 1080);
      bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 82));
    }
    if (!mounted) return;
    setState(() => _media = _Media(imageBytes: bytes));
  }

  Future<void> _pickVideo() async {
    setState(() => _busy = true);
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (picked != null) _media = _Media(video: picked);
    });
  }

  void _submit() {
    final text = _controller.text.trim();
    final media = _media;
    if (text.isEmpty && media == null) return;

    final kind = media != null && media.isVideo ? 'video' : 'photo';
    Navigator.of(context).pop(
      _Post(
        author: 'You',
        time: 'just now',
        body: text.isEmpty ? 'Shared a $kind' : text,
        category: _category,
        media: media,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'New post',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.creamBright,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.sage.withValues(alpha: 0.8),
                ),
              ),
              child: TextField(
                controller: _controller,
                autofocus: !widget.pickImageFirst,
                maxLines: 4,
                minLines: 2,
                style: const TextStyle(fontSize: 12, color: AppColors.forest),
                decoration: const InputDecoration(
                  hintText: 'Ask a question or share an update...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _Category.values.length - 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final category = _Category.values[i + 1];
                  final active = category == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            active ? AppColors.forest : AppColors.creamBright,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? AppColors.forest
                              : AppColors.sage.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Text(
                        category.label,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? AppColors.creamBright
                              : AppColors.forest,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_media != null) ...[
              const SizedBox(height: 12),
              _MediaPreview(
                media: _media!,
                onRemove: () => setState(() => _media = null),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _AttachButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Photo',
                  onTap: _busy ? null : _pickImage,
                ),
                const SizedBox(width: 8),
                _AttachButton(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  onTap: _busy ? null : _pickVideo,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Post',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.creamBright,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.9)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.forest),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.media, required this.onRemove});

  final _Media media;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: media.isVideo
              ? Container(
                  height: 140,
                  width: double.infinity,
                  color: AppColors.forest.withValues(alpha: 0.10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.movie_rounded,
                        size: 26,
                        color: AppColors.forest,
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          media.video!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Image.memory(
                  media.imageBytes!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              height: 26,
              width: 26,
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 15,
                color: AppColors.creamBright,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
