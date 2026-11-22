import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/account_type.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/role_hero.dart';
import '../../verification/services/verification_service.dart';
import 'remove_resident.dart';

/// Opens the resident's details and ID. Returns true once a decision was
/// saved, so the caller can refresh its list.
Future<bool> showResidentReview(
  BuildContext context,
  Map<String, dynamic> account,
) async {
  final decided = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.creamBright,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ResidentReviewSheet(
      account: account,
      verification: VerificationService(),
    ),
  );
  return decided == true;
}

/// Everything the resident entered, their ID, and the barangay's decision.
/// Pops `true` once a decision is saved.
class ResidentReviewSheet extends StatefulWidget {
  const ResidentReviewSheet({
    super.key,
    required this.account,
    required this.verification,
  });

  final Map<String, dynamic> account;
  final VerificationService verification;

  @override
  State<ResidentReviewSheet> createState() => _ResidentReviewSheetState();
}

class _ResidentReviewSheetState extends State<ResidentReviewSheet> {
  late final Future<String?> _idDataUrl = widget.verification
      .fetchForUser(widget.account['uid'] as String)
      .then((request) => request?.document?.dataUrl);
  bool _busy = false;

  Map<String, dynamic> get _a => widget.account;

  DateTime? get _birthdate {
    final raw = _a['birthdate'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  int? _ageFromBirthdate() {
    final born = _birthdate;
    if (born == null) {
      final raw = _a['age'];
      return raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    }
    final now = DateTime.now();
    var years = now.year - born.year;
    if (now.month < born.month ||
        (now.month == born.month && now.day < born.day)) {
      years--;
    }
    return years;
  }

  String? _birthdateLabel() {
    final born = _birthdate;
    if (born == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[born.month - 1]} ${born.day}, ${born.year}';
  }

  Future<void> _decide({required bool approve}) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (reason == null) return;
    }
    setState(() => _busy = true);
    try {
      await widget.verification.setUserVerification(
        userId: _a['uid'] as String,
        status: approve
            ? VerificationStatus.verified
            : VerificationStatus.rejected,
        reviewerId: staff.uid,
        reviewerName: staff.displayName ?? 'Barangay staff',
        reason: reason,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final name = _a['name'] ?? 'Resident';
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '$name approved. They can now sign in.'
                : '$name rejected.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save the decision: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Deletes the account. Only for a resident who no longer belongs to the
  /// barangay (moved out, or signed up with an address outside Batasan Hills).
  Future<void> _remove() async {
    final uid = _a['uid'] as String;
    final name = (_a['name'] as String?)?.trim() ?? 'this resident';
    if (!await confirmRemoveResident(context, name)) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      await deleteResidentAccount(uid);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(content: Text('$name removed.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not remove the account: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// The reason shown to the resident at login, or null when cancelled.
  Future<String?> _askReason() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this registration?'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason (shown to the resident)',
            hintText: 'e.g. The ID is unreadable / not a Batasan Hills address',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (ok != true) return null;
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Give the resident a reason.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return null;
    }
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final emailConfirmed = _a['emailVerified'] == true;
    final status = _status();
    final address = [
      _a['houseStreet'],
      _a['subdivision'],
      _a['barangay'],
      _a['city'],
      _a['province'],
    ].whereType<String>().where((p) => p.trim().isNotEmpty).join(', ');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: EdgeInsets.zero,
              children: [
                _header(status, emailConfirmed),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('RESIDENT DETAILS'),
                      const SizedBox(height: 8),
                      _detailsCard(address),
                      const SizedBox(height: 18),
                      const SectionLabel('VALID ID'),
                      const SizedBox(height: 8),
                      _idCard(),
                      const SizedBox(height: 7),
                      const Text(
                        'Pinch to zoom. Check the name and that the address is '
                        'in Batasan Hills.',
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1.45,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _DecisionBar(
            busy: _busy,
            // An approved resident has nothing left to approve; Reject stays
            // so the desk can still revoke the verification.
            showApprove: status != VerificationStatus.verified,
            onReject: () => _decide(approve: false),
            onApprove: () => _decide(approve: true),
            onRemove: _remove,
          ),
        ],
      ),
    );
  }

  VerificationStatus _status() {
    final verification = VerificationStatusX.fromName(
      _a['verificationStatus'] as String?,
    );
    if (verification != VerificationStatus.unverified) return verification;
    // Older records carry only the account status.
    if (_a['accountStatus'] == 'pending') return VerificationStatus.pending;
    return verification;
  }

  /// The forest band that names the person and their standing before any
  /// detail is read.
  Widget _header(VerificationStatus status, bool emailConfirmed) {
    final name = (_a['name'] as String?)?.trim();
    final display = (name == null || name.isEmpty)
        ? 'Unnamed resident'
        : name;
    final initial = display.substring(0, 1).toUpperCase();
    final barangay = (_a['barangay'] as String?)?.trim();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.forestGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            right: -40,
            top: -54,
            child: RoleHeroRing(size: 140, opacity: 0.09),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      height: 54,
                      width: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            display,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            barangay == null || barangay.isEmpty
                                ? 'Resident'
                                : 'Resident · $barangay',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _HeaderChip(
                      label: status.label,
                      color: status.color,
                      icon: status.icon,
                    ),
                    const SizedBox(width: 7),
                    _HeaderChip(
                      label: emailConfirmed ? 'Email confirmed' : 'Email pending',
                      color: emailConfirmed
                          ? AppColors.primary
                          : AppColors.warning,
                      icon: emailConfirmed
                          ? Icons.mark_email_read_outlined
                          : Icons.mail_outline_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(String address) {
    return EcoCard(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.alternate_email_rounded,
            label: 'Email',
            value: _a['email'],
          ),
          _InfoRow(
            icon: Icons.call_outlined,
            label: 'Phone',
            value: _a['phone'],
          ),
          _InfoRow(
            icon: Icons.cake_outlined,
            label: 'Birthdate',
            value: _birthdateLabel(),
          ),
          _InfoRow(
            icon: Icons.perm_identity_rounded,
            label: 'Age',
            value: _ageFromBirthdate()?.toString(),
          ),
          _InfoRow(
            icon: Icons.holiday_village_outlined,
            label: 'Area',
            value: (_a['subdivision'] as String?)?.trim(),
          ),
          _InfoRow(
            icon: Icons.place_outlined,
            label: 'Address',
            value: address.isEmpty ? null : address,
          ),
          _InfoRow(
            icon: Icons.event_available_outlined,
            label: 'Signed up',
            value: _formatDate(_a['createdAt']),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _idCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            color: AppColors.mintSoft,
            child: Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'Uploaded document',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                ),
                Icon(
                  Icons.zoom_in_rounded,
                  size: 13,
                  color: AppColors.inkMuted.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Zoom',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<String?>(
            future: _idDataUrl,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 170,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _IdMessage('Could not load the ID: ${snapshot.error}');
              }
              final dataUrl = snapshot.data;
              if (dataUrl == null) {
                return const _IdMessage('This resident did not upload an ID.');
              }
              return Container(
                color: Colors.black,
                constraints: const BoxConstraints(maxHeight: 360),
                width: double.infinity,
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.memory(
                    _bytes(dataUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const _IdMessage('The ID file could not be shown.'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A translucent pill on the review header. The dot carries the colour so the
/// label stays readable on the gradient.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(EcoRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reject / Approve, pinned under the scroll so the decision never needs a
/// scroll to the bottom of a long record.
class _DecisionBar extends StatelessWidget {
  const _DecisionBar({
    required this.busy,
    required this.showApprove,
    required this.onReject,
    required this.onApprove,
    required this.onRemove,
  });

  final bool busy;
  final bool showApprove;
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.sage.withValues(alpha: 0.6)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestDeep.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size.fromHeight(46),
                    side: BorderSide(
                      color: AppColors.danger.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject'),
                ),
              ),
              if (showApprove) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onApprove,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: busy
                        ? const SizedBox(
                            height: 15,
                            width: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 17),
                    label: Text(busy ? 'Saving' : 'Approve'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: busy ? null : onRemove,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkMuted,
              minimumSize: const Size.fromHeight(34),
            ),
            icon: const Icon(Icons.person_remove_outlined, size: 15),
            label: const Text(
              'Remove resident',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final Object? value;

  /// The final row drops its divider so the card closes cleanly.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = value?.toString().trim();
    final empty = text == null || text.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.sage.withValues(alpha: 0.35),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.inkMuted),
          const SizedBox(width: 9),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              empty ? '—' : text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: empty ? AppColors.inkMuted : AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdMessage extends StatelessWidget {
  const _IdMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
      ),
    );
  }
}

String? _formatDate(Object? raw) {
  if (raw is! Timestamp) return null;
  final d = raw.toDate().toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '${months[d.month - 1]} ${d.day}, ${d.year} · $hour:$minute '
      '${d.hour < 12 ? 'AM' : 'PM'}';
}

Uint8List _bytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (comma < 0) return Uint8List(0);
  return base64Decode(dataUrl.substring(comma + 1));
}
