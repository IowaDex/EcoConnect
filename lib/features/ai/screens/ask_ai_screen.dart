import 'package:flutter/material.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_page.dart';

/// On-device assistant. Answers the questions residents ask most often; it
/// runs entirely locally, so it works without an API key or a network round
/// trip.
class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key});

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      'Hi! I\'m the EcoConnect assistant. Ask me about collection '
      'schedules, missed pickups, or waste segregation.',
      fromUser: false,
    ),
  ];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;

  /// Chips offered once the conversation has started. The welcome panel owns
  /// the full list of topics, so these stay short.
  static const _suggestions = [
    'Collection schedule',
    'Report a missed pickup',
    'How do I recycle?',
  ];

  static const _topics = <_Topic>[
    _Topic(
      icon: Icons.calendar_month_outlined,
      title: 'Collection day',
      hint: 'When is my street picked up?',
      prompt: 'When is my collection schedule?',
    ),
    _Topic(
      icon: Icons.report_gmailerrorred_outlined,
      title: 'Missed pickup',
      hint: 'Report an uncollected bin',
      prompt: 'How do I report a missed pickup?',
    ),
    _Topic(
      icon: Icons.recycling_rounded,
      title: 'Recycling',
      hint: 'What goes in the recyclables?',
      prompt: 'How do I recycle properly?',
    ),
    _Topic(
      icon: Icons.delete_sweep_outlined,
      title: 'Segregation',
      hint: 'Biodegradable vs the rest',
      prompt: 'How do I segregate my waste?',
    ),
    _Topic(
      icon: Icons.local_shipping_outlined,
      title: 'Track the truck',
      hint: 'Is the truck near me?',
      prompt: 'Where is the truck now?',
    ),
    _Topic(
      icon: Icons.verified_user_outlined,
      title: 'My account',
      hint: 'Email and ID verification',
      prompt: 'Why do I need to verify my account?',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _thinking) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text, fromUser: true));
      _thinking = true;
    });
    _scrollToEnd();

    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage(_answer(text), fromUser: false));
      _thinking = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: EcoMotion.base,
        curve: EcoMotion.enter,
      );
    });
  }

  String _answer(String input) {
    final q = input.toLowerCase();

    if (q.contains('schedule') ||
        q.contains('collection') ||
        q.contains('pickup') && q.contains('when') ||
        q.contains('what time')) {
      return 'Collection follows the route your barangay publishes. Today, '
          'Sector 4 is picked up at 2:30 PM. Open the Track tab to watch the '
          'truck move in real time.';
    }
    if (q.contains('missed') ||
        q.contains('report') ||
        q.contains('incident') ||
        q.contains('dumping') ||
        q.contains('full bin')) {
      return 'For a missed pickup, use Report uncollected to request a Wave 2 '
          'collection. For dumping or an overflowing bin, submit a complaint '
          'from the Complaints section.';
    }
    if (q.contains('recycl') ||
        q.contains('drop off') ||
        q.contains('drop-off')) {
      return 'Rinse and sort recyclables, then set them out on your street on '
          'collection day. Barangay staff collect them with the rest of the '
          "street's waste.";
    }
    if (q.contains('segregat') ||
        q.contains('biodegradable') ||
        q.contains('non-biodegradable') ||
        q.contains('sort')) {
      return 'Two bins: biodegradable for food scraps, leaves and soiled '
          'paper; non-biodegradable for plastic, glass and metal. Rinse '
          'containers so the batch stays clean.';
    }
    if (q.contains('track') || q.contains('truck') || q.contains('where')) {
      return 'Live truck positions are monitored by barangay staff. Residents '
          'receive collection and delay updates in Notifications.';
    }
    if (q.contains('account') ||
        q.contains('verify') ||
        q.contains('email') ||
        q.contains('login') ||
        q.contains('sign in')) {
      return 'Resident accounts need a verified email before the first login. '
          'If the message never arrived, check spam, then request a new link '
          'from the verification screen.';
    }
    if (q.contains('hello') ||
        q.contains('hi ') ||
        q == 'hi' ||
        q.contains('hey')) {
      return 'Hello! How can I help — schedules, a missed pickup, or waste '
          'segregation?';
    }
    if (q.contains('thank')) {
      return 'You\'re welcome. Thank you for keeping the barangay clean!';
    }

    return 'I can help with collection schedules, reporting a missed pickup, '
        'request tracking, and segregation tips. Try one of the suggestions '
        'below.';
  }

  @override
  Widget build(BuildContext context) {
    final fresh = _messages.length == 1 && !_thinking;
    return EcoPageScaffold(
      eyebrow: 'RESIDENT · ASSISTANT',
      title: 'Ask AI',
      subtitle:
          'Answers about collections, recycling and requests. Works '
          'without a connection.',
      icon: Icons.forum_rounded,
      onBack: () => Navigator.of(context).pop(),
      maxWidth: 720,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          Expanded(
            child: fresh
                ? _WelcomePanel(topics: _topics, onAsk: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    itemCount: _messages.length + (_thinking ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) return const _TypingBubble();
                      return _Bubble(message: _messages[i]);
                    },
                  ),
          ),
          if (!fresh) _SuggestionStrip(onAsk: _send, labels: _suggestions),
          _InputBar(controller: _controller, busy: _thinking, onSend: _send),
        ],
      ),
    );
  }
}

