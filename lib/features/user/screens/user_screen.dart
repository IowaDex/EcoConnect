import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/primary_button.dart';
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
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const RoleTopBar(),
            Expanded(
              // Pull to refresh re-reads the profile, so an approval made at
              // the barangay desk unlocks the dashboard without a new login.
              child: RefreshIndicator(
                onRefresh: auth.refreshUser,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    FadeSlideIn(
                      index: 0,
                      child: _ResidentHero(
                        user: user,
                        onEditProfile: () => _showProfile(context),
                      ),
                    ),
                    if (restricted) ...[
                      const SizedBox(height: EcoSpace.md),
                      _VerificationGateCard(user: user!),
                      const SizedBox(height: EcoSpace.md),
                      const _TrackTruckCard(),
                      const SizedBox(height: EcoSpace.xl),
                      const SectionLabel('QUICK ACTIONS'),
                      const SizedBox(height: 4),
                      const Text(
                        'Only truck tracking is open for now. The rest unlocks '
                        'once barangay staff verify your account.',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.45,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: EcoSpace.sm),
                      QuickActionGrid(
                        actions: _restrictedActions,
                        onLocked: (action) =>
                            _showLocked(context, action.lockedNote),
                      ),
                    ] else ...[
                      if (user?.registrationPending == true) ...[
                        const SizedBox(height: EcoSpace.md),
                        const EcoBanner(
                          message:
                              'Your registration is waiting for barangay review. You can keep using EcoConnect while staff check your details.',
                          icon: Icons.hourglass_top_rounded,
                          color: AppColors.warning,
                        ),
                      ],
                      if (user?.isGovernment == true &&
                          !user!.isVerifiedGovernment) ...[
                        const SizedBox(height: EcoSpace.md),
                        _VerificationNotice(user: user),
                      ],
                      const SizedBox(height: EcoSpace.md),
                      const _TrackTruckCard(),
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
                      const LocationControls(),
                    ],
                  ],
                ),
              ),
            ),
          ],
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

  static const _actions = <QuickAction>[
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
    for (final action in _actions)
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

/// The resident's only open feature while the account is not verified.
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

        return EcoCard(
          onTap: () => context.push('/tracking'),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // The truck itself is a tap target too: residents reach for the
              // icon first, so it opens the map without hunting for the pill.
              Tooltip(
                message: 'Track the collection truck',
                child: InkWell(
                  onTap: () => context.push('/tracking'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.forestGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      size: 23,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 6,
                          width: 6,
                          decoration: BoxDecoration(
                            color: live ? AppColors.lime : AppColors.sage,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          live ? 'LIVE TRUCK TRACKING' : 'TRUCK TRACKING',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      live
                          ? 'The collection truck is on the road'
                          : 'Track the next collection',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        height: 1.35,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // A control of its own, so the way into the map is obvious even
              // while every other shortcut on the dashboard is locked.
              Material(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => context.push('/tracking'),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Track',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
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
        );
      },
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

    return EcoCard(
      padding: const EdgeInsets.all(16),
      borderColor: accent.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  rejected
                      ? Icons.gpp_bad_outlined
                      : Icons.verified_user_outlined,
                  size: 19,
                  color: accent,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCOUNT NOT VERIFIED',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rejected
                          ? 'Your ID was rejected'
                          : 'Your ID is being checked',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rejected
                ? 'Barangay staff could not accept your last ID'
                      '${reason == null || reason.isEmpty ? '.' : ': $reason'} '
                      'Upload a clearer photo to try again.'
                : 'Your sign-up ID is with barangay staff. You can track the '
                      'collection truck while you wait; waste uploads, pickup '
                      'requests, complaints and community unlock after '
                      'approval. Upload a clearer photo below if needed.',
            style: const TextStyle(
              fontSize: 10,
              height: 1.5,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
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
