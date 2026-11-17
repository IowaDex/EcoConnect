import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';

/// Notification list opened from the bell in the home hero.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  static const _items = <_Alert>[
    _Alert(
      title: 'Collection today',
      body: 'Sector 4 pickup at 2:30 PM. Have your bins ready.',
      time: '10 min ago',
      icon: Icons.local_shipping_rounded,
      unread: true,
    ),
    _Alert(
      title: 'Recycling drive',
      body: 'Barangay hall, Saturday 8 AM to 12 NN.',
      time: '2 hours ago',
      icon: Icons.recycling_rounded,
      unread: true,
    ),
    _Alert(
      title: 'Daily notice',
      body: 'Segregate biodegradable and non-biodegradable waste.',
      time: 'Yesterday',
      icon: Icons.campaign_rounded,
    ),
    _Alert(
      title: 'Account verified',
      body: 'Your email is confirmed. Welcome to EcoConnect!',
      time: '2 days ago',
      icon: Icons.verified_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(
              title: 'Notifications',
              subtitle: 'Updates from your barangay and collection crew.',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    FadeSlideIn(
                      index: i,
                      child: _AlertTile(alert: _items[i]),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Alert {
  const _Alert({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    this.unread = false,
  });

  final String title;
  final String body;
  final String time;
  final IconData icon;
  final bool unread;
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final _Alert alert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alert.unread
            ? AppColors.mint.withValues(alpha: 0.55)
            : AppColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alert.unread
              ? AppColors.forest.withValues(alpha: 0.22)
              : AppColors.sage.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: alert.unread ? AppColors.forest : AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              alert.icon,
              size: 17,
              color: alert.unread ? AppColors.creamBright : AppColors.forest,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    if (alert.unread)
                      Container(
                        height: 7,
                        width: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2574C),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  alert.body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.time,
                  style: const TextStyle(
                    fontSize: 10,
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
