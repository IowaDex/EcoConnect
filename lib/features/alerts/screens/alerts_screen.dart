import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 22, 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Alerts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Updates from your barangay and collection crew.',
                    style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 18),
                  for (final item in _items) ...[
                    _AlertTile(alert: item),
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
        borderRadius: BorderRadius.circular(16),
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
                          fontSize: 11.5,
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
                    fontSize: 10,
                    height: 1.45,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.time,
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
