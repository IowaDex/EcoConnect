import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/eco_card.dart';

/// One destination in the desk's shortcut grid.
typedef DeskTool = ({String label, IconData icon, String route, int badge});

/// The twelve City Hall shortcuts, laid out as a responsive grid.
///
/// Every shortcut is visible by scrolling the page down: two columns on a
/// phone, three or four on a tablet and five on a wide window. The grid is
/// sized by its children and never scrolls on its own, so the page stays the
/// only scrollable and there is no sideways swiping anywhere in this section.
class DeskTools extends StatelessWidget {
  const DeskTools({super.key, required this.pendingSignatures});

  /// Shown as a badge on the Signatures shortcut.
  final int pendingSignatures;

  /// The destinations, in the order the desk has always shown them.
  List<DeskTool> get tools => [
        (
          label: 'Complaints',
          icon: Icons.report_outlined,
          route: '/complaints',
          badge: 0,
        ),
        (
          label: 'Resident requests',
          icon: Icons.forum_outlined,
          route: '/cityhall-requests',
          badge: 0,
        ),
        (
          label: 'Manuals',
          icon: Icons.menu_book_outlined,
          route: '/manuals',
          badge: 0,
        ),
        (
          label: 'Manual requests',
          icon: Icons.mark_email_unread_outlined,
          route: '/manual-requests',
          badge: 0,
        ),
        (
          label: 'Delay reports',
          icon: Icons.timer_outlined,
          route: '/delays',
          badge: 0,
        ),
        (
          label: 'Incidents',
          icon: Icons.warning_amber_outlined,
          route: '/incidents',
          badge: 0,
        ),
        (
          label: 'Wave 2',
          icon: Icons.layers_outlined,
          route: '/wave2',
          badge: 0,
        ),
        (
          label: 'Memos',
          icon: Icons.mail_outline_rounded,
          route: '/memos/cityHall',
          badge: 0,
        ),
        (
          label: 'Email log',
          icon: Icons.outgoing_mail,
          route: '/email-log',
          badge: 0,
        ),
        (
          label: 'Accounts',
          icon: Icons.badge_outlined,
          route: '/accounts',
          badge: 0,
        ),
        (
          label: 'Fleet',
          icon: Icons.local_shipping_outlined,
          route: '/fleet',
          badge: 0,
        ),
        (
          label: 'Signatures',
          icon: Icons.draw_outlined,
          route: '/cityhall/signatures',
          badge: pendingSignatures,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final shortcuts = tools;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Desk tools',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.forest,
              ),
            ),
            const Spacer(),
            Text(
              '${shortcuts.length} shortcuts',
              style: const TextStyle(
                fontSize: 8.5,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: shortcuts.length,
          // 210px per card gives two columns at phone widths, three at ~600,
          // four at ~800 and five once the page reaches its 980px cap.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            mainAxisExtent: 88,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) =>
              _ToolCard(tool: shortcuts[index]),
        ),
      ],
    );
  }
}

/// A single shortcut. The card keeps the shared surface, radius, border and
/// tap feedback from [EcoCard], so it matches every other panel in the app.
class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});

  final DeskTool tool;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.all(11),
      onTap: () => context.push(tool.route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 28,
                width: 28,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(tool.icon, size: 15, color: AppColors.forest),
              ),
              const Spacer(),
              if (tool.badge > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${tool.badge}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            tool.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}
