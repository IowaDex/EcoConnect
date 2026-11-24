import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/primary_button.dart';
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
import '../../route/models/collection_route.dart';
import '../../route/services/route_service.dart';
import '../../verification/services/verification_service.dart';
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
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final restricted = user?.isRestrictedResident ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                const RoleTopBar(),
                Expanded(
                  // Pull to refresh re-reads the profile, so an approval made
                  // at the barangay desk unlocks the dashboard without a new
                  // login. The scrim lets the last row of shortcuts dissolve
                  // above the floating nav instead of being cut by its edge.
                  child: Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: auth.refreshUser,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            24 + NavScrim.height,
                          ),
                          children: [
                            FadeSlideIn(
                              index: 0,
                              child: _ResidentHero(
                                user: user,
                                onEditProfile: () => _showProfile(context),
                              ),
                            ),
                            if (restricted)
                              ..._restrictedBody(context, user!)
                            else
                              ..._residentBody(context, user),
                          ],
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: NavScrim(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTap: (i) => _onNav(context, i, restricted: restricted),
        onAskAi: restricted
            ? () => _showLocked(context, 'use the Eco assistant')
            : () => context.push('/ask-ai'),
        disabledIndexes: restricted ? const {1, 2} : const {},
        askAiLocked: restricted,
      ),
    );
  }

  /// Everything a resident can use once the barangay has verified the ID.
  ///
  /// The order is deliberate: the truck they are waiting for, the three things
  /// they came to do, then everything else. The three primary actions are not
  /// repeated in the grid below — one destination, one tile.
  List<Widget> _residentBody(BuildContext context, AppUser? user) {
    final registrationPending = user?.registrationPending == true;
    final governmentPending =
        user?.isGovernment == true && user?.isVerifiedGovernment == false;

    return [
      if (registrationPending) ...[
        const SizedBox(height: EcoSpace.md),
        const EcoBanner(
          message:
              'Your registration is waiting for barangay review. You can keep '
              'using EcoConnect while staff check your details.',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warning,
        ),
      ],
      if (governmentPending) ...[
        const SizedBox(height: EcoSpace.md),
        _VerificationNotice(user: user!),
      ],
      const SizedBox(height: EcoSpace.md),
      const FadeSlideIn(index: 1, child: _TrackTruckCard()),
      const SizedBox(height: EcoSpace.xl),
      const FadeSlideIn(
        index: 2,
        child: DeskSectionHeader(
          icon: Icons.bolt_rounded,
          title: 'Quick actions',
          subtitle:
              'Upload proof, ask for a pickup, or report a street the '
              'truck skipped.',
        ),
      ),
      const SizedBox(height: EcoSpace.sm),
      const FadeSlideIn(index: 3, child: _PrimaryActions()),
      const SizedBox(height: EcoSpace.xl),
      const FadeSlideIn(
        index: 4,
        child: DeskSectionHeader(
          icon: Icons.grid_view_rounded,
          title: 'All services',
        ),
      ),
      const SizedBox(height: EcoSpace.sm),
      const QuickActionGrid(actions: _services),
      const SizedBox(height: EcoSpace.xl),
      FadeSlideIn(
        index: 5,
        child: DeskSectionHeader(
          icon: Icons.event_available_outlined,
          title: 'Coming up',
          trailing: _ViewAll(onTap: () => context.go('/events')),
        ),
      ),
      const SizedBox(height: EcoSpace.sm),
      const _EventsStrip(),
      const SizedBox(height: EcoSpace.xl),
      FadeSlideIn(
        index: 6,
        child: DeskSectionHeader(
          icon: Icons.campaign_outlined,
          title: 'From the barangay',
          trailing: _ViewAll(onTap: () => context.go('/announcements')),
        ),
      ),
      const SizedBox(height: EcoSpace.sm),
      const _LatestAnnouncements(),
      const SizedBox(height: EcoSpace.xl),
      const LocationControls(),
    ];
  }

  /// The locked dashboard. Only the ID card and truck tracking are live, and
  /// every shortcut below says why it is dimmed instead of quietly failing.
  List<Widget> _restrictedBody(BuildContext context, AppUser user) {
    return [
      const SizedBox(height: EcoSpace.md),
      _VerificationGateCard(user: user),
      const SizedBox(height: EcoSpace.md),
      const _TrackTruckCard(),
      const SizedBox(height: EcoSpace.xl),
      const DeskSectionHeader(
        icon: Icons.lock_outline_rounded,
        title: 'Unlocks after approval',
        subtitle:
            'Everything below opens the moment barangay staff verify '
            'your ID.',
      ),
      const SizedBox(height: EcoSpace.sm),
      QuickActionGrid(
        actions: _restrictedActions,
        onLocked: (action) => _showLocked(context, action.lockedNote),
      ),
    ];
  }

  /// The three actions residents reach for most, shown larger than the rest.
  static const _primary = <QuickAction>[
    QuickAction(
      label: 'Upload waste',
      icon: Icons.add_a_photo_outlined,
      route: '/waste-upload',
      lockedNote: 'upload waste photos',
    ),
    QuickAction(
      label: 'Request pickup',
      icon: Icons.assignment_outlined,
      route: '/request-collection',
      lockedNote: 'request a pickup',
    ),
    QuickAction(
      label: 'Report uncollected',
      icon: Icons.report_gmailerrorred_outlined,
      route: '/request-collection?kind=uncollected',
      lockedNote: 'report uncollected garbage',
    ),
  ];

  /// Everything else. The primary three are deliberately absent.
  static const _services = <QuickAction>[
    QuickAction(
      label: 'My requests',
      icon: Icons.fact_check_outlined,
      route: '/my-requests',
      lockedNote: 'follow your pickup requests',
    ),
    QuickAction(
      label: 'My uploads',
      icon: Icons.photo_library_outlined,
      route: '/waste-history',
      lockedNote: 'see your past uploads',
    ),
    QuickAction(
      label: 'Verify my ID',
      icon: Icons.badge_outlined,
      route: '/verify-identity',
    ),
    QuickAction(
      label: 'Collection schedule',
      icon: Icons.calendar_month_outlined,
      route: '/schedule',
      lockedNote: 'see the collection schedule',
    ),
    QuickAction(
      label: 'Events',
      icon: Icons.event_available_outlined,
      route: '/events',
      lockedNote: 'join barangay events',
    ),
    QuickAction(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      route: '/announcements',
      lockedNote: 'read announcements',
    ),
    QuickAction(
      label: 'Complaints',
      icon: Icons.report_outlined,
      route: '/my-complaints',
      lockedNote: 'file a complaint',
    ),
  ];

  /// Every shortcut is locked while the account waits for barangay
  /// verification. ID verification is handled by the card above, so that
  /// shortcut is left out instead of shown as locked.
  List<QuickAction> get _restrictedActions => [
    for (final action in [..._primary, ..._services])
      if (action.route != '/verify-identity')
        QuickAction(
          label: action.label,
          icon: action.icon,
          route: action.route,
          badge: action.badge,
          locked: true,
          lockedNote: action.lockedNote,
        ),
  ];

  /// Names the feature the resident reached for, so the lock message reads
  /// "…before you can file a complaint" instead of a generic refusal.
  void _showLocked(BuildContext context, [String note = '']) =>
      AppFeedback.info(
        context,
        'You need to verify your account first before you can '
        '${note.isEmpty ? 'use this feature' : note}. '
        'Upload your ID above and barangay staff will unlock it.',
      );

  void _onNav(BuildContext context, int index, {required bool restricted}) {
    switch (index) {
      case 0:
        break;
      case 1:
        if (restricted) {
          _showLocked(context, 'check your requests');
          return;
        }
        context.go('/my-requests');
      case 2:
        if (restricted) {
          _showLocked(context, 'open the community');
          return;
        }
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

/// The three things a resident does most, one step larger than the grid.
class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 106,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _UserScreenState._primary.length; i++) ...[
            if (i > 0) const SizedBox(width: EcoSpace.xs),
            Expanded(child: _PrimaryTile(action: _UserScreenState._primary[i])),
          ],
        ],
      ),
    );
  }
}

