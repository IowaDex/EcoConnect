import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/service_area.dart';
import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../verification/models/verification_request.dart';
import '../../verification/services/verification_service.dart';
import '../../notifications/widgets/notification_bell.dart';

/// User validation desk: pending driver/staff accounts, government ID
/// submissions and the resident directory.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                AppPageHeader(
                  title: 'User validation',
                  subtitle:
                      'Approve logins, check IDs and keep the resident directory clean.',
                  onBack: () => context.go('/admin-dashboard'),
                  actions: const [NotificationBell()],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _DeskTabs(controller: _tabs),
                ),
                const SizedBox(height: EcoSpace.sm),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: const [
                      _PendingAccountsTab(),
                      _GovernmentIdsTab(),
                      _ResidentsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three-way switch between the validation desks.
class _DeskTabs extends StatelessWidget {
  const _DeskTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EcoSpace.xxs),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(EcoRadius.pill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(EcoRadius.pill),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.inkMuted,
        labelStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'Accounts', height: 34),
          Tab(text: 'Government IDs', height: 34),
          Tab(text: 'Residents', height: 34),
        ],
      ),
    );
  }
}

class _PendingAccountsTab extends StatefulWidget {
  const _PendingAccountsTab();

  @override
  State<_PendingAccountsTab> createState() => _PendingAccountsTabState();
}

class _PendingAccountsTabState extends State<_PendingAccountsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AuthProvider>().getPendingAccounts();
  }

  void _reload() {
    setState(() {
      _future = context.read<AuthProvider>().getPendingAccounts();
    });
  }

  Future<void> _approve(Map<String, dynamic> account) async {
    try {
      await context.read<AuthProvider>().approveAccount(
        account['uid'] as String,
      );
      if (!mounted) return;
      AppFeedback.success(
        context,
        '${(account['name'] as String?) ?? 'Account'} approved',
      );
      _reload();
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonList(count: 2, height: 148);
        }
        if (snapshot.hasError) {
          return ErrorView(
            message: AppFeedback.describe(snapshot.error!),
            onRetry: _reload,
          );
        }
        final accounts = snapshot.data ?? const [];
        if (accounts.isEmpty) {
          return const EmptyState(
            icon: Icons.how_to_reg_outlined,
            title: 'No logins waiting',
            message:
                'New driver and staff registrations appear here for approval.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 28),
          itemCount: accounts.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: EcoSpace.sm),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _DeskSummary(
                icon: Icons.person_add_alt_1_rounded,
                title:
                    '${accounts.length} login${accounts.length == 1 ? '' : 's'} waiting for approval',
                message:
                    'Approving unlocks the app for this crew member right away.',
                tint: AppColors.warning,
              );
            }
            final account = accounts[i - 1];
            return FadeSlideIn(
              index: i,
              offset: 8,
              child: _PendingAccountCard(
                account: account,
                onApprove: () => _approve(account),
              ),
            );
          },
        );
      },
    );
  }
}

/// One login waiting for approval: who it is, what it can do, one button.
class _PendingAccountCard extends StatelessWidget {
  const _PendingAccountCard({required this.account, required this.onApprove});

  final Map<String, dynamic> account;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final role = (account['role'] as String?) ?? 'driver';
    final isDriver = role == 'driver';
    final name = (account['name'] as String?) ?? 'Unnamed account';
    final joined = _userDate(account);

