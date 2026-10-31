import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/hex_leaf_logo.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(firstName: user?.firstName ?? 'there'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                children: [
                  _SectionLabel(
                    title: "WHAT'S NEW?",
                    action: 'View all',
                    onAction: () => _toast(context, 'No more updates right now'),
                  ),
                  const SizedBox(height: 10),
                  const _WhatsNewRow(),
                  const SizedBox(height: 22),
                  const Text(
                    'Announcements!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _AnnouncementCard(),
                  const SizedBox(height: 18),
                  _TrackPrompt(onTap: () => context.go('/tracking')),
                  const SizedBox(height: 12),
                  _ReportPrompt(onTap: () => context.go('/report-incident')),
                  const SizedBox(height: 12),
                  _WalletPrompt(onTap: () => context.go('/wallet')),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (i) => _onNav(context, i),
      ),
    );
  }

  void _onNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        context.go('/tracking');
      case 2:
        _toast(context, 'You have no new alerts');
      case 3:
        _showProfile(context);
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showProfile(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            const CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.mint,
              child: Icon(Icons.person, size: 34, color: AppColors.forest),
            ),
            const SizedBox(height: 14),
            Text(
              user?.displayName ?? 'EcoConnect user',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.creamBright,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Address',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.fullAddress ?? 'No address on file',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await auth.logout();
                  if (context.mounted) context.go('/login');
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandWordmark(fontSize: 10.5),
                const SizedBox(height: 12),
                Text(
                  'Welcome,\n$firstName!',
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ],
            ),
          ),
          const HexLeafLogo(size: 58, strokeWidth: 3.2),
          const SizedBox(width: 10),
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.forest,
          ),
        ),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
            ),
          ),
      ],
    );
  }
}

class _WhatsNewRow extends StatelessWidget {
  const _WhatsNewRow();

  static const _cards = <({String title, String subtitle, IconData icon})>[
    (title: 'Collection today', subtitle: 'Sector 4 · 2:30 PM', icon: Icons.local_shipping_rounded),
    (title: 'Recycling drive', subtitle: 'Barangay hall', icon: Icons.recycling_rounded),
    (title: 'Route update', subtitle: 'New street added', icon: Icons.alt_route_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final card = _cards[i];
          return Container(
            width: 156,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.mint, Color(0xFFCDE8B4)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(card.icon, size: 20, color: AppColors.forest),
                ),
                const Spacer(),
                Text(
                  card.title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  card.subtitle,
                  style: const TextStyle(fontSize: 8.5, color: AppColors.moss),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 13,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 15, color: AppColors.forest),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Barangay EcoConnect',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '2 hours ago',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Daily Notice!',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please have your bins ready before the truck arrives. Segregate '
            'biodegradable and non-biodegradable waste to keep the collection '
            'fast and safe for everyone.',
            style: TextStyle(
              fontSize: 8.5,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportPrompt extends StatelessWidget {
  const _ReportPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.report_outlined,
                  size: 18, color: AppColors.forest),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report an incident',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Missed pickup, dumping or a full bin',
                    style: TextStyle(fontSize: 9, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.moss),
          ],
        ),
      ),
    );
  }
}

class _WalletPrompt extends StatelessWidget {
  const _WalletPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.mint.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.forest.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: const BoxDecoration(
                color: AppColors.forest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.recycling_rounded,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recycling wallet',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Your points from the barangay drop-off station',
                    style: TextStyle(fontSize: 9, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.moss),
          ],
        ),
      ),
    );
  }
}

class _TrackPrompt extends StatelessWidget {
  const _TrackPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.near_me_rounded,
                  size: 18, color: AppColors.forest),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track the truck',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'See where your collector is right now',
                    style: TextStyle(fontSize: 9, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.moss),
          ],
        ),
      ),
    );
  }
}
