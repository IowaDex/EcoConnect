import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../location/widgets/location_controls.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/models/account_type.dart';
import '../../announcements/models/announcement.dart';
import '../../announcements/services/announcement_service.dart';
import '../../events/models/community_event.dart';
import '../../events/services/event_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/profile_sheet.dart';
import '../../notifications/widgets/notification_bell.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = context.read<LocationProvider>();
      if (!location.hasLocation) location.getCurrentLocation();
      // Pick up a staff verification that happened since the last sign-in.
      context.read<AuthProvider>().refreshUser();
    });
  }

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
                if (user?.needsRegistrationDecision == true) ...[
                  const _RegistrationDecisionCard(),
                  const SizedBox(height: 18),
                ] else if (user?.registrationPending == true) ...[
                  const EcoBanner(
                    message:
                        'Your registration is waiting for barangay review. You can keep using EcoConnect while staff check your details.',
                    icon: Icons.hourglass_top_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 18),
                ] else if (user?.registrationDeclined == true) ...[
                  const EcoBanner(
                    message:
                        'You declined the barangay approval, so your registration is withdrawn. Contact barangay staff if this was a mistake.',
                    icon: Icons.info_outline_rounded,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(height: 18),
                ],
                if (user?.isGovernment == true &&
                    !user!.isVerifiedGovernment) ...[
                  _VerificationNotice(user: user),
                  const SizedBox(height: 18),
                ],
                const _SectionLabel(title: 'QUICK ACTIONS'),
                const SizedBox(height: 10),
                const _ResidentQuickActions(),
                const SizedBox(height: 24),
                _SectionLabel(
                  title: 'UPCOMING EVENTS',
                  action: 'View all',
                  onAction: () => context.go('/events'),
                ),
                const SizedBox(height: 10),
                const _EventsStrip(),
                const SizedBox(height: 24),
                _SectionLabel(
                  title: 'ANNOUNCEMENTS',
                  action: 'View all',
                  onAction: () => context.go('/announcements'),
                ),
                const SizedBox(height: 10),
                const _LatestAnnouncements(),
                const SizedBox(height: 20),
                HoverLift(
                  child: _TrackPrompt(onTap: () => context.go('/tracking')),
                ),
                const SizedBox(height: 12),
                HoverLift(
                  child: _ReportPrompt(
                    onTap: () => context.go('/report-incident'),
                  ),
                ),
                const SizedBox(height: 12),
                HoverLift(
                  child: _WalletPrompt(onTap: () => context.go('/wallet')),
                ),
                const SizedBox(height: 18),
                const LocationControls(),
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
              NotificationBell(
                iconSize: 19,
                color: AppColors.creamBright,
                circleColor: AppColors.creamBright.withValues(alpha: 0.14),
              ),
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
                child: HoverLift(
                  child: _HeroPill(
                    label: hasAddress ? address : 'No address yet',
                    icon: Icons.location_on_outlined,
                    onTap: onEditProfile,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              HoverLift(
                child: _HeroPill(label: 'Edit profile', onTap: onEditProfile),
              ),
            ],
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

/// The resident's answer to the barangay's registration approval.
///
/// The answer is stored with the date and time, and the barangay desk is told
/// so a declined registration can be closed in the records.
class _RegistrationDecisionCard extends StatefulWidget {
  const _RegistrationDecisionCard();

  @override
  State<_RegistrationDecisionCard> createState() =>
      _RegistrationDecisionCardState();
}

class _RegistrationDecisionCardState extends State<_RegistrationDecisionCard> {
  bool _busy = false;

  Future<void> _answer(bool accepted) async {
    if (!accepted) {
      final ok = await AppFeedback.confirm(
        context,
        title: 'Decline the approval?',
        message: 'Your registration will be withdrawn and barangay staff '
            'will be told. Contact them if you want to restart it.',
        confirmLabel: 'Decline',
        icon: Icons.info_outline_rounded,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final error =
        await context.read<AuthProvider>().answerRegistration(accepted: accepted);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      AppFeedback.error(context, error);
      return;
    }
    AppFeedback.success(
      context,
      accepted ? 'Registration accepted' : 'Registration declined',
    );
  }

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.how_to_reg_rounded,
                    size: 18, color: AppColors.forest),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Barangay approved your registration',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Accept to confirm you are a resident of this barangay. Decline if '
            'the approval was sent to the wrong person or you are not a '
            'resident. Your answer is recorded with the date and time.',
            style: TextStyle(
              fontSize: 9.5,
              height: 1.5,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _answer(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _answer(true),
                    child: _busy
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Government personnel see their verification state on the dashboard so a
/// pending ID never looks like a broken feature.
class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final rejected = user.verificationStatus == VerificationStatus.rejected;
    return EcoBanner(
      message: rejected
          ? 'Your government ID was rejected. ${user.rejectionReason ?? 'Please submit a clearer document.'}'
          : 'Your government account is pending verification. Special collection requests unlock after barangay staff approve your ID.',
      icon: rejected ? Icons.gpp_bad_outlined : Icons.hourglass_top_rounded,
      color: rejected ? AppColors.error : AppColors.warning,
    );
  }
}

class _ResidentQuickActions extends StatelessWidget {
  const _ResidentQuickActions();

  static const _actions = <({
    String label,
    IconData icon,
    String route,
    Color color,
  })>[
    (
      label: 'Upload waste',
      icon: Icons.add_a_photo_outlined,
      route: '/waste-upload',
      color: AppColors.primary,
    ),
    (
      label: 'Request pickup',
      icon: Icons.assignment_outlined,
      route: '/request-collection',
      color: Color(0xFF00695C),
    ),
    (
      label: 'Report uncollected',
      icon: Icons.report_gmailerrorred_outlined,
      route: '/request-collection?kind=uncollected',
      color: Color(0xFFEF6C00),
    ),
    (
      label: 'My requests',
      icon: Icons.fact_check_outlined,
      route: '/my-requests',
      color: Color(0xFF6A1B9A),
    ),
    (
      label: 'My uploads',
      icon: Icons.photo_library_outlined,
      route: '/waste-history',
      color: Color(0xFFEF6C00),
    ),
    (
      label: 'Events',
      icon: Icons.event_available_outlined,
      route: '/events',
      color: Color(0xFF1565C0),
    ),
    (
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      route: '/announcements',
      color: Color(0xFF558B2F),
    ),
    (
      label: 'Complaints',
      icon: Icons.report_outlined,
      route: '/my-complaints',
      color: Color(0xFFD32F2F),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 520 ? 6 : 3;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < _actions.length; i++)
              SizedBox(
                width: width,
                child: FadeSlideIn(
                  index: i,
                  offset: 10,
                  child: HoverLift(
                    child: InkWell(
                      onTap: () => context.push(_actions[i].route),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.sage.withValues(alpha: 0.75),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 34,
                              width: 34,
                              decoration: BoxDecoration(
                                color: _actions[i].color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _actions[i].icon,
                                size: 17,
                                color: _actions[i].color,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              _actions[i].label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 9,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EventsStrip extends StatelessWidget {
  const _EventsStrip();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityEvent>>(
      stream: EventService().watchPublished(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 118,
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final events = (snapshot.data ?? const <CommunityEvent>[])
            .where((e) => e.isUpcoming)
            .take(4)
            .toList(growable: false);
        if (events.isEmpty) {
          return const EcoCard(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.event_outlined,
                    size: 20, color: AppColors.inkMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No upcoming events yet. New community programs appear here.',
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.45,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final event = events[i];
              return GestureDetector(
                onTap: () => context.push('/events'),
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE8F5E9), Color(0xFFD7EED8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.sage.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusBadge(
                            label: event.category.label,
                            color: event.category.color,
                            compact: true,
                          ),
                          const Spacer(),
                          Text(
                            relativeDay(event.startAt),
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 10, color: AppColors.inkMuted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              event.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 8,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LatestAnnouncements extends StatelessWidget {
  const _LatestAnnouncements();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementService().watchPublished(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final items = (snapshot.data ?? const <Announcement>[])
            .take(2)
            .toList(growable: false);
        if (items.isEmpty) {
          return const EcoCard(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.campaign_outlined,
                    size: 20, color: AppColors.inkMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No announcements yet. Barangay updates will appear here.',
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.45,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              EcoCard(
                onTap: () => context.push('/announcements'),
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StatusBadge(
                          label: items[i].category.shortLabel,
                          color: items[i].category.color,
                          icon: items[i].category.icon,
                          compact: true,
                        ),
                        const Spacer(),
                        Text(
                          timeAgo(items[i].publishAt ?? items[i].createdAt),
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      items[i].title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      items[i].body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
