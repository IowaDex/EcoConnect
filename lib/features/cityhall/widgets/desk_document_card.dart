import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/desk_document.dart';

/// One row in the City Hall desk.
///
/// The card carries everything an officer needs before opening the document:
/// what it is, who sent it, its reference number, the trip or barangay it
/// belongs to and where it sits in the signature chain. The originating
/// office is signalled by a thin accent strip and a small pill, so a long
/// queue stays calm while remaining scannable.
class DeskDocumentCard extends StatelessWidget {
  const DeskDocumentCard({
    super.key,
    required this.document,
    required this.onOpen,
    this.onSign,
    this.index = 0,
  });

  final DeskDocument document;

  /// Opens the underlying ticket or memo.
  final VoidCallback onOpen;

  /// Opens the document at its signing step. Only shown while the document is
  /// genuinely waiting for City Hall, so no card offers a dead action.
  final VoidCallback? onSign;

  /// Position in the list, used to stagger the entrance animation.
  final int index;

  bool get _showSign => document.canSign && onSign != null;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      index: index,
      offset: 8,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.75)),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Subtle category indicator: a 3px strip on the leading edge.
              Container(
                width: 3,
                color: document.category.color.withValues(alpha: 0.55),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onOpen,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _head(),
                          const SizedBox(height: 8),
                          Text(
                            document.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forest,
                            ),
                          ),
                          const SizedBox(height: 5),
                          _sender(),
                          const SizedBox(height: 9),
                          _meta(),
                          if (document.hasAttachment) ...[
                            const SizedBox(height: 9),
                            _attachment(),
                          ],
                          const SizedBox(height: 11),
                          Container(
                            height: 1,
                            color: AppColors.sage.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 9),
                          _actions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _head() {
    // A Wrap, not a Row: the category, the document type and the status all
    // fit on one line at normal sizes, and the status drops to its own line on
    // a narrow phone instead of overflowing the card.
    return Wrap(
      spacing: 7,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _CategoryPill(category: document.category),
        Text(
          document.kind.label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: AppColors.inkMuted,
          ),
        ),
        StatusBadge(
          label: document.status.label,
          color: document.status.color,
          icon: document.status.icon,
          compact: true,
        ),
      ],
    );
  }

  Widget _sender() {
    return Row(
      children: [
        const Icon(
          Icons.person_outline_rounded,
          size: 13,
          color: AppColors.inkMuted,
        ),
        const SizedBox(width: 5),
        Flexible(
          flex: 3,
          child: Text(
            document.senderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          '·',
          style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
        ),
        const SizedBox(width: 5),
        Flexible(
          flex: 2,
          child: Text(
            document.senderRole,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _meta() {
    return Wrap(
      spacing: 13,
      runSpacing: 6,
      children: [
        _MetaItem(
          icon: Icons.tag_rounded,
          label: 'Ref',
          value: document.displayReference,
        ),
        _MetaItem(
          icon: Icons.event_outlined,
          label: document.dateCaption,
          value: dateLabel(document.date),
        ),
        if (document.area.isNotEmpty)
          _MetaItem(
            icon: Icons.place_outlined,
            label: 'Area',
            value: document.area,
          ),
        if (document.truck.isNotEmpty)
          _MetaItem(
            icon: Icons.local_shipping_outlined,
            label: 'Truck',
            value: document.truck,
          ),
      ],
    );
  }

  Widget _attachment() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file_rounded, size: 10, color: AppColors.forest),
          SizedBox(width: 4),
          Text(
            'Attachment included',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    final view = _CardButton(
      label: 'View document',
      icon: Icons.visibility_outlined,
      filled: false,
      onPressed: onOpen,
    );

    if (!_showSign) {
      return Align(alignment: Alignment.centerLeft, child: view);
    }

    // Memos, endorsements and announcements are acknowledged; trip tickets are
    // signed — the label follows the document so the officer knows what the
    // tap records.
    final sign = _CardButton(
      label: document.kind == DeskDocumentKind.tripTicket
          ? 'Sign'
          : 'Acknowledge',
      icon: Icons.draw_rounded,
      filled: true,
      onPressed: onSign,
    );

    return Row(
      children: [
        Expanded(child: view),
        const SizedBox(width: 8),
        Expanded(child: sign),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final DeskCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: category.color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 10, color: category.color),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(
            '$label ',
            style: const TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 13),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );

    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(9)),
    );
    const padding = EdgeInsets.symmetric(horizontal: 10);

    if (filled) {
      return SizedBox(
        height: 34,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forest,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 34),
            padding: padding,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: shape,
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          side: BorderSide(color: AppColors.sage.withValues(alpha: 0.95)),
          minimumSize: const Size(0, 34),
          padding: padding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: shape,
        ),
        child: child,
      ),
    );
  }
}
