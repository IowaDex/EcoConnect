import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

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
      'schedules, missed pickups, or your recycling points.',
      fromUser: false,
    ),
  ];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _thinking = false;

  static const _suggestions = [
    'Collection schedule',
    'Report a missed pickup',
    'How do I earn points?',
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
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
      return 'Tap Report an incident on the home screen. Describe what you '
          'saw, attach the exact spot, and your barangay reviews every '
          'report.';
    }
    if (q.contains('point') ||
        q.contains('wallet') ||
        q.contains('recycl') ||
        q.contains('drop off') ||
        q.contains('drop-off')) {
      return 'Bring sorted recyclables to the barangay drop-off station. '
          'Staff weigh them and credit points straight to your recycling '
          'wallet — you can open it from the home screen.';
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
      return 'The Track tab shows the collector assigned to your area, the '
          'stops on the route, and how far away the truck is right now.';
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
    if (q.contains('hello') || q.contains('hi ') || q == 'hi' || q.contains('hey')) {
      return 'Hello! How can I help — schedules, a missed pickup, or your '
          'recycling points?';
    }
    if (q.contains('thank')) {
      return 'You\'re welcome. Salamat for keeping the barangay clean!';
    }

    return 'I can help with collection schedules, reporting a missed pickup, '
        'your recycling points, and segregation tips. Try one of the '
        'suggestions below.';
  }

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
              padding: const EdgeInsets.fromLTRB(14, 10, 22, 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    height: 32,
                    width: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.forest,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.forum_rounded,
                      size: 16,
                      color: AppColors.creamBright,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask AI',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                      Text(
                        'EcoConnect assistant',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
                itemCount: _messages.length + (_thinking ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) return const _TypingBubble();
                  return _Bubble(message: _messages[i]);
                },
              ),
            ),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final label = _suggestions[i];
                  return GestureDetector(
                    onTap: () => _send(label),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.mint.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: AppColors.forest.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.sage.withValues(alpha: 0.9),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.forest,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ask about collections, points...',
                          hintStyle: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.inkMuted,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      height: 46,
                      width: 46,
                      decoration: const BoxDecoration(
                        color: AppColors.forest,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 19,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!fromUser) ...[
            Container(
              height: 26,
              width: 26,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_rounded,
                size: 14,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: fromUser ? AppColors.forest : AppColors.cream,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(fromUser ? 16 : 4),
                  bottomRight: Radius.circular(fromUser ? 4 : 16),
                ),
                border: fromUser
                    ? null
                    : Border.all(
                        color: AppColors.sage.withValues(alpha: 0.8),
                      ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.45,
                  color: fromUser ? AppColors.creamBright : AppColors.forest,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            height: 26,
            width: 26,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco_rounded,
              size: 14,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
            ),
            child: const Text(
              '...',
              style: TextStyle(
                fontSize: 11.5,
                height: 1,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
