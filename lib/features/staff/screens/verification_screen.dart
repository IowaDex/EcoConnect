import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../verification/models/verification_request.dart';
import '../../verification/services/verification_service.dart';
import '../widgets/resident_review_sheet.dart';

/// Resident validation desk: the barangay checks residents only. Drivers,
/// guides and staff are created by Iswim and City Hall, and there are no
/// separate government-ID submissions any more.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Resident validation',
              subtitle:
                  'Check each resident’s ID before they unlock barangay '
                  'services. Drivers and staff are created by Iswim and City '
                  'Hall.',
              onBack: () => context.go('/admin-dashboard'),
              actions: const [NotificationBell()],
            ),
            const SizedBox(height: 6),
            const Expanded(child: _ResidentsTab()),
          ],
        ),
      ),
    );
  }
}

enum _ResidentAction {
  viewId,
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
  'rejected' => 'Registration rejected',
  _ => 'Registration accepted',
};

Color _registrationColor(String status) => switch (status) {
  'pending' => AppColors.warning,
  'approved' => const Color(0xFF1565C0),
  'declined' => AppColors.error,
  'rejected' => AppColors.error,
  _ => AppColors.primary,
};

class _ResidentsTab extends StatefulWidget {
  const _ResidentsTab();

  @override
  State<_ResidentsTab> createState() => _ResidentsTabState();
}

class _ResidentsTabState extends State<_ResidentsTab> {
  final _service = VerificationService();
  final _search = TextEditingController();
  String _query = '';
  String? _status;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Keeps the residents whose name, email or street matches the search box
  /// and whose verification status matches the chosen chip.
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> users) {
    final q = _query.trim().toLowerCase();
    return users.where((u) {
      if (_status != null &&
          VerificationStatusX.fromName(
                u['verificationStatus'] as String?,
              ).name !=
              _status) {
        return false;
      }
      if (q.isEmpty) return true;
      final name = '${u['name'] ?? ''}'.toLowerCase();
      final email = '${u['email'] ?? ''}'.toLowerCase();
      final street = '${u['houseStreet'] ?? ''}'.toLowerCase();
      return name.contains(q) || email.contains(q) || street.contains(q);
    }).toList();
  }

  /// The resident's details and ID, with Approve / Reject.
  Future<void> _viewId(Map<String, dynamic> user) async {
    // The list is live, so the decision shows up without a manual reload.
    await showResidentReview(context, user);
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
            ? 'Registration approved — the resident can now sign in'
            : 'Verification updated',
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<AuthProvider>().watchResidents(),
      builder: (context, usersSnap) {
        if (usersSnap.connectionState == ConnectionState.waiting) {
          return const LoadingView(label: 'Loading residents');
        }
        if (usersSnap.hasError) {
          return ErrorView(message: AppFeedback.describe(usersSnap.error!));
        }
        final residents = usersSnap.data ?? const [];
        if (residents.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No residents yet',
            message: 'Registered residents appear here for validation.',
          );
        }
        return StreamBuilder<List<VerificationRequest>>(
          stream: _service.watchAll(),
          builder: (context, idsSnap) {
            // One lookup for the "ID on file" badge instead of a read per row.
            final ids = {
              for (final request
                  in idsSnap.data ?? const <VerificationRequest>[])
                request.userId: request,
            };
            final list = _filter(residents);
            final page = clampPage(_page, list.length, _pageSize);
            final visible = pageSlice(list, page, _pageSize);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                  child: EcoSearchField(
                    controller: _search,
                    hint: 'Search name, email or street',
                    onChanged: (value) => setState(() {
                      _query = value;
                      _page = 0;
                    }),
                  ),
                ),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    children: [
                      for (final entry in const <(String, String?)>[
                        ('All', null),
                        ('Pending', 'pending'),
                        ('Verified', 'verified'),
                        ('Rejected', 'rejected'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(
                              entry.$1,
                              style: const TextStyle(fontSize: 9.5),
                            ),
                            selected: _status == entry.$2,
                            onSelected: (_) => setState(() {
                              _status = entry.$2;
                              _page = 0;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
                  child: EcoResultCount(
                    shown: list.length,
                    total: residents.length,
                    singular: 'resident',
                    plural: 'residents',
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Text(
                              'No resident matches the search and filter.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) =>
                              _residentCard(visible[i], ids[visible[i]['uid']]),
                        ),
                ),
                if (list.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    child: EcoPaginationBar(
                      page: page,
                      pageSize: _pageSize,
                      total: list.length,
                      onPageChanged: (next) => setState(() => _page = next),
                      onPageSizeChanged: (size) => setState(() {
                        _pageSize = size;
                        _page = 0;
                      }),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _residentCard(
    Map<String, dynamic> user,
    VerificationRequest? idRequest,
  ) {
    final status = VerificationStatusX.fromName(
      user['verificationStatus'] as String?,
    );
    final accountType = AccountTypeX.fromName(user['accountType'] as String?);
    final registration = (user['registrationStatus'] as String?) ?? 'accepted';
    // A new sign-up must confirm its email before the barangay can approve it.
    final awaitingEmail =
        user['accountStatus'] == 'pending' && user['emailVerified'] != true;
    final hasId = idRequest?.document != null;

    return EcoCard(
      onTap: () => _viewId(user),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.lightGreen,
            child: Text(
              ((user['name'] as String?) ?? 'R').substring(0, 1).toUpperCase(),
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
                    StatusBadge(
                      label: _registrationLabel(registration),
                      color: _registrationColor(registration),
                      compact: true,
                    ),
                    if (hasId)
                      const StatusBadge(
                        label: 'ID on file',
                        color: AppColors.primary,
                        icon: Icons.badge_outlined,
                        compact: true,
                      ),
                    if (awaitingEmail)
                      const StatusBadge(
                        label: 'Email not verified',
                        color: AppColors.warning,
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
              _ResidentAction.viewId => _viewId(user),
              _ResidentAction.approveRegistration => _set(
                user,
                VerificationStatus.verified,
              ),
              _ResidentAction.rejectRegistration => _set(
                user,
                VerificationStatus.rejected,
              ),
              _ResidentAction.verify => _set(user, VerificationStatus.verified),
              _ResidentAction.reject => _set(user, VerificationStatus.rejected),
              _ResidentAction.reset => _set(
                user,
                VerificationStatus.unverified,
              ),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _ResidentAction.viewId,
                child: Text('View ID'),
              ),
              if (registration == 'pending' && !awaitingEmail) ...[
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
    );
  }
}
