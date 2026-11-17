import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../announcements/models/announcement.dart';
import '../../announcements/services/announcement_service.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../complaints/models/complaint.dart';
import '../../complaints/services/complaint_service.dart';
import '../../dashboard/widgets/quick_action_grid.dart';
import '../../dashboard/widgets/role_hero.dart';
import '../../dashboard/widgets/role_top_bar.dart';
import '../../events/models/community_event.dart';
import '../../events/services/event_service.dart';
import '../../location/providers/location_provider.dart';
import '../../location/widgets/location_controls.dart';
import '../../requests/models/collection_request.dart';
import '../../requests/services/collection_request_service.dart';
import '../widgets/profile_sheet.dart';
import '../widgets/user_avatar.dart';

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
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const RoleTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  FadeSlideIn(
                    index: 0,
                    child: _ResidentHero(
                      user: user,
                      onEditProfile: () => _showProfile(context),
                    ),
                  ),
                  if (user?.needsRegistrationDecision == true) ...[
                    const SizedBox(height: EcoSpace.md),
                    const _RegistrationDecisionCard(),
                  ] else if (user?.registrationPending == true) ...[
                    const SizedBox(height: EcoSpace.md),
                    const EcoBanner(
                      message:
                          'Your registration is waiting for barangay review. You can keep using EcoConnect while staff check your details.',
                      icon: Icons.hourglass_top_rounded,
                      color: AppColors.warning,
                    ),
                  ] else if (user?.registrationDeclined == true) ...[
                    const SizedBox(height: EcoSpace.md),
                    const EcoBanner(
                      message:
                          'You declined the barangay approval, so your registration is withdrawn. Contact barangay staff if this was a mistake.',
                      icon: Icons.info_outline_rounded,
                      color: AppColors.inkMuted,
                    ),
                  ],
                  if (user?.isGovernment == true &&
                      !user!.isVerifiedGovernment) ...[
                    const SizedBox(height: EcoSpace.md),
                    _VerificationNotice(user: user),
                  ],
                  const SizedBox(height: EcoSpace.xl),
                  const SectionLabel('QUICK ACTIONS'),
                  const SizedBox(height: EcoSpace.sm),
                  const QuickActionGrid(actions: _actions),
                  const SizedBox(height: EcoSpace.xl),
                  SectionLabel(
                    'UPCOMING EVENTS',
                    action: 'View all',
                    onAction: () => context.go('/events'),
                  ),
                  const SizedBox(height: EcoSpace.sm),
                  const _EventsStrip(),
                  const SizedBox(height: EcoSpace.xl),
                  SectionLabel(
                    'ANNOUNCEMENTS',
                    action: 'View all',
                    onAction: () => context.go('/announcements'),
                  ),
                  const SizedBox(height: EcoSpace.sm),
                  const _LatestAnnouncements(),
                  const SizedBox(height: EcoSpace.lg),
                  HoverLift(
                    child: _ReportPrompt(
                      onTap: () => context.go('/report-incident'),
                    ),
                  ),
                  const SizedBox(height: EcoSpace.lg),
                  const LocationControls(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (i) => _onNav(context, i),
        onAskAi: () => context.push('/ask-ai'),
      ),
    );
  }

  static const _actions = <QuickAction>[
    QuickAction(
      label: 'Upload waste',
      icon: Icons.add_a_photo_outlined,
      route: '/waste-upload',
    ),
    QuickAction(
      label: 'Track truck',
      icon: Icons.local_shipping_rounded,
      route: '/tracking',
    ),
    QuickAction(
      label: 'Request pickup',
      icon: Icons.assignment_outlined,
      route: '/request-collection',
    ),
    QuickAction(
      label: 'Uncollected',
      icon: Icons.report_problem_outlined,
      route: '/request-collection?wave=2',
    ),
    QuickAction(
      label: 'My requests',
      icon: Icons.fact_check_outlined,
      route: '/my-requests',
    ),
    QuickAction(
      label: 'My uploads',
      icon: Icons.photo_library_outlined,
      route: '/waste-history',
    ),
    QuickAction(
      label: 'Events',
      icon: Icons.event_available_outlined,
      route: '/events',
    ),
    QuickAction(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      route: '/announcements',
    ),
    QuickAction(
      label: 'Complaints',
      icon: Icons.report_outlined,
      route: '/my-complaints',
    ),
  ];

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

