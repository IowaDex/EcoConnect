import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/models/user.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/user_avatar.dart';
import '../widgets/profile_sheet.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(user: user, onEditProfile: () => _showProfile(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              children: [
                _SectionLabel(
                  title: "WHAT'S NEW?",
                  action: 'View all',
                  onAction: () => _toast(context, 'No more updates right now'),
                ),
                const SizedBox(height: 12),
                const _WhatsNewRow(),
                const SizedBox(height: 26),
                const Text(
                  'Announcements!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 12),
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
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (i) => _onNav(context, i),
        onAskAi: () => context.push('/ask-ai'),
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
        context.go('/community');
      case 3:
        _showProfile(context);
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showProfile(BuildContext context) => showProfileSheet(context);
}

/// Dark hero panel: wordmark, avatar, greeting and the two quick pills.
class _Hero extends StatelessWidget {
  const _Hero({required this.user, required this.onEditProfile});

  final AppUser? user;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final address = user?.fullAddress ?? 'No address on file';
    final hasAddress = address != 'No address on file';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, topInset + 16, 22, 22),
      decoration: const BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandWordmark(fontSize: 12, color: AppColors.creamBright),
              const Spacer(),
              _HeroBell(onTap: () => context.push('/alerts')),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              UserAvatar(
                photoUrl: user?.photoUrl,
                size: 62,
                background: AppColors.creamBright,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.creamBright.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.displayName ?? 'EcoConnect user',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.creamBright,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.creamBright.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Flexible(
                child: _HeroPill(
                  label: hasAddress ? address : 'No address yet',
                  icon: Icons.location_on_outlined,
                  onTap: onEditProfile,
                ),
              ),
              const SizedBox(width: 10),
              _HeroPill(label: 'Edit profile', onTap: onEditProfile),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bell button in the hero's top-right corner with an unread dot.
class _HeroBell extends StatelessWidget {
  const _HeroBell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppColors.creamBright.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 19,
              color: AppColors.creamBright,
            ),
          ),
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              height: 10,
              width: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE2574C),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.forestDeep, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outline pill used inside the dark hero.
class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.onTap, this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: AppColors.creamBright.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: AppColors.creamBright),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.creamBright,
                ),
              ),
            ),
          ],
        ),
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
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: AppColors.forest,
              ),
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
                colors: [Color(0xFFE9F5DC), Color(0xFFD5EDBE)],
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 16, color: AppColors.forest),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Barangay EcoConnect',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '2 hours ago',
                    style: TextStyle(
                      fontSize: 8.5,
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
              fontSize: 12.5,
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
              fontSize: 9.5,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.8),
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
