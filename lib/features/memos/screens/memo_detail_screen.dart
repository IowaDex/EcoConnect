import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_loading.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tickets/widgets/signature_sheet.dart';
import '../services/memo_service.dart';
import '../widgets/memo_widgets.dart';

/// One memo, with its attachment and — for City Hall — the signing action.
///
/// Opening a memo addressed to City Hall marks it received, which is what the
/// author sees in their sent history. Signing stores the drawn signature, the
/// signer and the time on the memo itself, so reopening shows the same record.
class MemoDetailScreen extends StatefulWidget {
  const MemoDetailScreen({
    super.key,
    required this.memoId,
    this.autoSign = false,
  });

  final String memoId;

  /// Opens the signature sheet as soon as the memo loads. Used by the City
  /// Hall desk when the officer taps "Acknowledge" on a card.
  final bool autoSign;

  @override
  State<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends State<MemoDetailScreen> {
  bool _receivedMarked = false;
  bool _signing = false;
  bool _downloading = false;
  bool _autoSignHandled = false;

  /// Cached so a rebuild from [_signing] or [_downloading] does not hand the
  /// StreamBuilder a new stream and flash the loading state.
  late final Stream<Memo?> _memo = MemoService().watchOne(widget.memoId);

  Future<void> _markReceived(Memo memo) async {
    if (_receivedMarked) return;
    _receivedMarked = true;
    try {
      await MemoService().markReceived(memo.id);
    } catch (_) {
      // A failed status write must not block reading the memo.
      _receivedMarked = false;
    }
  }

  Future<void> _sign(Memo memo) async {
    if (_signing) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    // Guard the whole interaction, including the time the signature sheet is
    // open, so a double tap cannot open two sheets.
    setState(() => _signing = true);
    try {
      final signature = await showSignatureSheet(
        context,
        signerLabel: 'City Hall',
      );
      if (signature == null || !mounted) return;

      await MemoService().acknowledge(
        id: memo.id,
        byUid: user.uid,
        byName: user.displayName ?? 'City Hall',
        signature: signature,
      );
      if (mounted) AppFeedback.success(context, 'Memo signed');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  /// Downloads a real, self-contained copy of the signed memo: the text, the
  /// signer, the timestamps and the drawn signature. No server round trip and
  /// no new dependency — the browser saves an HTML file.
  Future<void> _downloadCopy(Memo memo) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final dataUrl =
          'data:text/html;charset=utf-8;base64,${base64Encode(utf8.encode(_signedCopy(memo)))}';
      final saved = await saveDataUrl(dataUrl, 'memo-${memo.id}.html');
      if (!mounted) return;
      if (saved) {
        AppFeedback.success(context, 'Signed copy downloaded');
      } else {
        AppFeedback.error(
          context,
          'Could not save this memo. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) AppFeedback.error(context, 'Could not download this memo.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  static String _signedCopy(Memo memo) {
    String esc(String value) => value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    final signature = memo.acknowledgementSignature;
    final attachment = memo.attachment;
    final flow = [
      'Sent ${dateTimeLabel(memo.createdAt)}',
      if (memo.receivedAt != null) 'Received ${dateTimeLabel(memo.receivedAt)}',
      if (memo.acknowledgedAt != null)
        'Signed ${dateTimeLabel(memo.acknowledgedAt)}',
    ].join(' · ');

    return '''<!doctype html>
<html><head><meta charset="utf-8"><title>${esc(memo.subject)}</title>
<style>
body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;color:#1b2b1f;max-width:720px;margin:40px auto;padding:0 24px}
h1{font-size:22px;line-height:1.3;color:#1f4d2b;margin-bottom:6px}
.meta{color:#5b6b5f;font-size:13px;line-height:1.6;margin:0}
.body{margin-top:20px;white-space:pre-wrap;line-height:1.7;font-size:15px}
.sig{margin-top:30px;border-top:1px solid #cbd9bc;padding-top:14px;font-size:13px}
.sig img{display:block;max-height:120px;margin-top:8px}
footer{margin-top:40px;color:#8a9a8e;font-size:11px}
</style></head>
<body>
<h1>${esc(memo.subject)}</h1>
<p class="meta">${esc(memo.kind.label)} · From ${esc(memo.fromName)} · To ${esc(memo.recipientLabel)}<br>${esc(flow)}</p>
<div class="body">${esc(memo.body)}</div>
${signature == null ? '' : '<div class="sig"><strong>Signed by ${esc(memo.acknowledgedByName ?? 'City Hall')}</strong><br><img alt="Signature" src="$signature"></div>'}
${attachment == null ? '' : '<p class="meta" style="margin-top:18px">Attachment: ${esc(attachment.fileName)}</p>'}
<footer>Eco Connect · City Hall / DSQC · exported ${esc(dateTimeLabel(DateTime.now()))}</footer>
</body></html>''';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    // The whole page sits inside the stream so the header can carry the live
    // status pill instead of repeating it at the top of the body.
    return StreamBuilder<Memo?>(
      stream: _memo,
      builder: (context, snapshot) {
        final memo = snapshot.data;
        final waiting = snapshot.connectionState == ConnectionState.waiting;

        return EcoPageScaffold(
          eyebrow: 'MEMORANDUM',
          title: 'Memo',
          subtitle: 'The full text, the signatures and the trail behind it.',
          icon: Icons.description_outlined,
          actions: [if (memo != null) MemoStatusBadge(status: memo.status)],
          onBack: () => context.pop(),
          body: snapshot.hasError
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load this memo',
                  message: AppFeedback.describe(snapshot.error!),
                )
              : waiting && memo == null
              ? const EcoLoadingView(label: 'Loading memo')
              : memo == null
              ? const EmptyState(
                  icon: Icons.description_outlined,
                  title: 'Memo not found',
                  message: 'This memo no longer exists or was withdrawn.',
                )
              : _body(context, memo, user),
        );
      },
    );
  }

  Widget _body(BuildContext context, Memo memo, AppUser? user) {
    final isCityHall = user?.role == UserRole.cityHall;
    final isAuthor = user?.uid == memo.fromUid;
    final isRecipient = _ownsChannel(user?.role, memo.toChannel);
    final canSign =
        isCityHall && memo.toChannel == 'cityHall' && !memo.isSigned;
    final canEdit = isAuthor && memo.isEditable;

    // Arriving from the desk's "Acknowledge" button: open the signature sheet
    // once, after the first frame so the page is already mounted.
    if (widget.autoSign && canSign && !_autoSignHandled) {
      _autoSignHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sign(memo);
      });
    }

    // Opening a memo addressed to your own desk records that it arrived.
    if (isRecipient && !memo.isSigned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markReceived(memo);
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        FadeSlideIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(EcoRadius.pill),
                    ),
                    child: Text(
                      memo.kind.label,
                      style: EcoType.chip(context, color: AppColors.forest),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeAgo(memo.createdAt),
                    style: EcoType.meta(context, color: AppColors.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: EcoSpace.sm),
              Text(
                memo.subject,
                style: EcoType.panelTitle(context, color: AppColors.darkGreen),
              ),
              const SizedBox(height: EcoSpace.sm),
              Row(
                children: [
                  DeskInitialAvatar(name: memo.fromName, size: 24),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'From ${memo.fromName} · To ${memo.recipientLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.meta(context, color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
              if (memo.editedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Edited ${timeAgo(memo.editedAt)}',
                  style: EcoType.micro(context, color: AppColors.inkMuted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: EcoSpace.md),
        EcoCard(
          child: SelectableText(
            memo.body,
            style: EcoType.body(
              context,
              color: AppColors.textDark,
            ).copyWith(height: 1.7),
          ),
        ),
        if (memo.attachment != null) ...[
          const SizedBox(height: EcoSpace.md),
          MemoAttachmentCard(attachment: memo.attachment!),
        ],
        const SizedBox(height: EcoSpace.md),
        _StatusTimeline(memo: memo),
        if (memo.isSigned) ...[
          const SizedBox(height: EcoSpace.md),
          _SignatureCard(memo: memo),
          const SizedBox(height: EcoSpace.sm),
          SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _downloading ? null : () => _downloadCopy(memo),
              icon: const Icon(Icons.download_rounded, size: 15),
              label: Text(
                _downloading ? 'Preparing…' : 'Download signed copy',
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
          ),
        ],
        if (canSign) ...[
          const SizedBox(height: EcoSpace.lg),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _signing ? null : () => _sign(memo),
              icon: _signing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.draw_rounded, size: 18),
              label: Text(_signing ? 'Saving…' : 'Sign & acknowledge'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
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
          const SizedBox(height: EcoSpace.sm),
          Text(
            'Your signature is stored on this memo with your name and the '
            'date and time.',
            textAlign: TextAlign.center,
            style: EcoType.micro(context, color: AppColors.inkMuted),
          ),
        ],
        if (canEdit) ...[
          const SizedBox(height: EcoSpace.lg),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/memo/${memo.id}/edit'),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit memo', style: TextStyle(fontSize: 11.5)),
            ),
          ),
        ],
      ],
    );
  }
}

/// True when the signed-in role is the desk the memo was addressed to.
bool _ownsChannel(UserRole? role, String channel) => switch (role) {
  UserRole.cityHall => channel == 'cityHall',
  UserRole.iswim => channel == 'iswim',
  UserRole.admin => channel == 'barangay',
  _ => false,
};

/// Sent → Received → Signed, so both desks see the same progress.
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.memo});

  final Memo memo;

  @override
  Widget build(BuildContext context) {
    final steps = <({String label, DateTime? time, bool done})>[
      (label: 'Sent', time: memo.createdAt, done: memo.createdAt != null),
      (label: 'Received', time: memo.receivedAt, done: memo.receivedAt != null),
      (
        label: 'Signed',
        time: memo.acknowledgedAt,
        done: memo.acknowledgedAt != null,
      ),
    ];

    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEMO FLOW',
            style: EcoType.eyebrow(context, color: AppColors.moss),
          ),
          const SizedBox(height: EcoSpace.sm),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Icon(
                    steps[i].done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: steps[i].done ? AppColors.primary : AppColors.sage,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      steps[i].label,
                      style: steps[i].done
                          ? EcoType.bodyStrong(
                              context,
                              color: AppColors.textDark,
                            )
                          : EcoType.body(context, color: AppColors.inkMuted),
                    ),
                  ),
                  if (steps[i].time != null)
                    Text(
                      timeAgo(steps[i].time),
                      style: EcoType.meta(context, color: AppColors.inkMuted),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The signature image and who left it, read back from the memo.
class _SignatureCard extends StatelessWidget {
  const _SignatureCard({required this.memo});

  final Memo memo;

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(memo.acknowledgementSignature);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SIGNED',
                  style: EcoType.eyebrow(context, color: AppColors.primary),
                ),
              ),
              Text(
                timeAgo(memo.acknowledgedAt),
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
            ],
          ),
          if (bytes != null) ...[
            const SizedBox(height: 10),
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(EcoRadius.sm),
                border: Border.all(color: AppColors.sage),
              ),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            memo.acknowledgedByName ?? 'City Hall',
            style: EcoType.bodyStrong(context, color: AppColors.textDark),
          ),
          Text(
            'City Hall · DSQC',
            style: EcoType.meta(context, color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }

  static Uint8List? _decode(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}