/// The resident hero. Both counters come from the same streams the request
/// and complaint lists use, so the figures and the lists cannot disagree.
class _ResidentHero extends StatefulWidget {
  const _ResidentHero({required this.user, required this.onEditProfile});

  final AppUser? user;
  final VoidCallback onEditProfile;

  @override
  State<_ResidentHero> createState() => _ResidentHeroState();
}

class _ResidentHeroState extends State<_ResidentHero> {
  Stream<List<CollectionRequest>>? _requests;
  Stream<List<Complaint>>? _complaints;

  @override
  void initState() {
    super.initState();
    _bind(widget.user?.uid);
  }

  @override
  void didUpdateWidget(covariant _ResidentHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.uid != widget.user?.uid) _bind(widget.user?.uid);
  }

  void _bind(String? uid) {
    if (uid == null || uid.isEmpty) {
      _requests = null;
      _complaints = null;
      return;
    }
    _requests = CollectionRequestService().watchMine(uid);
    _complaints = ComplaintService().watchMine(uid);
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;
    final complaints = _complaints;

    if (requests == null || complaints == null) return _hero();

    return StreamBuilder<List<CollectionRequest>>(
      stream: requests,
      builder: (context, requestSnapshot) {
        final openRequests =
            (requestSnapshot.data ?? const <CollectionRequest>[])
                .where((request) => request.status.isOpen)
                .length;
        return StreamBuilder<List<Complaint>>(
          stream: complaints,
          builder: (context, complaintSnapshot) {
            final openComplaints =
                (complaintSnapshot.data ?? const <Complaint>[])
                    .where((complaint) => complaint.status.isOpen)
                    .length;
            return _hero(
              openRequests: openRequests,
              openComplaints: openComplaints,
            );
          },
        );
      },
    );
  }

  Widget _hero({int openRequests = 0, int openComplaints = 0}) {
    final user = widget.user;
    final address = user?.fullAddress;

    return RoleHero(
      icon: Icons.person_rounded,
      eyebrow: 'RESIDENT · BATASAN HILLS',
      greeting: greeting(),
      title: user?.displayName ?? 'EcoConnect user',
      subtitle: address == null || address.trim().isEmpty
          ? 'Add your address so staff can find your pickup point.'
          : address,
      leading: UserAvatar(
        photoUrl: user?.photoUrl,
        size: 56,
        background: AppColors.creamBright,
      ),
      stats: [
        RoleStat(
          icon: Icons.assignment_rounded,
          label: 'Open requests',
          value: openRequests,
          accent: AppColors.warning,
        ),
        RoleStat(
          icon: Icons.report_rounded,
          label: 'Open complaints',
          value: openComplaints,
        ),
      ],
      actions: [
        RoleActionPill(
          label: 'Edit profile',
          icon: Icons.edit_outlined,
          onTap: widget.onEditProfile,
        ),
      ],
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
        message:
            'Your registration will be withdrawn and barangay staff '
            'will be told. Contact them if you want to restart it.',
        confirmLabel: 'Decline',
        icon: Icons.info_outline_rounded,
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    final error = await context.read<AuthProvider>().answerRegistration(
      accepted: accepted,
    );
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
                child: const Icon(
                  Icons.how_to_reg_rounded,
                  size: 18,
                  color: AppColors.forest,
                ),
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
              fontSize: 10,
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
              child: const Icon(
                Icons.report_outlined,
                size: 18,
                color: AppColors.forest,
              ),
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
                    style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.moss,
            ),
          ],
        ),
      ),
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
                Icon(Icons.event_outlined, size: 20, color: AppColors.inkMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No upcoming events yet. New community programs appear here.',
                    style: TextStyle(
                      fontSize: 10,
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
                              fontSize: 9,
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
                          const Icon(
                            Icons.place_outlined,
                            size: 10,
                            color: AppColors.inkMuted,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              event.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
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
                Icon(
                  Icons.campaign_outlined,
                  size: 20,
                  color: AppColors.inkMuted,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No announcements yet. Barangay updates will appear here.',
                    style: TextStyle(
                      fontSize: 10,
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
                            fontSize: 9,
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
                        fontSize: 10,
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
