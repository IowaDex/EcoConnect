import 'package:flutter/material.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/widgets/section_header.dart';
import '../../dashboard/widgets/quick_action_grid.dart';

/// The City Hall shortcuts, laid out as a responsive grid.
///
/// The grid itself lives in [QuickActionGrid], the same component the other
/// role dashboards use, so a shortcut looks and behaves identically no matter
/// which desk the officer signed in to. The tiles are deliberately short: this
/// block is navigation, and the queue underneath is the work.
class DeskTools extends StatelessWidget {
  const DeskTools({super.key, required this.pendingSignatures});

  /// Shown as a badge on the Signatures shortcut.
  final int pendingSignatures;

  /// The destinations, in the order the desk has always shown them.
  List<QuickAction> get tools => [
    const QuickAction(
      label: 'SOS incidents',
      icon: Icons.notifications_active_outlined,
      route: '/sos',
    ),
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
    QuickAction(
      label: 'Signatures',
      icon: Icons.draw_outlined,
      route: '/cityhall/signatures',
      badge: pendingSignatures,
    ),
    const QuickAction(
      label: 'District Officers',
      icon: Icons.support_agent_rounded,
      route: '/district-officers',
    ),
    const QuickAction(
      label: 'Call history',
      icon: Icons.history_rounded,
      route: '/calls',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('DESK TOOLS'),
        const SizedBox(height: EcoSpace.xs),
        QuickActionGrid(actions: tools),
      ],
    );
  }
}
