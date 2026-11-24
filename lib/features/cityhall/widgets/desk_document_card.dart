import 'package:flutter/material.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/desk_document.dart';

/// One row in the City Hall desk.
///
/// The card answers four questions before the officer opens anything: what it
/// is, where it came from, which record it belongs to, and what happens next.
/// The originating office is carried by a thin rail and a pill rather than a
/// second header, so a long queue stays calm while remaining scannable.
///
/// It is built on [EcoCard], which supplies the hover lift and press dip every
/// other desk surface has — the queue should feel like part of the product,
/// not a list bolted onto it.
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
      child: EcoCard(
        padding: EdgeInsets.zero,
        onTap: onOpen,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The rail is the office, so the queue can be scanned by colour
              // before a single word is read.
              Container(
                width: 4,
                color: document.category.color.withValues(alpha: 0.7),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _head(context),
                      const SizedBox(height: EcoSpace.xs + 2),
                      Text(
                        document.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: EcoType.cardTitleLarge(
                          context,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _sender(context),
                      const SizedBox(height: EcoSpace.sm),
                      _meta(context),
                      const SizedBox(height: EcoSpace.sm),
                      _actions(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _head(BuildContext context) {
    // A Wrap, not a Row: the office, the document type and the status all fit
    // on one line at normal sizes, and the status drops to its own line on a
    // narrow phone instead of overflowing the card.
    return Wrap(
      spacing: 7,
      runSpacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _CategoryPill(category: document.category),
        Text(
          document.kind.label,
          style: EcoType.meta(context, color: AppColors.inkMuted),
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

  Widget _sender(BuildContext context) {
    return Row(
      children: [
        DeskInitialAvatar(name: document.senderName, size: 22),
        const SizedBox(width: 7),
        Flexible(
          flex: 3,
          child: Text(
            document.senderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EcoType.bodyStrong(context, color: AppColors.textDark),
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
            style: EcoType.meta(context, color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _meta(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _MetaItem(icon: Icons.tag_rounded, value: document.displayReference),
        _MetaItem(
          icon: Icons.event_outlined,
          value: '${document.dateCaption} ${dateLabel(document.date)}',
        ),
        if (document.area.isNotEmpty)
          _MetaItem(icon: Icons.place_outlined, value: document.area),
        if (document.truck.isNotEmpty)
          _MetaItem(icon: Icons.local_shipping_outlined, value: document.truck),
        if (document.hasAttachment)
          const _MetaItem(icon: Icons.attach_file_rounded, value: 'Attachment'),
      ],
    );
  }

  Widget _actions(BuildContext context) {
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

/// The sender's initials come from the shared [DeskInitialAvatar], so the same
/// person looks the same here, on a complaint and on an incident.

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final DeskCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(EcoRadius.pill),
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
              fontWeight: FontWeight.w800,
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
  const _MetaItem({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EcoType.meta(context, color: AppColors.inkMuted),
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
      borderRadius: BorderRadius.all(Radius.circular(EcoRadius.sm)),
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
