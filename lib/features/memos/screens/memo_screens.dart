import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/motion.dart';
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
    final channels = _channelsFor(context.watch<AuthProvider>().currentUser?.role);

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _editing ? 'Edit memo' : 'New memo',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              children: [
                if (_editing)
                  const EcoNote(
                    message:
                        'This memo has not been received yet, so it can still be corrected.',
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final kind in MemoKind.values)
                        ChoiceChip(
                          label: Text(kind.label),
                          selected: _kind == kind,
                          onSelected: (_) => setState(() => _kind = kind),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final channel in channels)
                        ChoiceChip(
                          label: Text('To ${channel.label}'),
                          selected: _channel == channel.value,
                          onSelected: (_) =>
                              setState(() => _channel = channel.value),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _subject,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _body,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Body',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                ImagePickerField(
                  value: _attachment,
                  onChanged: (value) => setState(() => _attachment = value),
                  label: 'Attachment (optional)',
                  helper: 'JPG, PNG or PDF · up to 600 KB',
                  documentMode: true,
                  previewHeight: 130,
                  enabled: !_busy,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _busy ? null : _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_editing ? 'Save changes' : 'Send'),
                  ),
                ),
                if (_kind == MemoKind.announcement && !_editing) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Iswim announcements are also emailed to the District Officer '
                    'automatically (recorded in the City Hall email log).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Inbox and sent history of memos for one desk.
class MemoInboxScreen extends StatefulWidget {
  const MemoInboxScreen({super.key, required this.channel, required this.title});

  final String channel;
  final String title;

  @override
  State<MemoInboxScreen> createState() => _MemoInboxScreenState();
}

class _MemoInboxScreenState extends State<MemoInboxScreen> {
  int _tab = 0;

  // Cached so switching tabs (or any rebuild) does not resubscribe to
  // Firestore and flash the loading state.
  Stream<List<Memo>>? _inbox;
  Stream<List<Memo>>? _sent;
  String? _streamKey;

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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/cityhall');
            }
          },
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(
                '/memos/new?channel=${_composeChannel(user.role)}',
              ),
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text(
                'Compose',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
            child: Row(
              children: [
                _tabButton(0, 'Inbox'),
                const SizedBox(width: 8),
                _tabButton(1, 'Sent'),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _MemoList(
                    stream: _inbox!,
                    emptyTitle: 'No memos in the inbox',
                    emptyMessage:
                        'Memos addressed to this desk appear here in real time.',
                  )
                : _MemoList(
                    stream: _sent ??
                        const Stream<List<Memo>>.empty(),
                    emptyTitle: 'Nothing sent yet',
                    emptyMessage:
                        'Memos sent from this desk are listed here with their '
                        'status.',
                  ),
          ),
        ],
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

  Widget _tabButton(int item, String label) {
    final selected = item == _tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.forest : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.sage,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoList extends StatelessWidget {
  const _MemoList({
    required this.stream,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final Stream<List<Memo>> stream;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Memo>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                AppFeedback.describe(snapshot.error!),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10.5, color: AppColors.error),
              ),
            ),
          );
        }
        final memos = snapshot.data ?? const <Memo>[];
        if (memos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mail_outline_rounded,
                      size: 40, color: AppColors.sage),
                  const SizedBox(height: 12),
                  Text(
                    emptyTitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
          itemCount: memos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (context, i) => FadeSlideIn(
            index: i,
            offset: 10,
            child: MemoCard(memo: memos[i]),
          ),
        );
      },
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
          const Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 9.5,
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