    return EcoCard(
      padding: const EdgeInsets.all(EcoSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InitialsAvatar(
                name: name,
                size: 42,
                icon: isDriver
                    ? Icons.local_shipping_outlined
                    : Icons.admin_panel_settings_outlined,
              ),
              const SizedBox(width: EcoSpace.sm + 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      (account['email'] as String?) ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: isDriver ? 'Driver' : 'Barangay staff',
                color: AppColors.forest,
                icon: isDriver
                    ? Icons.local_shipping_outlined
                    : Icons.badge_outlined,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm + 2),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 12,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  (account['barangay'] as String?) ?? 'Barangay not set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              if (joined != null)
                Text(
                  'Registered ${timeAgo(joined)}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm + 2),
          SizedBox(
            height: 38,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Approve account'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                textStyle: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EcoRadius.sm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernmentIdsTab extends StatefulWidget {
  const _GovernmentIdsTab();

  @override
  State<_GovernmentIdsTab> createState() => _GovernmentIdsTabState();
}

class _GovernmentIdsTabState extends State<_GovernmentIdsTab> {
  final _service = VerificationService();
  bool _showReviewed = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VerificationRequest>>(
      stream: _service.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SkeletonList(count: 2, height: 240);
        }
        if (snapshot.hasError) {
          return ErrorView(message: AppFeedback.describe(snapshot.error!));
        }
        final all = snapshot.data ?? const <VerificationRequest>[];
        final pending = all
            .where((r) => r.status == VerificationStatus.pending)
            .length;
        final items = _showReviewed
            ? all
            : all
                  .where((r) => r.status == VerificationStatus.pending)
                  .toList(growable: false);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      pending == 0
                          ? 'No IDs waiting for review'
                          : '$pending ID${pending == 1 ? '' : 's'} waiting for review',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  _MiniToggle(
                    options: const ['Pending', 'All'],
                    selected: _showReviewed ? 1 : 0,
                    onChanged: (index) =>
                        setState(() => _showReviewed = index == 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? EmptyState(
                      icon: Icons.badge_outlined,
                      title: _showReviewed
                          ? 'No ID submissions'
                          : 'Nothing waiting for review',
                      message: _showReviewed
                          ? 'Government personnel uploads appear here for review.'
                          : 'Switch to All to see IDs that were already reviewed.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: EcoSpace.sm),
                      itemBuilder: (context, i) => FadeSlideIn(
                        index: i,
                        offset: 8,
                        child: _VerificationCard(
                          request: items[i],
                          onApprove: () => _approve(items[i]),
                          onReject: () => _reject(items[i]),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approve(VerificationRequest request) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    final ok = await AppFeedback.confirm(
      context,
      title: 'Approve government ID?',
      message:
          '${request.name} will be able to submit special collection requests.',
      confirmLabel: 'Approve',
      icon: Icons.verified_outlined,
    );
    if (!ok || !mounted) return;
    try {
      await _service.approve(
        request: request,
        reviewerId: staff.uid,
        reviewerName: staff.displayName ?? 'Barangay staff',
      );
      if (mounted) AppFeedback.success(context, 'Government ID approved');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  Future<void> _reject(VerificationRequest request) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject ID?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give a clear reason so the applicant can resubmit.',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Blurry photo or expired ID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.reject(
        request: request,
        reviewerId: staff.uid,
        reviewerName: staff.displayName ?? 'Barangay staff',
        reason: controller.text.trim(),
      );
      if (mounted) AppFeedback.success(context, 'Submission rejected');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }
}

/// Compact two-option switch used above a filtered list.
class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(EcoRadius.pill),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: EcoMotion.fast,
                curve: EcoMotion.enter,
                padding: const EdgeInsets.symmetric(
                  horizontal: EcoSpace.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: i == selected ? AppColors.forest : Colors.transparent,
                  borderRadius: BorderRadius.circular(EcoRadius.pill),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: i == selected ? Colors.white : AppColors.inkMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final VerificationRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final document = request.document;
    return EcoCard(
      padding: const EdgeInsets.all(EcoSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _InitialsAvatar(name: request.name, size: 40),
              const SizedBox(width: EcoSpace.sm + 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      request.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: request.status.label,
                color: request.status.color,
                icon: request.status.icon,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 12,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.barangay ?? 'Barangay not set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              Text(
                'Submitted ${timeAgo(request.submittedAt)}',
                style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: EcoSpace.sm + 2),
          if (document == null)
            const EcoBanner(
              message: 'No identification document was attached.',
              icon: Icons.error_outline_rounded,
              color: AppColors.error,
            )
          else
            _DocumentPreview(
              document: document,
              onOpen: () => _openDocument(context, document),
            ),
          if (request.rejectionReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: EcoSpace.sm),
            EcoBanner(
              message: request.rejectionReason!,
              icon: Icons.info_outline_rounded,
              color: AppColors.error,
            ),
          ],
          if (request.status == VerificationStatus.pending) ...[
            const SizedBox(height: EcoSpace.md),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded, size: 15),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.7),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(EcoRadius.sm),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: EcoSpace.sm),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 15),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(EcoRadius.sm),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({required this.document, this.onOpen});

  final UploadPayload document;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    if (document.isPdf) {
      return Container(
        padding: const EdgeInsets.all(EcoSpace.md),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(EcoRadius.sm),
          border: Border.all(color: AppColors.sage),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              size: 24,
              color: AppColors.error,
            ),
            const SizedBox(width: EcoSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const Text(
                    'PDF document',
                    style: TextStyle(fontSize: 9, color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final image = Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(EcoRadius.sm),
          child: Image.memory(
            _bytes(document.dataUrl),
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        if (onOpen != null)
          Positioned(
            right: EcoSpace.xs,
            bottom: EcoSpace.xs,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(EcoRadius.pill),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_full_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Tap to enlarge',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (onOpen == null) return image;
    return GestureDetector(onTap: onOpen, child: image);
  }
}

/// Full-screen view of an uploaded ID, pinch-zoomable on a phone.
void _openDocument(BuildContext context, UploadPayload document) {
  if (document.isPdf) return;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(EcoSpace.md),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
              maxWidth: MediaQuery.sizeOf(ctx).width,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(EcoRadius.md),
              child: InteractiveViewer(
                maxScale: 4,
                child: Image.memory(
                  _bytes(document.dataUrl),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

enum _ResidentAction { approve, reject, reset }

String _registrationLabel(String status) => switch (status) {
  'pending' => 'Registration pending',
  'approved' => 'Awaiting resident',
  'declined' => 'Resident declined',
  _ => 'Registration accepted',
};

Color _registrationColor(String status) => switch (status) {
  'pending' => AppColors.warning,
  'approved' => const Color(0xFF1565C0),
  'declined' => AppColors.error,
  _ => AppColors.primary,
};

/// `createdAt` arrives as a Firestore timestamp on the user document.
DateTime? _userDate(Map<String, dynamic> user) {
  final raw = user['createdAt'];
  if (raw is DateTime) return raw;
  if (raw is Timestamp) return raw.toDate();
  return null;
}

class _ResidentsTab extends StatefulWidget {
  const _ResidentsTab();

  @override
  State<_ResidentsTab> createState() => _ResidentsTabState();
}

class _ResidentsTabState extends State<_ResidentsTab> {
  final _service = VerificationService();
  final _search = TextEditingController();

  List<Map<String, dynamic>>? _all;
  Object? _error;
  bool _loading = true;
  String _query = '';
  String _filter = 'all';
  int _page = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// [silent] keeps the current list on screen while it refreshes, so a
  /// decision does not flash the whole tab back to a skeleton.
  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final users = await context.read<AuthProvider>().getAllUsers();
      if (!mounted) return;
      final residents =
          users.where((u) => (u['role'] ?? 'user') == 'user').toList()
            ..sort(_queueOrder);
      setState(() {
        _all = residents;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Registrations waiting for a decision come first, then the ones the
  /// resident still has to answer, then rejections — newest first in a group.
  static int _queueOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
    final rank = _queueRank(a).compareTo(_queueRank(b));
    if (rank != 0) return rank;
    final left = _userDate(a);
    final right = _userDate(b);
    if (left == null || right == null) return 0;
    return right.compareTo(left);
  }

  static int _queueRank(Map<String, dynamic> user) {
    final registration = (user['registrationStatus'] as String?) ?? 'accepted';
    if (registration == 'pending') return 0;
    if (registration == 'approved') return 1;
    final verification = VerificationStatusX.fromName(
      user['verificationStatus'] as String?,
    );
    if (verification == VerificationStatus.rejected) return 2;
    if (verification == VerificationStatus.unverified) return 3;
    return 4;
  }

  static bool _inFilter(Map<String, dynamic> user, String filter) {
    if (filter == 'all') return true;
    final verification =
        (user['verificationStatus'] as String?) ?? 'unverified';
    if (filter == 'unverified') return verification == 'unverified';
    return ((user['registrationStatus'] as String?) ?? 'accepted') == filter;
  }

  static bool _matchesQuery(Map<String, dynamic> user, String query) {
    if (query.isEmpty) return true;
    final name = ((user['name'] as String?) ?? '').toLowerCase();
    final email = ((user['email'] as String?) ?? '').toLowerCase();
    final barangay = ((user['barangay'] as String?) ?? '').toLowerCase();
    return name.contains(query) ||
        email.contains(query) ||
        barangay.contains(query);
  }

  int _countFor(String filter) {
    final all = _all ?? const <Map<String, dynamic>>[];
    return all.where((u) => _inFilter(u, filter)).length;
  }

  Future<void> _openReview(Map<String, dynamic> user) async {
    final action = await showModalBottomSheet<_ResidentAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResidentSheet(user: user),
    );
    if (action == null || !mounted) return;
    await _apply(user, action);
  }

  Future<void> _apply(Map<String, dynamic> user, _ResidentAction action) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;

    final status = switch (action) {
      _ResidentAction.approve => VerificationStatus.verified,
      _ResidentAction.reject => VerificationStatus.rejected,
      _ResidentAction.reset => VerificationStatus.unverified,
    };

    String? reason;
    if (status == VerificationStatus.rejected) {
      reason = await _askReason(user);
      if (reason == null || !mounted) return;
    }

    try {
      await _service.setUserVerification(
        userId: user['uid'] as String,
        status: status,
        reviewerId: staff.uid,
        reviewerName: staff.displayName ?? 'Barangay staff',
        reason: reason,
      );
      if (!mounted) return;
      AppFeedback.success(context, _resultMessage(user, action));
      await _load(silent: true);
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  /// A rejection without a reason leaves the resident guessing, so the
  /// confirm button stays disabled until something is typed.
  Future<String?> _askReason(Map<String, dynamic> user) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.creamBright,
          title: const Text('Reject this registration?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(user['name'] as String?) ?? 'The resident'} is told why, '
                'so keep it clear and kind.',
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: EcoSpace.sm + 2),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g. The ID photo is blurry',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(controller.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  String _resultMessage(Map<String, dynamic> user, _ResidentAction action) {
    final name = (user['name'] as String?) ?? 'Resident';
    final pending =
        ((user['registrationStatus'] as String?) ?? 'accepted') == 'pending';
    return switch (action) {
      _ResidentAction.approve =>
        pending
            ? 'Approved — $name will accept or decline'
            : '$name is now verified',
      _ResidentAction.reject => 'Rejected — $name was told why',
      _ResidentAction.reset => '$name is back to unverified',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _all == null) {
      return const SkeletonList(count: 3, height: 104);
    }
    if (_error != null && _all == null) {
      return ErrorView(message: AppFeedback.describe(_error!), onRetry: _load);
    }

    final all = _all ?? const <Map<String, dynamic>>[];
    final query = _query.trim().toLowerCase();
    final filtered = all
        .where((user) => _inFilter(user, _filter) && _matchesQuery(user, query))
        .toList(growable: false);
    final page = clampPage(_page, filtered.length, _pageSize);
    final visible = pageSlice(filtered, page, _pageSize);
    final pending = all
        .where(
          (user) =>
              ((user['registrationStatus'] as String?) ?? 'accepted') ==
              'pending',
        )
        .length;

    return Column(
      children: [
        if (pending > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
            child: _DeskSummary(
              icon: Icons.fact_check_outlined,
              title:
                  '$pending registration${pending == 1 ? '' : 's'} waiting for a decision',
              message:
                  'Open a resident to check the ID, then approve or reject.',
              tint: AppColors.warning,
              actionLabel: _filter == 'pending' ? null : 'Show pending',
              onAction: () => setState(() {
                _filter = 'pending';
                _page = 0;
              }),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
          child: EcoSearchField(
            controller: _search,
            hint: 'Search name, email or barangay',
            onChanged: (value) => setState(() {
              _query = value;
              _page = 0;
            }),
          ),
        ),
        _FilterPills(
          options: [
            ('all', 'All', _countFor('all')),
            ('pending', 'Pending', _countFor('pending')),
            ('approved', 'Approved', _countFor('approved')),
            ('accepted', 'Accepted', _countFor('accepted')),
            ('declined', 'Declined', _countFor('declined')),
            ('unverified', 'Unverified', _countFor('unverified')),
          ],
          selected: _filter,
          onChanged: (value) => setState(() {
            _filter = value;
            _page = 0;
          }),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No residents match',
                  message: 'Change the search or filter to see other accounts.',
                  actionLabel: _filter == 'all' && query.isEmpty
                      ? null
                      : 'Clear filters',
                  onAction: _filter == 'all' && query.isEmpty
                      ? null
                      : () {
                          _search.clear();
                          setState(() {
                            _query = '';
                            _filter = 'all';
                            _page = 0;
                          });
                        },
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: EcoSpace.sm),
                  itemBuilder: (context, i) => FadeSlideIn(
                    index: i,
                    offset: 8,
                    child: _ResidentRow(
                      user: visible[i],
                      onOpen: () => _openReview(visible[i]),
                    ),
                  ),
                ),
        ),
        if (filtered.length > _pageSize)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: EcoPaginationBar(
              page: page,
              pageSize: _pageSize,
              total: filtered.length,
              onPageChanged: (value) => setState(() => _page = value),
              onPageSizeChanged: (value) => setState(() {
                _pageSize = value;
                _page = 0;
              }),
            ),
          ),
      ],
    );
  }
}

/// One-line summary above a list: what needs attention and why.
class _DeskSummary extends StatelessWidget {
  const _DeskSummary({
    required this.icon,
    required this.title,
    required this.message,
    required this.tint,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EcoSpace.sm + 2),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(EcoRadius.sm),
            ),
            child: Icon(icon, size: 17, color: tint),
          ),
          const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.35,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.forest,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Scrollable filter pills that carry their own counts.
class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// `(value, label, count)` for each filter.
  final List<(String, String, int)> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: EcoSpace.xs),
        itemBuilder: (context, i) {
          final (value, label, count) = options[i];
          final active = value == selected;
          return GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: EcoMotion.fast,
              curve: EcoMotion.enter,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: active ? AppColors.forest : Colors.white,
                borderRadius: BorderRadius.circular(EcoRadius.pill),
                border: Border.all(
                  color: active
                      ? AppColors.forest
                      : AppColors.sage.withValues(alpha: 0.9),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.forest,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: 0.22)
                          : AppColors.cream,
                      borderRadius: BorderRadius.circular(EcoRadius.pill),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A resident in the directory. The whole row opens the review sheet.
class _ResidentRow extends StatelessWidget {
  const _ResidentRow({required this.user, required this.onOpen});

  final Map<String, dynamic> user;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] as String?) ?? 'Resident';
    final accountType = AccountTypeX.fromName(user['accountType'] as String?);
    final status = VerificationStatusX.fromName(
      user['verificationStatus'] as String?,
    );
    final registration = (user['registrationStatus'] as String?) ?? 'accepted';
    final barangay = (user['barangay'] as String?)?.trim() ?? '';
    final outsideArea = barangay.isNotEmpty && !ServiceArea.covers(barangay);
    final hasId = user['barangayId'] is Map;
    final needsDecision = registration == 'pending';

    return EcoCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(
        EcoSpace.md,
        EcoSpace.md,
        EcoSpace.sm + 2,
        EcoSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InitialsAvatar(name: name, size: 42),
          const SizedBox(width: EcoSpace.sm + 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${accountType.shortLabel} · '
                  '${barangay.isEmpty ? 'No barangay' : barangay}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: EcoSpace.xs + 2),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    StatusBadge(
                      label: status.label,
                      color: status.color,
                      icon: status.icon,
                      compact: true,
                    ),
                    if (registration != 'accepted')
                      StatusBadge(
                        label: _registrationLabel(registration),
                        color: _registrationColor(registration),
                        compact: true,
                      ),
                    if (hasId)
                      const StatusBadge(
                        label: 'ID attached',
                        color: AppColors.moss,
                        icon: Icons.attachment_rounded,
                        compact: true,
                      ),
                    if (outsideArea)
                      const StatusBadge(
                        label: 'Outside Batasan Hills',
                        color: AppColors.warning,
                        icon: Icons.wrong_location_outlined,
                        compact: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: EcoSpace.xs),
          if (needsDecision)
            FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EcoRadius.sm),
                ),
              ),
              child: const Text('Review'),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 9, right: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.inkMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// The review sheet: the ID, the details and the decision in one place.
class _ResidentSheet extends StatelessWidget {
  const _ResidentSheet({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] as String?) ?? 'Resident';
    final email = (user['email'] as String?) ?? '';
    final barangay = (user['barangay'] as String?)?.trim() ?? '';
    final accountType = AccountTypeX.fromName(user['accountType'] as String?);
    final status = VerificationStatusX.fromName(
      user['verificationStatus'] as String?,
    );
    final registration = (user['registrationStatus'] as String?) ?? 'accepted';
    final reason = (user['rejectionReason'] as String?)?.trim() ?? '';
    final document = UploadPayload.fromMap(user['barangayId']);
    final joined = _userDate(user);
    final needsDecision = registration == 'pending';
    final outsideArea = barangay.isNotEmpty && !ServiceArea.covers(barangay);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: EcoSpace.sm),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(EcoRadius.pill),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  20,
                  EcoSpace.md,
                  20,
                  EcoSpace.md,
                ),
                children: [
                  Row(
                    children: [
                      _InitialsAvatar(name: name, size: 48),
                      const SizedBox(width: EcoSpace.sm + 2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.forest,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${accountType.shortLabel} · '
                              '${barangay.isEmpty ? 'No barangay' : barangay}',
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
                  const SizedBox(height: EcoSpace.sm + 2),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      StatusBadge(
                        label: status.label,
                        color: status.color,
                        icon: status.icon,
                        compact: true,
                      ),
                      if (registration != 'accepted')
                        StatusBadge(
                          label: _registrationLabel(registration),
                          color: _registrationColor(registration),
                          compact: true,
                        ),
                      if (outsideArea)
                        const StatusBadge(
                          label: 'Outside Batasan Hills',
                          color: AppColors.warning,
                          icon: Icons.wrong_location_outlined,
                          compact: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: EcoSpace.lg),
                  const SectionLabel('SUBMITTED ID'),
                  const SizedBox(height: EcoSpace.sm),
                  if (document == null)
                    const _Note(
                      icon: Icons.badge_outlined,
                      message:
                          'No ID was uploaded with this registration. Ask the '
                          'resident to submit one before approving.',
                    )
                  else
                    _DocumentPreview(
                      document: document,
                      onOpen: () => _openDocument(context, document),
                    ),
                  const SizedBox(height: EcoSpace.lg),
                  const SectionLabel('DETAILS'),
                  const SizedBox(height: EcoSpace.sm),
                  _DetailRow(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: email.isEmpty ? 'Not set' : email,
                  ),
                  _DetailRow(
                    icon: Icons.place_outlined,
                    label: 'Barangay',
                    value: barangay.isEmpty ? 'Not set' : barangay,
                  ),
                  _DetailRow(
                    icon: Icons.home_outlined,
                    label: 'Account',
                    value: accountType.label,
                  ),
                  _DetailRow(
                    icon: Icons.event_outlined,
                    label: 'Registered',
                    value: joined == null ? 'Unknown' : timeAgo(joined),
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: EcoSpace.md),
                    EcoBanner(
                      message: reason,
                      icon: Icons.info_outline_rounded,
                      color: AppColors.error,
                    ),
                  ],
                ],
              ),
            ),
            _SheetActions(needsDecision: needsDecision),
          ],
        ),
      ),
    );
  }
}

/// Sticky decision bar at the bottom of the review sheet.
class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.needsDecision});

  final bool needsDecision;

  void _close(BuildContext context, _ResidentAction action) =>
      Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final radius = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(EcoRadius.sm),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, EcoSpace.sm, 20, EcoSpace.sm),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.sage)),
      ),
      child: needsDecision
          ? Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => _close(context, _ResidentAction.reject),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.7),
                        ),
                        shape: radius,
                        textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ),
                const SizedBox(width: EcoSpace.sm),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: () => _close(context, _ResidentAction.approve),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Approve registration'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        shape: radius,
                        textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _close(context, _ResidentAction.approve),
                    icon: const Icon(Icons.verified_outlined, size: 17),
                    label: const Text('Mark as verified'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      shape: radius,
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            _close(context, _ResidentAction.reject),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => _close(context, _ResidentAction.reset),
                        child: const Text(
                          'Reset to unverified',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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

/// Muted explanatory block for missing or secondary information.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EcoSpace.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(EcoRadius.sm),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
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
}

/// Icon, label and value on one line inside the review sheet.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EcoSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.inkMuted),
          const SizedBox(width: EcoSpace.sm),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Initials in a mint circle; used instead of a photo everywhere in the desk.
class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, this.size = 40, this.icon});

  final String name;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.mint,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.8)),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.45, color: AppColors.forest)
          : Text(
              _initials(name),
              style: TextStyle(
                fontSize: size * 0.32,
                fontWeight: FontWeight.w800,
                color: AppColors.forest,
              ),
            ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'R';
  final first = parts.first.substring(0, 1);
  if (parts.length == 1) return first.toUpperCase();
  return '$first${parts.last.substring(0, 1)}'.toUpperCase();
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}
