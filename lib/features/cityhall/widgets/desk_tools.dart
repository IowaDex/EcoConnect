import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/section_header.dart';
import '../../dashboard/widgets/quick_action_grid.dart';

/// The twelve City Hall shortcuts, laid out as a responsive grid.
///
/// The grid itself lives in [QuickActionGrid], the same component the other
/// role dashboards use, so a shortcut looks and behaves identically no matter
/// which desk the officer signed in to.
class DeskTools extends StatelessWidget {
  const DeskTools({super.key, required this.pendingSignatures});

  /// Shown as a badge on the Signatures shortcut.
  final int pendingSignatures;

  /// The destinations, in the order the desk has always shown them.
  List<QuickAction> get tools => [
    const QuickAction(
      label: 'Complaints',
      icon: Icons.report_outlined,
      route: '/complaints',
    ),
    const QuickAction(
      label: 'Resident requests',
      icon: Icons.forum_outlined,
      route: '/cityhall-requests',
    ),
    const QuickAction(
      label: 'Manuals',
      icon: Icons.menu_book_outlined,
      route: '/manuals',
    ),
    const QuickAction(
      label: 'Manual requests',
      icon: Icons.mark_email_unread_outlined,
      route: '/manual-requests',
    ),
    const QuickAction(
      label: 'Schedules',
      icon: Icons.calendar_month_outlined,
      route: '/assignments',
    ),
    const QuickAction(
      label: 'Delay reports',
      icon: Icons.timer_outlined,
      route: '/delays',
    ),
    const QuickAction(
      label: 'Incidents',
      icon: Icons.warning_amber_outlined,
      route: '/incidents',
    ),
    const QuickAction(
      label: 'Wave 2',
      icon: Icons.layers_outlined,
      route: '/wave2',
    ),
    const QuickAction(
      label: 'Memos',
      icon: Icons.mail_outline_rounded,
      route: '/memos/cityHall',
    ),
    const QuickAction(
      label: 'Email log',
      icon: Icons.outgoing_mail,
      route: '/email-log',
    ),
    const QuickAction(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      route: '/announcements',
    ),
    const QuickAction(
      label: 'Fleet',
      icon: Icons.local_shipping_outlined,
      route: '/fleet',
    ),
    QuickAction(
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
        const SectionLabel('DESK TOOLS'),
        const SizedBox(height: 2),
        Text(
          '${shortcuts.length} shortcuts — every record the DSQC can open, '
          'one tap away.',
          style: const TextStyle(
            fontSize: 10,
            height: 1.4,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 9),
        QuickActionGrid(actions: shortcuts),
      ],
    );
  }
}