class _Topic {
  const _Topic({
    required this.icon,
    required this.title,
    required this.hint,
    required this.prompt,
  });

  final IconData icon;
  final String title;
  final String hint;
  final String prompt;
}

/// What the page shows before the first question: who is answering, and the
/// handful of things it can actually answer.
class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.topics, required this.onAsk});

  final List<_Topic> topics;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(EcoSpace.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.mint,
                  AppColors.mint.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(EcoRadius.lg),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BotMark(size: 40),
                const SizedBox(width: EcoSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, I\'m the EcoConnect assistant',
                        style: EcoType.panelTitle(
                          context,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'I answer from the barangay\'s own collection rules, '
                        'so I keep working even when the signal drops.',
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
          ),
          const SizedBox(height: EcoSpace.lg),
          const DeskSectionHeader(
            icon: Icons.auto_awesome_outlined,
            title: 'What I can help with',
          ),
          const SizedBox(height: EcoSpace.sm),
          for (var i = 0; i < topics.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: EcoSpace.xs),
              // IntrinsicHeight so a tile with a two-line hint does not leave
              // its neighbour short — the pair stays one even block.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _TopicTile(topic: topics[i], onAsk: onAsk),
                    ),
                    const SizedBox(width: EcoSpace.xs),
                    Expanded(
                      child: i + 1 < topics.length
                          ? _TopicTile(topic: topics[i + 1], onAsk: onAsk)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic, required this.onAsk});

  final _Topic topic;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: () => onAsk(topic.prompt),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(EcoRadius.sm),
            ),
            child: Icon(topic.icon, size: 15, color: AppColors.forest),
          ),
          const SizedBox(height: EcoSpace.xs),
          Text(
            topic.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EcoType.cardTitle(context, weight: FontWeight.w700),
          ),
          const SizedBox(height: 1),
          Text(
            topic.hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.meta(context, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _SuggestionStrip extends StatelessWidget {
  const _SuggestionStrip({required this.onAsk, required this.labels});

  final ValueChanged<String> onAsk;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        children: [
          ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 0, 28, 0),
            itemCount: labels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, i) => DeskFilterChip(
              label: labels[i],
              selected: false,
              onTap: () => onAsk(labels[i]),
            ),
          ),
          // The strip is wider than a phone; without the fade the last chip
          // looks sliced by the screen edge.
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 26,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.background.withValues(alpha: 0),
                      AppColors.background,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(EcoRadius.pill),
          border: Border.all(color: AppColors.sage),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: EcoType.body(context, color: AppColors.forest),
                decoration: InputDecoration(
                  hintText: 'Ask about collections, recycling…',
                  hintStyle: EcoType.body(context, color: AppColors.inkMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final ready = value.text.trim().isNotEmpty && !busy;
                return GestureDetector(
                  onTap: ready ? onSend : null,
                  child: AnimatedContainer(
                    duration: EcoMotion.fast,
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: ready ? AppColors.forest : AppColors.sage,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 18,
                      color: ready ? Colors.white : AppColors.inkMuted,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BotMark extends StatelessWidget {
  const _BotMark({this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(
        gradient: AppColors.forestGradient,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.eco_rounded, size: size * 0.5, color: Colors.white),
    );
  }
}

class _ChatMessage {
  const _ChatMessage(this.text, {required this.fromUser});

  final String text;
  final bool fromUser;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.sm),
      child: Row(
        mainAxisAlignment: fromUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!fromUser) ...[
            const _BotMark(),
            const SizedBox(width: EcoSpace.xs),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
              decoration: BoxDecoration(
                color: fromUser ? AppColors.forest : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(fromUser ? EcoRadius.md : 4),
                  topRight: Radius.circular(fromUser ? 4 : EcoRadius.md),
                  bottomLeft: const Radius.circular(EcoRadius.md),
                  bottomRight: const Radius.circular(EcoRadius.md),
                ),
                border: fromUser
                    ? null
                    : Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
              ),
              child: Text(
                message.text,
                style: EcoType.body(
                  context,
                  color: fromUser ? Colors.white : AppColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.sm),
      child: Row(
        children: [
          const _BotMark(),
          const SizedBox(width: EcoSpace.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(EcoRadius.md),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
            ),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    _Dot(
                      // Each dot lags the one before it, so the three read as
                      // a wave rather than a blink.
                      value: ((_pulse.value + i * 0.18) % 1.0),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final lift = (value < 0.5 ? value : 1 - value) * 2;
    return Transform.translate(
      offset: Offset(0, -2 * lift),
      child: Container(
        height: 5,
        width: 5,
        decoration: BoxDecoration(
          color: AppColors.forest.withValues(alpha: 0.35 + 0.5 * lift),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
