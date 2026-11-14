import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/motion.dart';
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
                    onPressed: () => _open(context),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text(
                      'Open',
                      style: TextStyle(fontSize: 10.5),
                    ),
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
    if (!saved && context.mounted) await _open(context);
  }

  Future<void> _open(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri.parse(attachment.dataUrl),
        mode: LaunchMode.platformDefault,
      );
      if (!opened && context.mounted) {
        AppFeedback.error(context, 'No app can open this file on this device.');
      }
    } catch (_) {
      if (context.mounted) {
        AppFeedback.error(context, 'Could not open this file.');
      }
    }
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
class MemoCard extends StatelessWidget {
  const MemoCard({super.key, required this.memo});

  final Memo memo;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/memo/${memo.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Ink(
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
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
                    const SizedBox(width: 6),
                    MemoStatusBadge(status: memo.status),
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
                const SizedBox(height: 7),
                Text(
                  memo.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  memo.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.45,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 11, color: AppColors.inkMuted),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${memo.fromName} → ${memo.recipientLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (memo.attachment != null)
                      MemoAttachmentChip(attachment: memo.attachment!),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
