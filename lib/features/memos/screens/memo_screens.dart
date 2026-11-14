import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/memo_service.dart';

/// Compose a memo, endorsement, announcement or manual request.
///
/// The destinations depend on who is writing: City Hall can reach Iswim and the
/// barangay, Iswim and the barangay write back to City Hall.
class MemoComposeScreen extends StatefulWidget {
  const MemoComposeScreen({super.key, this.initialKind, this.initialChannel});

  final MemoKind? initialKind;
  final String? initialChannel;

  @override
  State<MemoComposeScreen> createState() => _MemoComposeScreenState();
}

class _MemoComposeScreenState extends State<MemoComposeScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _picker = ImagePicker();

  late MemoKind _kind = widget.initialKind ?? MemoKind.memo;
  late String _channel = widget.initialChannel ?? 'cityHall';
  String? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  List<({String value, String label})> get _channels {
    final role = context.read<AuthProvider>().currentUser?.role;
    return switch (role) {
      UserRole.cityHall => const [
          (value: 'iswim', label: 'Iswim'),
          (value: 'barangay', label: 'Barangay'),
        ],
      UserRole.iswim => const [(value: 'cityHall', label: 'City Hall')],
      UserRole.admin => const [(value: 'cityHall', label: 'City Hall')],
      _ => const [(value: 'cityHall', label: 'City Hall')],
    };
  }

  Future<void> _attach() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final payload = await UploadCodec.image(bytes, fileName: file.name);
      if (mounted) setState(() => _photo = payload.dataUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not attach: $e'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _send() async {
    final subject = _subject.text.trim();
    final body = _body.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Subject and body are required'),
            backgroundColor: AppColors.error,
          ),
        );
      return;
    }

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      await MemoService().send(
        kind: _kind,
        subject: subject,
        body: body,
        fromUid: user.uid,
        fromName: user.displayName ?? user.role.label,
        fromRole: user.role == UserRole.cityHall
            ? 'cityHall'
            : user.role == UserRole.iswim
                ? 'iswim'
                : 'barangay',
        toChannel: _channel,
        photo: _photo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Sent'),
            backgroundColor: AppColors.forest,
          ),
        );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not send: $e'),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'New memo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        children: [
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
              for (final channel in _channels)
                ChoiceChip(
                  label: Text('To ${channel.label}'),
                  selected: _channel == channel.value,
                  onSelected: (_) => setState(() => _channel = channel.value),
                ),
            ],
          ),
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
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Nilalaman',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _attach,
                icon: const Icon(Icons.attach_file_rounded, size: 16),
                label: Text(_photo == null ? 'Attach photo' : 'Palitan photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forest,
                  side: const BorderSide(color: AppColors.sage),
                  textStyle: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 10),
              if (_photo != null)
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: AppColors.primary),
            ],
          ),
          if (_decode(_photo) != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _decode(_photo)!,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          ],
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
                  : const Text('Send'),
            ),
          ),
          if (_kind == MemoKind.announcement) ...[
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

  static Uint8List? _decode(String? dataUrl) {
    if (dataUrl == null) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

/// Inbox of memos addressed to one channel.
class MemoInboxScreen extends StatelessWidget {
  const MemoInboxScreen({super.key, required this.channel, required this.title});

  final String channel;
  final String title;

  @override
  Widget build(BuildContext context) {
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
              // The inbox is opened from three different consoles.
              final role = context.read<AuthProvider>().currentUser?.role;
              context.go(
                switch (role) {
                  UserRole.iswim => '/iswim',
                  UserRole.admin => '/admin-dashboard',
                  _ => '/cityhall',
                },
              );
            }
          },
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<List<Memo>>(
        stream: MemoService().watchForChannel(channel),
        builder: (context, snapshot) {
          final memos = snapshot.data ?? const <Memo>[];
          if (memos.isEmpty) {
            return const Center(
              child: Text(
                'No memos in the inbox.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 26),
            children: [
              for (final memo in memos) ...[
                _MemoCard(memo: memo),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({required this.memo});

  final Memo memo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  memo.kind.label,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                memo.fromName,
                style: const TextStyle(
                  fontSize: 9,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            memo.subject,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            memo.body,
            style: const TextStyle(
              fontSize: 10,
              height: 1.5,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
