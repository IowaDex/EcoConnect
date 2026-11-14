import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
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
        AppFeedback.error(context, 'Download is not available on this device.');
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
          'Memo',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<Memo?>(
        stream: MemoService().watchOne(widget.memoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2.4),
            );
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
          final memo = snapshot.data;
          if (memo == null) {
            return const Center(
              child: Text(
                'This memo no longer exists.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              ),
            );
          }

          final isCityHall = user?.role == UserRole.cityHall;
          final isAuthor = user?.uid == memo.fromUid;
          final isRecipient = _ownsChannel(user?.role, memo.toChannel);
          final canSign =
              isCityHall && memo.toChannel == 'cityHall' && !memo.isSigned;
          final canEdit = isAuthor && memo.isEditable;

          // Arriving from the desk's "Acknowledge" button: open the signature
          // sheet once, after the first frame so the page is already mounted.
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              FadeSlideIn(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            memo.kind.label,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        MemoStatusBadge(status: memo.status, compact: false),
                        const Spacer(),
                        Text(
                          timeAgo(memo.createdAt),
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      memo.subject,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'From ${memo.fromName} · To ${memo.recipientLabel}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    if (memo.editedAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Edited ${timeAgo(memo.editedAt)}',
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              EcoCard(
                child: Text(
                  memo.body,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.65,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (memo.attachment != null) ...[
                const SizedBox(height: 12),
                MemoAttachmentCard(attachment: memo.attachment!),
              ],
              const SizedBox(height: 12),
              _StatusTimeline(memo: memo),
              if (memo.isSigned) ...[
                const SizedBox(height: 12),
                _SignatureCard(memo: memo),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed:
                        _downloading ? null : () => _downloadCopy(memo),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      _downloading ? 'Preparing…' : 'Download signed copy',
                    ),
                  ),
                ),
              ],
              if (canSign) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _signing ? null : () => _sign(memo),
                    icon: const Icon(Icons.draw_rounded, size: 18),
                    label: Text(_signing ? 'Saving…' : 'Sign & acknowledge'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your signature is stored on this memo with your name and the '
                  'date and time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8.5,
                    height: 1.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
              if (canEdit) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/memo/${memo.id}/edit'),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit memo'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
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
        done: memo.acknowledgedAt != null
      ),
    ];

    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Memo flow',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 10),
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
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            steps[i].done ? FontWeight.w600 : FontWeight.w500,
                        color: steps[i].done
                            ? AppColors.textDark
                            : AppColors.inkMuted,
                      ),
                    ),
                  ),
                  if (steps[i].time != null)
                    Text(
                      timeAgo(steps[i].time),
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
              const Icon(Icons.verified_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                'Signed',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const Spacer(),
              Text(
                timeAgo(memo.acknowledgedAt),
                style: const TextStyle(
                  fontSize: 8.5,
                  color: AppColors.inkMuted,
                ),
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
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.sage),
              ),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            memo.acknowledgedByName ?? 'City Hall',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const Text(
            'City Hall · DSQC',
            style: TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
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
