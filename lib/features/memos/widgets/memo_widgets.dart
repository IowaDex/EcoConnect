import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../services/memo_service.dart';

/// Small pill showing where a memo is in its life.
class MemoStatusBadge extends StatelessWidget {
  const MemoStatusBadge({super.key, required this.status, this.compact = true});

  final MemoStatus status;
  final bool compact;

  Color get _color => switch (status) {
    MemoStatus.sent => const Color(0xFF1565C0),
    MemoStatus.received => AppColors.warning,
    MemoStatus.acknowledged => AppColors.primary,
  };

  IconData get _icon => switch (status) {
    MemoStatus.sent => Icons.outbox_rounded,
    MemoStatus.received => Icons.mark_email_read_outlined,
    MemoStatus.acknowledged => Icons.verified_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: status.label,
      color: _color,
      icon: _icon,
      compact: compact,
    );
  }
}

/// The file that came with a memo, with a preview and a real download.
class MemoAttachmentCard extends StatelessWidget {
  const MemoAttachmentCard({super.key, required this.attachment});

  final UploadPayload attachment;

  @override
  Widget build(BuildContext context) {
    final bytes = attachment.isPdf ? null : _decode(attachment);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                attachment.isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.image_outlined,
                size: 20,
                color: attachment.isPdf ? AppColors.error : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    Text(
                      attachment.bytes == 0
                          ? 'Attached file'
                          : '${attachment.sizeKb.toStringAsFixed(0)} KB · '
                                '${attachment.isPdf ? 'PDF' : 'image'}',
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
          if (bytes != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: () => _showViewer(context),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('Open', style: TextStyle(fontSize: 10.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton.icon(
                    onPressed: () => _download(context),
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text(
                      'Download',
                      style: TextStyle(fontSize: 10.5),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Saves the file through the browser, or opens it when the platform has no
  /// download (mobile), so the action always does something real.
  Future<void> _download(BuildContext context) async {
    final saved = await saveDataUrl(attachment.dataUrl, attachment.fileName);
    if (!saved && context.mounted) _showViewer(context);
  }

  /// Shows the file over the memo instead of sending the reader to another
  /// tab: the page behind is dimmed and the attachment sits in a modal.
  void _showViewer(BuildContext context) {
    final bytes = attachment.isPdf ? null : _decode(attachment);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: const BoxDecoration(
                color: AppColors.creamBright,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Icon(
                    attachment.isPdf
                        ? Icons.picture_as_pdf_rounded
                        : Icons.image_outlined,
                    size: 18,
                    color: attachment.isPdf
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      attachment.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.inkMuted,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 380),
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.creamBright,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: bytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        maxScale: 4,
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 46,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${attachment.fileName} · '
                          '${attachment.sizeKb.toStringAsFixed(0)} KB',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'A PDF cannot be shown inside the app. Download it '
                          'to read the full document.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.45,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 38,
                          child: FilledButton.icon(
                            onPressed: () => saveDataUrl(
                              attachment.dataUrl,
                              attachment.fileName,
                            ),
                            icon: const Icon(Icons.download_rounded, size: 15),
                            label: const Text(
                              'Download',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.forest,
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

  static Uint8List? _decode(UploadPayload payload) {
    final comma = payload.dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(payload.dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

/// Small square preview used inside list cards, so a memo with a file looks
/// different from one without.
class MemoAttachmentChip extends StatelessWidget {
  const MemoAttachmentChip({super.key, required this.attachment});

  final UploadPayload attachment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          attachment.isPdf
              ? Icons.picture_as_pdf_rounded
              : Icons.attach_file_rounded,
          size: 11,
          color: AppColors.inkMuted,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            attachment.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// One memo in a list: kind, status, subject, a preview of the body and the
/// sender → recipient line. Tapping opens the full record.
///
/// Built on [DeskRailCard] so the rail carries the delivery state, the same
/// way a complaint, a request and a manual do: a clerk scans the queue by
/// colour before reading a single word.
class MemoCard extends StatelessWidget {
  const MemoCard({super.key, required this.memo, this.needsAction});

  final Memo memo;

  /// Overrides the amber "needs attention" treatment. The inbox passes true
  /// for every unacknowledged memo, including ones the desk has not opened.
  final bool? needsAction;

  static IconData _iconFor(MemoKind kind) => switch (kind) {
    MemoKind.memo => Icons.sticky_note_2_outlined,
    MemoKind.endorsement => Icons.forward_to_inbox_rounded,
    MemoKind.announcement => Icons.campaign_outlined,
    MemoKind.manualRequest => Icons.menu_book_outlined,
  };

  static Color _railFor(MemoStatus status) => switch (status) {
    MemoStatus.sent => const Color(0xFF1565C0),
    MemoStatus.received => AppColors.warning,
    MemoStatus.acknowledged => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final action = needsAction ?? memo.status == MemoStatus.received;
    // "New" is the inbox's own read state: addressed here, not opened yet.
    final unopened = action && memo.status == MemoStatus.sent;
    final rail = _railFor(memo.status);

    return DeskRailCard(
      railColor: rail,
      onTap: () => context.push('/memo/${memo.id}'),
      padding: const EdgeInsets.fromLTRB(16, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(memo.kind), size: 13, color: rail),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${memo.kind.label} · ${timeAgo(memo.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.eyebrow(context, color: AppColors.moss),
                ),
              ),
              const SizedBox(width: 8),
              if (unopened)
                const StatusBadge(
                  label: 'New',
                  color: Color(0xFF1565C0),
                  icon: Icons.fiber_new_rounded,
                )
              else
                MemoStatusBadge(status: memo.status),
            ],
          ),
          const SizedBox(height: EcoSpace.xs),
          Text(
            memo.subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.cardTitleLarge(context, color: AppColors.darkGreen),
          ),
          const SizedBox(height: 5),
          Text(
            memo.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.bodySmall(context, color: AppColors.inkMuted),
          ),
          const SizedBox(height: EcoSpace.sm),
          Row(
            children: [
              DeskInitialAvatar(name: memo.fromName, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${memo.fromName} → ${memo.recipientLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ),
              if (memo.attachment != null) ...[
                const SizedBox(width: EcoSpace.sm),
                Flexible(
                  child: MemoAttachmentChip(attachment: memo.attachment!),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
