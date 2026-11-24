import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/memo_service.dart';
import '../widgets/memo_widgets.dart';

/// Compose a memo, endorsement, announcement or manual request.
///
/// The destinations depend on who is writing: City Hall can reach Iswim and the
/// barangay, Iswim and the barangay write back to City Hall. Pass [memoId] to
/// edit a memo that has not been received yet.
class MemoComposeScreen extends StatefulWidget {
  const MemoComposeScreen({
    super.key,
    this.initialKind,
    this.initialChannel,
    this.memoId,
  });

  final MemoKind? initialKind;
  final String? initialChannel;

  /// Set when the author is correcting an existing memo.
  final String? memoId;

  @override
  State<MemoComposeScreen> createState() => _MemoComposeScreenState();
}

class _MemoComposeScreenState extends State<MemoComposeScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();

  late MemoKind _kind = widget.initialKind ?? MemoKind.memo;
  String _channel = 'cityHall';
  UploadPayload? _attachment;

  bool _resolved = false;
  bool _loading = false;
  bool _busy = false;

  bool get _editing => widget.memoId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    _resolved = true;

    final role = context.read<AuthProvider>().currentUser?.role;
    final channels = _channelsFor(role);
    // A memo is never addressed to the office that writes it, so the default
    // is the first desk this role may actually reach.
    _channel = channels.any((c) => c.value == widget.initialChannel)
        ? widget.initialChannel!
        : channels.first.value;

    if (_editing) _load();
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  List<({String value, String label})> _channelsFor(UserRole? role) =>
      switch (role) {
        UserRole.cityHall => const [
          (value: 'iswim', label: 'Iswim'),
          (value: 'barangay', label: 'Barangay'),
        ],
        UserRole.iswim => const [(value: 'cityHall', label: 'City Hall')],
        UserRole.admin => const [(value: 'cityHall', label: 'City Hall')],
        _ => const [(value: 'cityHall', label: 'City Hall')],
      };

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final memo = await MemoService().watchOne(widget.memoId!).first;
      if (!mounted) return;
      if (memo == null) {
        AppFeedback.error(context, 'This memo no longer exists.');
        context.pop();
        return;
      }
      setState(() {
        _kind = memo.kind;
        _channel = memo.toChannel;
        _subject.text = memo.subject;
        _body.text = memo.body;
        _attachment = memo.attachment;
      });
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    // A double tap in the same frame would otherwise file the memo twice.
    if (_busy) return;
    final subject = _subject.text.trim();
    final body = _body.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      AppFeedback.error(context, 'Subject and body are required');
      return;
    }

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      AppFeedback.error(context, 'You are not signed in.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (_editing) {
        await MemoService().updateContent(
          id: widget.memoId!,
          subject: subject,
          body: body,
          attachment: _attachment,
        );
      } else {
        await MemoService().send(
          kind: _kind,
          subject: subject,
          body: body,
          fromUid: user.uid,
          fromName: user.displayName ?? user.role.label,
          fromRole: _roleKey(user.role),
          toChannel: _channel,
          attachment: _attachment,
        );
      }
      if (!mounted) return;
      AppFeedback.success(context, _editing ? 'Memo updated' : 'Memo sent');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _roleKey(UserRole role) => switch (role) {
    UserRole.cityHall => 'cityHall',
    UserRole.iswim => 'iswim',
    _ => 'barangay',
  };

  @override
  Widget build(BuildContext context) {
    final channels = _channelsFor(
      context.watch<AuthProvider>().currentUser?.role,
    );

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                AppPageHeader(
                  eyebrow: 'MEMO DESK · COMPOSE',
                  title: _editing ? 'Edit memo' : 'New memo',
                  subtitle: _editing
                      ? 'Correct the details before the receiving desk opens it.'
                      : 'Pick a document type, then write the message.',
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: _loading
                      ? const LoadingView(label: 'Loading memo')
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
                          children: [
                            if (_editing)
                              const FadeSlideIn(
                                index: 0,
                                child: EcoNote(
                                  message:
                                      'This memo has not been received yet, so it can still be corrected.',
                                ),
                              )
                            else ...[
                              FadeSlideIn(
                                index: 0,
                                child: _KindPicker(
                                  selected: _kind,
                                  onChanged: (kind) =>
                                      setState(() => _kind = kind),
                                ),
                              ),
                              AnimatedSize(
                                duration: EcoMotion.base,
                                curve: EcoMotion.enter,
                                alignment: Alignment.topCenter,
                                child: _kind == MemoKind.announcement
                                    ? const _AnnouncementNote()
                                    : const SizedBox(width: double.infinity),
                              ),
                              const SizedBox(height: EcoSpace.lg),
                              FadeSlideIn(
                                index: 1,
                                child: _RecipientPicker(
                                  channels: channels,
                                  selected: _channel,
                                  onChanged: (value) =>
                                      setState(() => _channel = value),
                                ),
                              ),
                            ],
                            const SizedBox(height: EcoSpace.lg),
                            FadeSlideIn(
                              index: 2,
                              child: EcoCard(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SectionHeader(
                                      title: 'Message',
                                      subtitle:
                                          'The receiving desk reads exactly what you write here.',
                                    ),
                                    const SizedBox(height: EcoSpace.sm + 2),
                                    ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: _subject,
                                      builder: (context, value, _) => TextField(
                                        controller: _subject,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        textInputAction: TextInputAction.next,
                                        decoration: InputDecoration(
                                          labelText: 'Subject',
                                          hintText: 'What is this about?',
                                          fillColor: AppColors.creamBright,
                                          counterText: value.text.trim().isEmpty
                                              ? null
                                              : '${value.text.trim().length} characters',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: EcoSpace.sm + 2),
                                    ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: _body,
                                      builder: (context, value, _) => TextField(
                                        controller: _body,
                                        minLines: 5,
                                        maxLines: 12,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        decoration: InputDecoration(
                                          labelText: 'Body',
                                          hintText:
                                              'Write the details the receiving desk needs.',
                                          alignLabelWithHint: true,
                                          fillColor: AppColors.creamBright,
                                          counterText: value.text.trim().isEmpty
                                              ? null
                                              : '${value.text.trim().length} characters',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: EcoSpace.md),
                            FadeSlideIn(
                              index: 3,
                              child: EcoCard(
                                padding: const EdgeInsets.all(EcoSpace.md),
                                child: ImagePickerField(
                                  value: _attachment,
                                  onChanged: (value) =>
                                      setState(() => _attachment = value),
                                  label: 'Attachment',
                                  helper:
                                      'Optional · JPG, PNG or PDF up to 600 KB',
                                  documentMode: true,
                                  previewHeight: 100,
                                  enabled: !_busy,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                if (!_loading)
                  _SendBar(
                    subject: _subject,
                    body: _body,
                    busy: _busy,
                    editing: _editing,
                    onSend: _send,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Four document types, each with a plain-language explanation.
class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.selected, required this.onChanged});

  final MemoKind selected;
  final ValueChanged<MemoKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('DOCUMENT TYPE'),
        const SizedBox(height: EcoSpace.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - EcoSpace.sm) / 2;
            return Wrap(
              spacing: EcoSpace.sm,
              runSpacing: EcoSpace.sm,
              children: [
                for (final kind in MemoKind.values)
                  SizedBox(
                    width: width,
                    height: 104,
                    child: _KindOption(
                      kind: kind,
                      selected: selected == kind,
                      onTap: () => onChanged(kind),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final MemoKind kind;
  final bool selected;
  final VoidCallback onTap;

  static IconData _iconFor(MemoKind kind) => switch (kind) {
    MemoKind.memo => Icons.sticky_note_2_outlined,
    MemoKind.endorsement => Icons.forward_to_inbox_rounded,
    MemoKind.announcement => Icons.campaign_outlined,
    MemoKind.manualRequest => Icons.menu_book_outlined,
  };

  static String _blurbFor(MemoKind kind) => switch (kind) {
    MemoKind.memo => 'A formal note to another desk.',
    MemoKind.endorsement => 'Forward a case for approval.',
    MemoKind.announcement => 'A circular for the whole office.',
    MemoKind.manualRequest => 'Request a manual or reference.',
  };

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.forest;

    return HoverLift(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EcoRadius.md),
          child: AnimatedContainer(
            duration: EcoMotion.fast,
            curve: EcoMotion.enter,
            padding: const EdgeInsets.all(EcoSpace.sm + 2),
            decoration: BoxDecoration(
              color: selected ? AppColors.forest : Colors.white,
              borderRadius: BorderRadius.circular(EcoRadius.md),
              border: Border.all(
                color: selected ? AppColors.forest : AppColors.sage,
                width: selected ? 1.4 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.forest.withValues(alpha: 0.20),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.16)
                            : AppColors.mint,
                        borderRadius: BorderRadius.circular(EcoRadius.sm),
                      ),
                      child: Icon(
                        _iconFor(kind),
                        size: 16,
                        color: selected ? Colors.white : AppColors.forest,
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: EcoMotion.fast,
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 15,
                        color: AppColors.lime,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  kind.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _blurbFor(kind),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8.8,
                    height: 1.35,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.74)
                        : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the memo goes. With one reachable desk this is a statement, not a
/// choice; with two, the cards become selectable.
class _RecipientPicker extends StatelessWidget {
  const _RecipientPicker({
    required this.channels,
    required this.selected,
    required this.onChanged,
  });

  final List<({String value, String label})> channels;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final single = channels.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('SEND TO'),
        const SizedBox(height: EcoSpace.sm),
        for (var i = 0; i < channels.length; i++) ...[
          _RecipientCard(
            label: channels[i].label,
            detail: single
                ? 'The only desk this account can address.'
                : 'Delivered to the ${channels[i].label} desk.',
            selected: selected == channels[i].value,
            onTap: single ? null : () => onChanged(channels[i].value),
          ),
          if (i < channels.length - 1) const SizedBox(height: EcoSpace.xs),
        ],
      ],
    );
  }
}

class _RecipientCard extends StatelessWidget {
  const _RecipientCard({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: EcoMotion.fast,
      curve: EcoMotion.enter,
      padding: const EdgeInsets.all(EcoSpace.sm + 2),
      decoration: BoxDecoration(
        color: selected ? AppColors.mint : Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.sage,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.cream,
              borderRadius: BorderRadius.circular(EcoRadius.sm),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: 17,
              color: selected ? Colors.white : AppColors.forest,
            ),
          ),
          const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    height: 1.35,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: AppColors.primary,
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return HoverLift(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EcoRadius.md),
          child: content,
        ),
      ),
    );
  }
}

class _AnnouncementNote extends StatelessWidget {
  const _AnnouncementNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: EcoSpace.sm),
      padding: const EdgeInsets.all(EcoSpace.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_outlined, size: 16, color: AppColors.forest),
          SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Text(
              'Iswim announcements are also emailed to the District Officer '
              'automatically (recorded in the City Hall email log).',
              style: TextStyle(
                fontSize: 10,
                height: 1.45,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The action bar stays pinned so the primary action is always in reach.
class _SendBar extends StatelessWidget {
  const _SendBar({
    required this.subject,
    required this.body,
    required this.busy,
    required this.editing,
    required this.onSend,
  });

  final TextEditingController subject;
  final TextEditingController body;
  final bool busy;
  final bool editing;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        border: Border(
          top: BorderSide(color: AppColors.sage.withValues(alpha: 0.6)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([subject, body]),
        builder: (context, _) {
          final ready =
              subject.text.trim().isNotEmpty && body.text.trim().isNotEmpty;
          final caption = busy
              ? 'Sending your memo…'
              : ready
              ? (editing ? 'Ready to save' : 'Ready to send')
              : 'Add a subject and body to send';

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: EcoMotion.fast,
                child: Row(
                  key: ValueKey('$ready-$busy'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      busy
                          ? Icons.outbox_rounded
                          : ready
                          ? Icons.check_circle_outline_rounded
                          : Icons.edit_note_rounded,
                      size: 13,
                      color: ready ? AppColors.moss : AppColors.inkMuted,
                    ),
                    const SizedBox(width: EcoSpace.xs),
                    Text(
                      caption,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: ready ? AppColors.moss : AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: EcoSpace.xs),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: ready && !busy ? onSend : null,
                  icon: busy
                      ? const SizedBox(
                          height: 17,
                          width: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 17),
                  label: Text(
                    busy
                        ? 'Sending…'
                        : (editing ? 'Save changes' : 'Send memo'),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    disabledBackgroundColor: AppColors.sage,
                    disabledForegroundColor: AppColors.inkMuted,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EcoRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Inbox and sent history of memos for one desk.
/// The two lists a memo desk works through.
enum _MemoTab { inbox, sent }

class MemoInboxScreen extends StatefulWidget {
  const MemoInboxScreen({
    super.key,
    required this.channel,
    required this.title,
  });

  final String channel;
  final String title;

  @override
  State<MemoInboxScreen> createState() => _MemoInboxScreenState();
}

class _MemoInboxScreenState extends State<MemoInboxScreen> {
  _MemoTab _tab = _MemoTab.inbox;
  int _page = 0;
  int _pageSize = 10;

  final _search = TextEditingController();
  String _query = '';

  // Cached so switching tabs (or any rebuild) does not resubscribe to
  // Firestore and flash the loading state.
  Stream<List<Memo>>? _inbox;
  Stream<List<Memo>>? _sent;
  String? _streamKey;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Keeps the memos a desk clerk can find by typing what they remember.
  List<Memo> _filter(List<Memo> memos) {
    if (_query.trim().isEmpty) return memos;
    return memos.where((memo) => memoMatchesQuery(memo, _query)).toList();
  }

  void _clearSearch() {
    _search.clear();
    setState(() {
      _query = '';
      _page = 0;
    });
  }

  void _switchTab(_MemoTab tab) {
    if (tab == _tab) return;
    // A query typed for the inbox should not silently hide the outbox.
    _search.clear();
    setState(() {
      _tab = tab;
      _query = '';
      _page = 0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.watch<AuthProvider>().currentUser;
    final key = '${widget.channel}:${user?.uid}:${user?.role.name}';
    if (key == _streamKey) return;
    _streamKey = key;
    _inbox = MemoService().watchForChannel(widget.channel);
    _sent = user == null
        ? null
        : MemoService().watchSentByDesk(_roleKey(user.role));
  }

  /// The desk the inbox belongs to, so the page says where you are once.
  String get _eyebrow => switch (widget.channel) {
    'iswim' => 'ISWIM · MEMO DESK',
    'barangay' => 'BARANGAY · MEMO DESK',
    _ => 'CITY HALL · MEMO DESK',
  };

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final inboxTab = _tab == _MemoTab.inbox;

    return EcoPageScaffold(
      eyebrow: _eyebrow,
      title: widget.title,
      icon: Icons.mail_outline_rounded,
      subtitle: inboxTab
          ? 'Memos addressed to this desk, newest first.'
          : 'Everything this desk has sent, with its delivery status.',
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          // The inbox is opened from three different consoles, so go back to
          // the caller's own home.
          final role = context.read<AuthProvider>().currentUser?.role;
          context.go(switch (role) {
            UserRole.iswim => '/iswim',
            UserRole.admin => '/admin-dashboard',
            _ => '/cityhall',
          });
        }
      },
      actions: [
        if (user != null)
          _ComposeAction(
            onTap: () => context.push(
              '/memos/new?channel=${_composeChannel(user.role)}',
            ),
          ),
      ],
      body: StreamBuilder<List<Memo>>(
        stream: _inbox,
        builder: (context, inboxSnap) {
          return StreamBuilder<List<Memo>>(
            stream: _sent,
            builder: (context, sentSnap) {
              final inbox = inboxSnap.data ?? const <Memo>[];
              final sent = sentSnap.data ?? const <Memo>[];
              final snapshot = inboxTab ? inboxSnap : sentSnap;
              final source = inboxTab ? inbox : sent;
              final visible = _filter(source);
              final page = clampPage(_page, visible.length, _pageSize);
              final paged = pageSlice(visible, page, _pageSize);

              final awaiting = inbox.where((memo) => !memo.isSigned).length;
              final acknowledged = sent.where((memo) => memo.isSigned).length;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: DeskSegmented<_MemoTab>(
                      value: _tab,
                      onChanged: _switchTab,
                      segments: [
                        DeskSegment(
                          value: _MemoTab.inbox,
                          label: 'Inbox',
                          icon: Icons.inbox_rounded,
                          count: inbox.length,
                        ),
                        DeskSegment(
                          value: _MemoTab.sent,
                          label: 'Sent',
                          icon: Icons.send_rounded,
                          count: sent.length,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: snapshot.hasError
                        ? EmptyState(
                            icon: Icons.cloud_off_rounded,
                            title: 'Could not load memos',
                            message: AppFeedback.describe(snapshot.error!),
                          )
                        : !snapshot.hasData
                        ? const EcoLoadingView(label: 'Loading memos')
                        : DeskQueueView(
                            metrics: inboxTab
                                ? [
                                    DeskMetric(
                                      icon: Icons.mark_email_unread_rounded,
                                      label: 'Awaiting',
                                      value: '$awaiting',
                                      accent: AppColors.warning,
                                      highlight: awaiting > 0,
                                    ),
                                    DeskMetric(
                                      icon: Icons.verified_rounded,
                                      label: 'Signed',
                                      value: '${inbox.length - awaiting}',
                                    ),
                                    DeskMetric(
                                      icon: Icons.inbox_rounded,
                                      label: 'Total',
                                      value: '${inbox.length}',
                                    ),
                                  ]
                                : [
                                    DeskMetric(
                                      icon: Icons.done_all_rounded,
                                      label: 'Acknowledged',
                                      value: '$acknowledged',
                                    ),
                                    DeskMetric(
                                      icon: Icons.hourglass_empty_rounded,
                                      label: 'Waiting',
                                      value: '${sent.length - acknowledged}',
                                      accent: AppColors.warning,
                                    ),
                                    DeskMetric(
                                      icon: Icons.send_rounded,
                                      label: 'Sent',
                                      value: '${sent.length}',
                                    ),
                                  ],
                            search: EcoSearchField(
                              controller: _search,
                              hint: inboxTab
                                  ? 'Search subject, sender or kind'
                                  : 'Search subject, recipient or kind',
                              onChanged: (value) => setState(() {
                                _query = value;
                                _page = 0;
                              }),
                            ),
                            resultLine: DeskResultLine(
                              label: _query.trim().isEmpty
                                  ? '${visible.length} '
                                        '${visible.length == 1 ? 'memo' : 'memos'}'
                                  : 'Showing ${visible.length} of '
                                        '${source.length}',
                              onClear: _query.trim().isEmpty
                                  ? null
                                  : _clearSearch,
                            ),
                            empty: source.isEmpty
                                ? DeskEmptyQueue(
                                    icon: Icons.mail_outline_rounded,
                                    title: inboxTab
                                        ? 'No memos in the inbox'
                                        : 'Nothing sent yet',
                                    message: inboxTab
                                        ? 'Memos addressed to this desk appear '
                                              'here in real time.'
                                        : 'Memos sent from this desk are '
                                              'listed here with their status.',
                                    steps: const [
                                      'A desk composes the memo',
                                      'It lands in the receiving inbox',
                                      'Signing it closes the record',
                                    ],
                                    actionLabel: inboxTab
                                        ? null
                                        : 'Compose a memo',
                                    actionIcon: Icons.edit_note_rounded,
                                    onAction: inboxTab || user == null
                                        ? null
                                        : () => context.push(
                                            '/memos/new?channel='
                                            '${_composeChannel(user.role)}',
                                          ),
                                  )
                                : DeskEmptyQueue(
                                    icon: Icons.search_off_rounded,
                                    title: 'No memo matches',
                                    message:
                                        'Nothing in this desk mentions '
                                        '"${_query.trim()}". Try a shorter '
                                        'word, a name or a kind.',
                                    actionLabel: 'Clear search',
                                    actionIcon: Icons.search_off_rounded,
                                    onAction: _clearSearch,
                                  ),
                            itemCount: paged.length,
                            itemBuilder: (context, i) => FadeSlideIn(
                              index: i > 6 ? 6 : i,
                              offset: 10,
                              child: MemoCard(
                                memo: paged[i],
                                needsAction: inboxTab && !paged[i].isSigned,
                              ),
                            ),
                            pagination: visible.isEmpty
                                ? null
                                : EcoPaginationBar(
                                    page: page,
                                    pageSize: _pageSize,
                                    total: visible.length,
                                    onPageChanged: (next) =>
                                        setState(() => _page = next),
                                    onPageSizeChanged: (size) => setState(() {
                                      _pageSize = size;
                                      _page = 0;
                                    }),
                                  ),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// A memo is never addressed to the desk that writes it, so City Hall
  /// writes to the inbox it is reading when that inbox belongs to another
  /// desk, and to Iswim otherwise.
  String _composeChannel(UserRole role) {
    if (role == UserRole.cityHall) {
      return widget.channel == 'barangay' ? 'barangay' : 'iswim';
    }
    return 'cityHall';
  }

  static String _roleKey(UserRole role) => switch (role) {
    UserRole.cityHall => 'cityHall',
    UserRole.iswim => 'iswim',
    _ => 'barangay',
  };
}

/// The compose action in the page header.
///
/// A header pill rather than a floating button: the FAB sat on top of the
/// pagination bar and forced every list to reserve 96px of empty space.
class _ComposeAction extends StatelessWidget {
  const _ComposeAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.edit_note_rounded, size: 16),
        label: const Text(
          'Compose',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// Small inline note used by the edit form.
class EcoNote extends StatelessWidget {
  const EcoNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
