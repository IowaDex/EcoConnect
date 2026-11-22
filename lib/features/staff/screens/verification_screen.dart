import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/role_hero.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../verification/models/verification_request.dart';
import '../../verification/services/verification_service.dart';
import '../widgets/remove_resident.dart';
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
    return EcoPageScaffold(
      eyebrow: 'BARANGAY STAFF · RESIDENT VALIDATION',
      title: 'Resident validation',
      subtitle:
          'Check each resident’s ID before their account unlocks '
          'barangay services.',
      onBack: () => ecoBack(context, '/admin-dashboard'),
      actions: const [NotificationBell()],
      body: const _ResidentsTab(),
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
  remove,
}

String _registrationLabel(String status) => switch (status) {
  'pending' => 'Registration pending',
  // Approvals are accepted on the spot now; 'approved' only survives on
  // records created before the resident's second answer was removed.
  'approved' => 'Registration approved',
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

/// How long an account has been in the queue. A clerk triages by waiting
/// time, so the card says it instead of making them open the record.
String? _waitingLabel(DateTime? createdAt) {
  if (createdAt == null) return null;
  final elapsed = DateTime.now().difference(createdAt);
  if (elapsed.isNegative || elapsed.inMinutes < 60) return 'New';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h';
  return '${elapsed.inDays}d';
}

DateTime? _createdAt(Map<String, dynamic> user) {
  final raw = user['createdAt'];
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
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
  String _query = '';
  String? _status;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The queue order a clerk expects: waiting first, then the ones that need
  /// correcting, then everyone already cleared. Oldest first inside a group.
  static int _rank(String? status) => switch (status) {
    'pending' => 0,
    'rejected' => 1,
    'unverified' => 2,
    _ => 3,
  };

  /// Keeps the residents whose name, email or street matches the search box
  /// and whose verification status matches the chosen filter.
  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> users) {
    final q = _query.trim().toLowerCase();
    final list = users.where((u) {
      final status = VerificationStatusX.fromName(
        u['verificationStatus'] as String?,
      );
      if (_status != null && status.name != _status) return false;
      if (q.isEmpty) return true;
      final name = '${u['name'] ?? ''}'.toLowerCase();
      final email = '${u['email'] ?? ''}'.toLowerCase();
      final street = '${u['houseStreet'] ?? ''}'.toLowerCase();
      return name.contains(q) || email.contains(q) || street.contains(q);
    }).toList();

    list.sort((a, b) {
      final rank = _rank(
        a['verificationStatus'] as String?,
      ).compareTo(_rank(b['verificationStatus'] as String?));
      if (rank != 0) return rank;
      final aDate = _createdAt(a);
      final bDate = _createdAt(b);
      if (aDate != null && bDate != null && aDate != bDate) {
        return aDate.compareTo(bDate);
      }
      return '${a['name'] ?? ''}'.toLowerCase().compareTo(
        '${b['name'] ?? ''}'.toLowerCase(),
      );
    });
    return list;
  }

  /// Totals for the summary card and the filter cells. Computed once per
  /// build from the same list, so the figures can never disagree.
  Map<String, int> _counts(List<Map<String, dynamic>> users) {
    var pending = 0;
    var verified = 0;
    var rejected = 0;
    for (final user in users) {
      switch (VerificationStatusX.fromName(
        user['verificationStatus'] as String?,
      )) {
        case VerificationStatus.pending:
          pending++;
        case VerificationStatus.verified:
          verified++;
        case VerificationStatus.rejected:
          rejected++;
        case VerificationStatus.unverified:
          break;
      }
    }
    return {
      'all': users.length,
      'pending': pending,
      'verified': verified,
      'rejected': rejected,
    };
  }

  /// The resident's details and ID, with Approve / Reject.
  Future<void> _viewId(Map<String, dynamic> user) async {
    // The list is live, so the decision shows up without a manual reload.
    await showResidentReview(context, user);
  }

  /// Deletes an account that no longer belongs to the barangay. The list is
  /// live, so the card disappears on its own once the profile is gone.
  Future<void> _removeResident(Map<String, dynamic> user) async {
    final name = (user['name'] as String?)?.trim();
    if (!await confirmRemoveResident(context, name)) return;
    if (!mounted) return;
    try {
      await deleteResidentAccount(user['uid'] as String);
      if (!mounted) return;
      AppFeedback.success(context, '${name ?? 'Resident'} removed.');
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
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
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Reason (shown to the resident)',
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
      reason = controller.text.trim();
      controller.dispose();
      if (ok != true) return;
      // The review sheet already insists on a reason; the quick menu does the
      // same so a resident never gets a rejection with no explanation.
      if (reason.isEmpty) {
        if (mounted) {
          AppFeedback.error(context, 'Give the resident a reason.');
        }
        return;
      }
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

  void _select(String? status) {
    setState(() {
      _status = status;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<AuthProvider>().watchResidents(),
      builder: (context, usersSnap) {
        if (usersSnap.hasError) {
          return ErrorView(message: AppFeedback.describe(usersSnap.error!));
        }
        final loading =
            usersSnap.connectionState == ConnectionState.waiting &&
            !usersSnap.hasData;
        final residents = usersSnap.data ?? const <Map<String, dynamic>>[];
        final counts = _counts(residents);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: _ValidationSummary(
                counts: counts,
                selected: _status,
                onSelect: _select,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: EcoSearchField(
                controller: _search,
                hint: 'Search name, email or street',
                onChanged: (value) => setState(() {
                  _query = value;
                  _page = 0;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _StatusFilterBar(
                selected: _status,
                counts: counts,
                onChanged: _select,
              ),
            ),
            Expanded(child: _body(residents, loading)),
          ],
        );
      },
    );
  }

  Widget _body(List<Map<String, dynamic>> residents, bool loading) {
    if (loading) return const _ResidentsSkeleton();
    if (residents.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No residents yet',
        message:
            'Residents who sign up in Barangay Batasan Hills appear here for '
            'validation.',
      );
    }

    final list = _filter(residents);
    return StreamBuilder<List<VerificationRequest>>(
      stream: _service.watchAll(),
      builder: (context, idsSnap) {
        // One lookup for the "ID on file" badge instead of a read per row.
        final ids = {
          for (final request in idsSnap.data ?? const <VerificationRequest>[])
            request.userId: request,
        };
        final page = clampPage(_page, list.length, _pageSize);
        final visible = pageSlice(list, page, _pageSize);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 9, 18, 1),
              child: EcoResultCount(
                shown: list.length,
                total: residents.length,
                singular: 'resident',
                plural: 'residents',
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? _noMatch()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 9, 18, 10),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (context, i) =>
                          _residentCard(visible[i], ids[visible[i]['uid']], i),
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
  }

  Widget _noMatch() {
    final filtered = _status != null || _query.trim().isNotEmpty;
    return EmptyState(
      compact: true,
      icon: filtered ? Icons.filter_alt_off_rounded : Icons.inbox_outlined,
      title: filtered ? 'Nothing in this queue' : 'Nothing to review',
      message: filtered
          ? 'No resident matches the search and filter you picked.'
          : 'Every account in the barangay has been checked.',
      actionLabel: filtered ? 'Show all residents' : null,
      onAction: filtered
          ? () {
              _search.clear();
              setState(() {
                _query = '';
                _status = null;
                _page = 0;
              });
            }
          : null,
    );
  }

  Widget _residentCard(
    Map<String, dynamic> user,
    VerificationRequest? idRequest,
    int index,
  ) {
    final status = VerificationStatusX.fromName(
      user['verificationStatus'] as String?,
    );
    final accountType = AccountTypeX.fromName(user['accountType'] as String?);
    final registration = (user['registrationStatus'] as String?) ?? 'accepted';
    // A sign-up whose email never arrived can still be approved: the ID check
    // is the stronger proof, and approving it also records the confirmation.
    final awaitingEmail =
        user['accountStatus'] == 'pending' && user['emailVerified'] != true;
    final hasId = idRequest?.document != null;
    final pending = status == VerificationStatus.pending;
    final waiting = pending ? _waitingLabel(_createdAt(user)) : null;
    final name = (user['name'] as String?)?.trim();
    final displayName = (name == null || name.isEmpty)
        ? 'Unnamed resident'
        : name;
    final email = (user['email'] as String?)?.trim() ?? '';
    final street = [
      (user['houseStreet'] as String?)?.trim(),
      (user['subdivision'] as String?)?.trim(),
    ].whereType<String>().where((p) => p.isNotEmpty).join(' · ');

    return FadeSlideIn(
      index: index,
      offset: 10,
      duration: const Duration(milliseconds: 300),
      stagger: const Duration(milliseconds: 32),
      child: EcoCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        onTap: () => _viewId(user),
        child: Row(
          children: [
            _ResidentAvatar(name: displayName, status: status),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (waiting != null) ...[
                        const SizedBox(width: 6),
                        _WaitingTag(label: waiting),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        accountType.icon,
                        size: 10,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          email.isNotEmpty
                              ? email
                              : (street.isNotEmpty
                                    ? street
                                    : accountType.shortLabel),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      StatusBadge(
                        label: status.label,
                        color: status.color,
                        icon: status.icon,
                        compact: true,
                      ),
                      // Only the exceptions earn a second badge; a resident
                      // whose registration was accepted needs no reminder.
                      if (registration != 'accepted')
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
            const SizedBox(width: 2),
            if (pending) _OpenBadge(onTap: () => _viewId(user)),
            _menu(user, registration),
          ],
        ),
      ),
    );
  }

  Widget _menu(Map<String, dynamic> user, String registration) {
    return PopupMenuButton<_ResidentAction>(
      padding: EdgeInsets.zero,
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
        _ResidentAction.reset => _set(user, VerificationStatus.unverified),
        _ResidentAction.remove => _removeResident(user),
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _ResidentAction.viewId,
          child: Text('View ID'),
        ),
        if (registration == 'pending') ...[
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
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _ResidentAction.remove,
          child: Text(
            'Remove resident',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}

/// The desk's own header: how many accounts wait, how many are clear, and
/// which ones were turned back. Each figure is a shortcut to that filter.
class _ValidationSummary extends StatelessWidget {
  const _ValidationSummary({
    required this.counts,
    required this.selected,
    required this.onSelect,
  });

  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final total = counts['all'] ?? 0;
    final pending = counts['pending'] ?? 0;
    final verified = counts['verified'] ?? 0;
    final share = total == 0 ? 0.0 : verified / total;

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.circular(EcoRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDeep.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            right: -42,
            top: -56,
            child: RoleHeroRing(size: 148, opacity: 0.08),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 26,
                      width: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'VALIDATION QUEUE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                    RoleChip(
                      label: pending == 0 ? 'All clear' : '$pending waiting',
                      icon: pending == 0
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_top_rounded,
                      tone: pending == 0 ? null : AppColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FigureTap(
                        active: selected == 'pending',
                        onTap: () => onSelect('pending'),
                        child: RoleStatFigure(
                          stat: RoleStat(
                            icon: Icons.hourglass_top_rounded,
                            label: 'Pending',
                            value: pending,
                            accent: AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FigureTap(
                        active: selected == 'verified',
                        onTap: () => onSelect('verified'),
                        child: RoleStatFigure(
                          stat: RoleStat(
                            icon: Icons.verified_rounded,
                            label: 'Verified',
                            value: verified,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _FigureTap(
                        active: selected == 'rejected',
                        onTap: () => onSelect('rejected'),
                        child: RoleStatFigure(
                          stat: RoleStat(
                            icon: Icons.gpp_bad_outlined,
                            label: 'Rejected',
                            value: counts['rejected'] ?? 0,
                            accent: const Color(0xFFFFB4A9),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                GrowBar(
                  value: share,
                  height: 4,
                  color: const Color(0xFFB9F6CA),
                  background: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(height: 7),
                Text(
                  total == 0
                      ? 'No residents registered yet'
                      : '$verified of $total residents verified',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.62),
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

/// A summary figure that filters the list when tapped, with a soft ring while
/// its filter is the active one and a wash while the pointer rests on it.
class _FigureTap extends StatefulWidget {
  const _FigureTap({
    required this.child,
    required this.active,
    required this.onTap,
  });

  final Widget child;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_FigureTap> createState() => _FigureTapState();
}

class _FigureTapState extends State<_FigureTap> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: EcoMotion.fast,
          curve: EcoMotion.enter,
          padding: const EdgeInsets.fromLTRB(7, 6, 7, 7),
          decoration: BoxDecoration(
            color: highlighted
                ? Colors.white.withValues(alpha: widget.active ? 0.12 : 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(EcoRadius.sm),
            border: Border.all(
              color: highlighted
                  ? Colors.white.withValues(alpha: widget.active ? 0.28 : 0.16)
                  : Colors.transparent,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// The four queue filters. Counts sit on the right edge so they line up in a
/// column, and the active cell fills with the brand gradient.
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final String? selected;
  final Map<String, int> counts;
  final ValueChanged<String?> onChanged;

  static const _items = <(String, String?, Color)>[
    ('All', null, AppColors.inkMuted),
    ('Pending', 'pending', AppColors.warning),
    ('Verified', 'verified', AppColors.primary),
    ('Rejected', 'rejected', AppColors.error),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 7.0;
        final width =
            (constraints.maxWidth - gap * (_items.length - 1)) / _items.length;
        return Row(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: width,
                child: _FilterCell(
                  label: _items[i].$1,
                  accent: _items[i].$3,
                  count: counts[_items[i].$2 ?? 'all'] ?? 0,
                  selected: selected == _items[i].$2,
                  onTap: () => onChanged(_items[i].$2),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FilterCell extends StatefulWidget {
  const _FilterCell({
    required this.label,
    required this.accent,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterCell> createState() => _FilterCellState();
}

class _FilterCellState extends State<_FilterCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final foreground = selected ? Colors.white : AppColors.forest;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: EcoMotion.fast,
          curve: EcoMotion.enter,
          height: 38,
          padding: const EdgeInsets.only(left: 9, right: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.forest
                : (_hovered ? AppColors.mintSoft : Colors.white),
            borderRadius: BorderRadius.circular(EcoRadius.sm),
            border: Border.all(
              color: selected
                  ? AppColors.forest
                  : (_hovered
                        ? AppColors.primary.withValues(alpha: 0.45)
                        : AppColors.sage.withValues(alpha: 0.85)),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.forest.withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              AnimatedContainer(
                duration: EcoMotion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : widget.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EcoRadius.pill),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : widget.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initials avatar ringed in the resident's verification colour, with a check
/// seal once the desk has cleared them.
class _ResidentAvatar extends StatelessWidget {
  const _ResidentAvatar({required this.name, required this.status});

  final String name;
  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'R' : name.substring(0, 1).toUpperCase();
    final verified = status == VerificationStatus.verified;

    return SizedBox(
      height: 44,
      width: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 44,
            width: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: status.color.withValues(alpha: 0.35)),
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: status.color,
              ),
            ),
          ),
          if (verified)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                height: 16,
                width: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The waiting-time pill on a pending card (`New`, `3h`, `2d`).
class _WaitingTag extends StatelessWidget {
  const _WaitingTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(EcoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 9, color: AppColors.warning),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

/// The one tap a pending row needs: open the record. A compact disc keeps the
/// name column wide on a phone, and fills with the brand gradient on hover.
class _OpenBadge extends StatefulWidget {
  const _OpenBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_OpenBadge> createState() => _OpenBadgeState();
}

class _OpenBadgeState extends State<_OpenBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Review ID',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovered ? 1.08 : 1,
            duration: EcoMotion.fast,
            curve: EcoMotion.enter,
            child: AnimatedContainer(
              duration: EcoMotion.fast,
              curve: EcoMotion.enter,
              height: 30,
              width: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovered ? AppColors.primary : AppColors.lightGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(
                    alpha: _hovered ? 1 : 0.22,
                  ),
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 15,
                color: _hovered ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card-shaped placeholders that match the resident row, so the page does not
/// jump when the first snapshot lands.
class _ResidentsSkeleton extends StatelessWidget {
  const _ResidentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
        ),
        child: const Row(
          children: [
            SkeletonBox(width: 44, height: 44, radius: 22),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 118, height: 11, radius: 6),
                  SizedBox(height: 7),
                  SkeletonBox(width: 156, height: 9, radius: 5),
                  SizedBox(height: 8),
                  SkeletonBox(width: 196, height: 13, radius: 7),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
