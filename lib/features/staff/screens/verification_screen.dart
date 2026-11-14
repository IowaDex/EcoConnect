import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
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
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Resident applications',
              subtitle:
                  'Accept the residents of Batasan Hills and check their IDs.',
              onBack: () => context.go('/admin-dashboard'),
              actions: const [NotificationBell()],
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sage),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(11),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.inkMuted,
                labelStyle: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Residents', height: 34),
                  Tab(text: 'Government IDs', height: 34),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [_ResidentsTab(), _GovernmentIdsTab()],
              ),
            ),
          ],
        ),
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
          return const LoadingView(label: 'Loading ID submissions');
        }
        if (snapshot.hasError) {
          return ErrorView(message: AppFeedback.describe(snapshot.error!));
        }
        var items = snapshot.data ?? const <VerificationRequest>[];
        if (!_showReviewed) {
          items = items
              .where((r) => r.status == VerificationStatus.pending)
              .toList(growable: false);
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Row(
                children: [
                  Text(
                    '${items.length} submission${items.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        setState(() => _showReviewed = !_showReviewed),
                    child: Text(
                      _showReviewed ? 'Show pending only' : 'Show all',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.badge_outlined,
                      title: 'No ID submissions',
                      message:
                          'Government personnel uploads appear here for review.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _VerificationCard(
                        request: items[i],
                        onApprove: () => _approve(items[i]),
                        onReject: () => _reject(items[i]),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      request.email,
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
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${request.barangay ?? 'Barangay not set'} · submitted ${timeAgo(request.submittedAt)}',
            style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          if (document == null)
            const EcoBanner(
              message: 'No identification document was attached.',
              icon: Icons.error_outline_rounded,
              color: AppColors.error,
            )
          else
            _DocumentPreview(document: document),
          if (request.rejectionReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            EcoBanner(
              message: request.rejectionReason!,
              icon: Icons.info_outline_rounded,
              color: AppColors.error,
            ),
          ],
          if (request.status == VerificationStatus.pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed: onApprove,
                      child: const Text('Approve'),
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
  const _DocumentPreview({required this.document});

  final UploadPayload document;

  @override
  Widget build(BuildContext context) {
    final isPdf = document.isPdf;
    if (isPdf) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              size: 26,
              color: AppColors.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                document.fileName,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        _bytes(document.dataUrl),
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

enum _ResidentAction {
  approveRegistration,
  rejectRegistration,
  verify,
  reject,
  reset,
}

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

class _ResidentsTab extends StatefulWidget {
  const _ResidentsTab();

  @override
  State<_ResidentsTab> createState() => _ResidentsTabState();
}

class _ResidentsTabState extends State<_ResidentsTab> {
  final _service = VerificationService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final users = await context.read<AuthProvider>().getAllUsers();
    final residents =
        users.where((u) => (u['role'] ?? 'user') == 'user').toList();
    // Applications waiting for the desk come first, then the rest by name, so
    // the person reviewing always sees the queue at the top.
    String registration(Map<String, dynamic> u) =>
        (u['registrationStatus'] as String?) ?? 'accepted';
    // A rejected application has already been answered by the desk, so it drops
    // out of the queue instead of sitting on top without any action to take.
    bool needsDesk(Map<String, dynamic> u) =>
        registration(u) == 'pending' &&
        (u['verificationStatus'] ?? 'unverified') != 'rejected';
    residents.sort((a, b) {
      final aPending = needsDesk(a);
      final bPending = needsDesk(b);
      if (aPending != bPending) return aPending ? -1 : 1;
      return ((a['name'] as String?) ?? '')
          .toLowerCase()
          .compareTo(((b['name'] as String?) ?? '').toLowerCase());
    });
    return residents;
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _set(
    Map<String, dynamic> user,
    VerificationStatus status,
  ) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    final openRegistration =
        ((user['registrationStatus'] as String?) ?? 'accepted') == 'pending';
    String? reason;
    if (status == VerificationStatus.rejected) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject account?'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Explain what needs to be corrected',
            ),
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
      if (ok != true) return;
      reason = controller.text.trim();
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
      AppFeedback.success(
        context,
        status == VerificationStatus.verified && openRegistration
            ? 'Registration approved — the resident will accept or decline'
            : 'Verification updated',
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
          return const LoadingView(label: 'Loading residents');
        }
        if (snapshot.hasError) {
          return ErrorView(message: AppFeedback.describe(snapshot.error!));
        }
        final residents = snapshot.data ?? const [];
        if (residents.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No residents yet',
            message:
                'Everyone who signs up appears here. Only residents apply — '
                'driver and guide logins come from City Hall.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          itemCount: residents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final user = residents[i];
            final status = VerificationStatusX.fromName(
              user['verificationStatus'] as String?,
            );
            final accountType = AccountTypeX.fromName(
              user['accountType'] as String?,
            );
            final registration =
                (user['registrationStatus'] as String?) ?? 'accepted';
            // Once the desk rejects the application the decision buttons are
            // done: the card goes quiet until the resident resubmits. Staff can
            // still undo from the overflow menu.
            final rejected = status == VerificationStatus.rejected;
            final awaitingDecision = registration == 'pending' && !rejected;
            return EcoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor: AppColors.lightGreen,
                        child: Text(
                          ((user['name'] as String?) ?? 'R')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (user['name'] as String?) ?? 'Resident',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              '${accountType.shortLabel} · ${(user['barangay'] as String?) ?? 'No barangay'}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                StatusBadge(
                                  label: status.label,
                                  color: status.color,
                                  icon: status.icon,
                                  compact: true,
                                ),
                                // A rejected application would otherwise read
                                // "Rejected" next to "Registration pending",
                                // which is exactly what confused the desk.
                                if (!rejected)
                                  StatusBadge(
                                    label: _registrationLabel(registration),
                                    color: _registrationColor(registration),
                                    compact: true,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<_ResidentAction>(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: AppColors.inkMuted,
                        ),
                        onSelected: (value) => switch (value) {
                          _ResidentAction.approveRegistration => _set(
                            user,
                            VerificationStatus.verified,
                          ),
                          _ResidentAction.rejectRegistration => _set(
                            user,
                            VerificationStatus.rejected,
                          ),
                          _ResidentAction.verify => _set(
                            user,
                            VerificationStatus.verified,
                          ),
                          _ResidentAction.reject => _set(
                            user,
                            VerificationStatus.rejected,
                          ),
                          _ResidentAction.reset => _set(
                            user,
                            VerificationStatus.unverified,
                          ),
                        },
                        itemBuilder: (_) => [
                          if (awaitingDecision) ...[
                            const PopupMenuItem(
                              value: _ResidentAction.approveRegistration,
                              child: Text('Approve registration'),
                            ),
                            const PopupMenuItem(
                              value: _ResidentAction.rejectRegistration,
                              child: Text('Reject registration'),
                            ),
                          ] else ...[
                            const PopupMenuItem(
                              value: _ResidentAction.verify,
                              child: Text('Mark verified'),
                            ),
                            const PopupMenuItem(
                              value: _ResidentAction.reject,
                              child: Text('Reject'),
                            ),
                            const PopupMenuItem(
                              value: _ResidentAction.reset,
                              child: Text('Reset to unverified'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  // The application itself: accept or decline the resident.
                  if (awaitingDecision)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _set(user, VerificationStatus.rejected),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(
                                    color: AppColors.error,
                                  ),
                                ),
                                child: const Text(
                                  'Reject',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 40,
                              child: FilledButton(
                                onPressed: () =>
                                    _set(user, VerificationStatus.verified),
                                child: const Text('Accept resident'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  // Rejected: the buttons are gone on purpose, so say why.
                  else if (rejected && registration == 'pending')
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: AppColors.inkMuted,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Rejected — waiting for the resident to resubmit.',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}