class _PrimaryTile extends StatelessWidget {
  const _PrimaryTile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: () => context.push(action.route),
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              gradient: AppColors.forestGradient,
              borderRadius: BorderRadius.circular(EcoRadius.sm),
            ),
            child: Icon(action.icon, size: 17, color: Colors.white),
          ),
          const Spacer(),
          Text(
            action.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EcoType.label(context, color: AppColors.forest),
          ),
        ],
      ),
    );
  }
}

/// The small "View all" pill that closes a section header.
class _ViewAll extends StatelessWidget {
  const _ViewAll({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(EcoRadius.pill),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View all',
              style: EcoType.label(context, color: AppColors.primary),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 13,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The resident's window on the collection truck.
///
/// It reads the same live route the map uses, so the status here and the map
/// can never disagree.
class _TrackTruckCard extends StatefulWidget {
  const _TrackTruckCard();

  @override
  State<_TrackTruckCard> createState() => _TrackTruckCardState();
}

class _TrackTruckCardState extends State<_TrackTruckCard> {
  late final Stream<CollectionRoute?> _route = RouteService()
      .watchActiveRoute();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CollectionRoute?>(
      stream: _route,
      builder: (context, snapshot) {
        final route = snapshot.data;
        final live = route != null && !route.isStale;
        final detail = !live
            ? 'No truck is collecting right now. Open the map to check again.'
            : route.etaMinutes != null
            ? '${route.driverName} · about ${route.etaMinutes} min away'
            : '${route.driverName} · ${route.status.label}';
        final updated = live
            ? timeAgo(route.updatedAt ?? route.lastSeenAt)
            : '';

        return DeskRailCard(
          railColor: live ? AppColors.lime : AppColors.sage,
          onTap: () => context.push('/tracking'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LiveDot(active: live),
                  const SizedBox(width: 6),
                  // Expanded, not Flexible + Spacer: the label gives way to the
                  // timestamp instead of pushing it off the row.
                  Expanded(
                    child: Text(
                      live ? 'LIVE TRUCK TRACKING' : 'TRUCK TRACKING',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.eyebrow(
                        context,
                        color: live ? AppColors.moss : AppColors.inkMuted,
                      ),
                    ),
                  ),
                  if (updated.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Updated $updated',
                      maxLines: 1,
                      style: EcoType.meta(context, color: AppColors.inkMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: EcoSpace.sm),
              Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.forestGradient,
                      borderRadius: BorderRadius.circular(EcoRadius.md),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 23,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: EcoSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          live
                              ? 'The collection truck is on the road'
                              : 'Track the next collection',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: EcoType.cardTitle(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: EcoType.bodySmall(
                            context,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: EcoSpace.xs),
                  // A control of its own, so the way into the map is obvious
                  // even while every other shortcut is locked.
                  Material(
                    color: AppColors.forest,
                    borderRadius: BorderRadius.circular(EcoRadius.pill),
                    child: InkWell(
                      onTap: () => context.push('/tracking'),
                      borderRadius: BorderRadius.circular(EcoRadius.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Track',
                              style: EcoType.label(
                                context,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A dot that breathes while the truck is on the road, and sits still when it
/// is not. Motion is the cheapest way to say "this is live".
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.active});

  final bool active;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _LiveDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.moss : AppColors.sage;
    return SizedBox(
      height: 10,
      width: 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.active)
            FadeTransition(
              opacity: Tween<double>(begin: 0.5, end: 0).animate(_pulse),
              child: Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          Container(
            height: 6,
            width: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

/// Shown while the account waits for barangay verification.
///
/// The upload is the one action the resident can take. Everything else on the
/// dashboard stays locked until staff approve the ID, so the screen never
/// looks broken or half-finished.
class _VerificationGateCard extends StatefulWidget {
  const _VerificationGateCard({required this.user});

  final AppUser user;

  @override
  State<_VerificationGateCard> createState() => _VerificationGateCardState();
}

class _VerificationGateCardState extends State<_VerificationGateCard> {
  UploadPayload? _document;
  bool _busy = false;

  Future<void> _submit() async {
    final document = _document;
    if (document == null) {
      AppFeedback.error(context, 'Choose a photo of your ID first.');
      return;
    }
    setState(() => _busy = true);
    try {
      await VerificationService().submitId(
        userId: widget.user.uid,
        name: widget.user.displayName ?? 'Resident',
        email: widget.user.email ?? '',
        phone: widget.user.phone,
        barangay: widget.user.barangay,
        document: document,
      );
      if (!mounted) return;
      setState(() => _document = null);
      // The desk may have approved the account while this screen was open.
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      AppFeedback.success(
        context,
        'ID submitted. Barangay staff will review it shortly.',
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final rejected = user.verificationStatus == VerificationStatus.rejected;
    final reason = user.rejectionReason?.trim();
    final accent = rejected ? AppColors.error : AppColors.warning;

    return DeskRailCard(
      railColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EcoRadius.sm + 2),
                ),
                child: Icon(
                  rejected
                      ? Icons.gpp_bad_outlined
                      : Icons.verified_user_outlined,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: EcoSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rejected ? 'ID REJECTED' : 'ID UNDER REVIEW',
                      style: EcoType.eyebrow(context, color: accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rejected
                          ? 'Send a clearer photo'
                          : 'Your ID is with barangay staff',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.cardTitle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Text(
            rejected
                ? 'Barangay staff could not accept your last ID'
                      '${reason == null || reason.isEmpty ? '.' : ': $reason'} '
                      'Upload a clearer photo to try again.'
                : 'You can track the collection truck while you wait. Waste '
                      'uploads, pickup requests, complaints and community '
                      'unlock after approval. Upload a clearer photo below if '
                      'needed.',
            style: EcoType.bodySmall(context, color: AppColors.inkMuted),
          ),
          const SizedBox(height: EcoSpace.md),
          ImagePickerField(
            value: _document,
            onChanged: (value) => setState(() => _document = value),
            label: rejected
                ? 'Upload a new ID'
                : 'Valid ID or proof of residence',
            helper:
                'JPG, PNG or PDF · name and Batasan Hills address must be '
                'readable',
            documentMode: true,
            previewHeight: 150,
          ),
          const SizedBox(height: EcoSpace.md),
          PrimaryButton(
            label: rejected
                ? 'Resubmit my ID'
                : user.verificationStatus == VerificationStatus.pending
                ? 'Replace my ID'
                : 'Submit ID for review',
            loading: _busy,
            onPressed: _submit,
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

/// The next few barangay events, as a swipeable row.
class _EventsStrip extends StatelessWidget {
  const _EventsStrip();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CommunityEvent>>(
      stream: EventService().watchPublished(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 112, child: _StripSkeleton());
        }
        final events = (snapshot.data ?? const <CommunityEvent>[])
            .where((e) => e.isUpcoming)
            .take(4)
            .toList(growable: false);
        if (events.isEmpty) {
          return const _QuietCard(
            icon: Icons.event_outlined,
            message:
                'No upcoming events yet. New community programs appear here.',
          );
        }
        return SizedBox(
          height: 112,
          child: Stack(
            children: [
              ListView.separated(
                scrollDirection: Axis.horizontal,
                // The row is wider than a phone, so it ends with air and a
                // fade instead of a card sliced by the screen edge.
                padding: const EdgeInsets.only(right: 26),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(width: EcoSpace.sm),
                itemBuilder: (context, i) {
                  final event = events[i];
                  return SizedBox(
                    width: 198,
                    child: DeskRailCard(
                      railColor: event.category.color,
                      onTap: () => context.push('/events'),
                      padding: const EdgeInsets.fromLTRB(17, 11, 11, 11),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _DayChip(date: event.startAt),
                              const Spacer(),
                              Text(
                                relativeDay(event.startAt),
                                style: EcoType.label(
                                  context,
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
                            style: EcoType.cardTitle(context),
                          ),
                          const SizedBox(height: 3),
                          DeskFact(
                            icon: Icons.place_outlined,
                            text: event.location,
                            color: AppColors.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const _EdgeFade(),
            ],
          ),
        );
      },
    );
  }
}

/// MON / 24, the way a calendar page reads at a glance.
class _DayChip extends StatelessWidget {
  const _DayChip({required this.date});

  final DateTime date;

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.sm),
      ),
      child: Text(
        '${_months[date.month - 1]} ${date.day}',
        style: EcoType.eyebrow(context, color: AppColors.forest),
      ),
    );
  }
}

/// The two newest announcements, read straight from the same feed the
/// announcements screen uses.
class _LatestAnnouncements extends StatelessWidget {
  const _LatestAnnouncements();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementService().watchPublished(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 104, child: _StripSkeleton());
        }
        final items = (snapshot.data ?? const <Announcement>[])
            .take(2)
            .toList(growable: false);
        if (items.isEmpty) {
          return const _QuietCard(
            icon: Icons.campaign_outlined,
            message: 'No announcements yet. Barangay updates will appear here.',
          );
        }
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: EcoSpace.sm),
              _AnnouncementCard(announcement: items[i]),
            ],
          ],
        );
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return DeskRailCard(
      railColor: announcement.category.color,
      onTap: () => context.push('/announcements'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(
                label: announcement.category.shortLabel,
                color: announcement.category.color,
                icon: announcement.category.icon,
                compact: true,
              ),
              const Spacer(),
              Text(
                timeAgo(announcement.publishAt ?? announcement.createdAt),
                style: EcoType.meta(context, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (announcement.image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(EcoRadius.sm),
                  child: Image.memory(
                    _bytes(announcement.image!.dataUrl),
                    height: 54,
                    width: 54,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: EcoSpace.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.cardTitle(context),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      announcement.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EcoType.bodySmall(
                        context,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single quiet line where a feed would be. Cheaper and calmer than an
/// empty-state panel inside an already long dashboard.
class _QuietCard extends StatelessWidget {
  const _QuietCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Text(
              message,
              style: EcoType.bodySmall(context, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripSkeleton extends StatelessWidget {
  const _StripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 26),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: EcoSpace.sm),
            const Expanded(child: SkeletonBox(height: double.infinity)),
          ],
        ],
      ),
    );
  }
}

/// Right-edge fade for a horizontal row that runs past the screen.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 26,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.background.withValues(alpha: 0),
                AppColors.background,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}
