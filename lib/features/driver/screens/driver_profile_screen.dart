import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/service_area.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/session_actions.dart';
import '../../auth/utils/phone.dart';
import '../../route/models/route_plan.dart';
import '../../route/services/route_service.dart';
import '../models/truck_crew_role.dart';
import '../widgets/driver_nav_bar.dart';

/// Driver profile: identity, account state, shortcuts and sign-out.
class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  Future<void> _logout(BuildContext context) => confirmAndLogout(context);

  /// Phone and address belong to the crew member, so he maintains them here.
  /// The barangay is not editable: the app serves one barangay only.
  void _edit(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _EditCrewProfileSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      return const Scaffold(body: LoadingView(label: 'Loading your profile'));
    }

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 14, 22, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: BrandWordmark(fontSize: 10.5),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                children: [
                  Center(
                    child: Column(
                      children: [
                        _Avatar(
                          photoUrl: user.photoUrl,
                          initial: user.firstName.isEmpty
                              ? 'D'
                              : user.firstName[0].toUpperCase(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.displayName ?? 'Collector',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.email ?? 'No email on file',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            StatusBadge(
                              label: user.crewRole.label,
                              color: AppColors.primary,
                              icon: user.crewRole.icon,
                              compact: true,
                            ),
                            const SizedBox(width: 6),
                            StatusBadge(
                              label: user.accountStatus == 'active'
                                  ? 'Approved'
                                  : 'Pending approval',
                              color: user.accountStatus == 'active'
                                  ? AppColors.primary
                                  : AppColors.warning,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StatsCard(driverId: user.uid),
                  const SizedBox(height: 14),
                  EcoCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: user.phone == null || user.phone!.isEmpty
                              ? 'Tap to add your number'
                              : user.phone!,
                          onTap: () => _edit(context),
                        ),
                        const _InfoRow(
                          icon: Icons.location_city_outlined,
                          label: 'Barangay',
                          // One barangay only: the value is fixed, never typed.
                          value: ServiceArea.barangay,
                          locked: true,
                        ),
                        _InfoRow(
                          icon: Icons.home_outlined,
                          label: 'Address',
                          value: user.houseStreet == null ||
                                  user.houseStreet!.trim().isEmpty
                              ? 'Tap to add your address'
                              : user.houseStreet!,
                          onTap: () => _edit(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  EcoCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _LinkRow(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notifications',
                          onTap: () => context.push('/notifications'),
                        ),
                        _LinkRow(
                          icon: Icons.event_outlined,
                          label: 'Community events',
                          onTap: () => context.push('/events'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  EcoCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _LinkRow(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      color: AppColors.error,
                      onTap: () => _logout(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DriverNavBar(currentIndex: 3),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.initial});

  final String? photoUrl;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(photoUrl);
    return Container(
      height: 84,
      width: 84,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.mint,
        shape: BoxShape.circle,
      ),
      child: bytes == null
          ? Text(
              initial,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            )
          : Image.memory(bytes, fit: BoxFit.cover),
    );
  }

  static Uint8List? _decode(String? dataUrl) {
    if (dataUrl == null) return null;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.driverId});

  final String driverId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RoutePlan>>(
      stream: RouteService().watchCompletedPlans(driverId),
      builder: (context, snapshot) {
        final runs = snapshot.data?.length ?? 0;
        final stops = (snapshot.data ?? const <RoutePlan>[]).fold<int>(
          0,
          (sum, plan) => sum + plan.stops.length,
        );
        return EcoCard(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: _Stat(value: '$runs', label: 'Runs completed'),
              ),
              Container(height: 34, width: 1, color: AppColors.sage),
              Expanded(
                child: _Stat(value: '$stops', label: 'Stops served'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Opens the editor for this field. Null leaves the row read-only.
  final VoidCallback? onTap;

  /// A fixed value (the barangay): shown with a lock instead of an edit hint.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: onTap == null && !locked
                    ? AppColors.textDark
                    : (locked ? AppColors.textDark : AppColors.forest),
              ),
            ),
          ),
          if (locked)
            const Icon(
              Icons.lock_outline_rounded,
              size: 13,
              color: AppColors.inkMuted,
            )
          else if (onTap != null)
            const Icon(
              Icons.edit_outlined,
              size: 13,
              color: AppColors.moss,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Edits the crew member's own contact details. The barangay is shown but not
/// editable, so a profile can never point outside Batasan Hills.
class _EditCrewProfileSheet extends StatefulWidget {
  const _EditCrewProfileSheet();

  @override
  State<_EditCrewProfileSheet> createState() => _EditCrewProfileSheetState();
}

class _EditCrewProfileSheetState extends State<_EditCrewProfileSheet> {
  late final TextEditingController _phone;
  late final TextEditingController _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _phone = TextEditingController(text: Phone.localDigits(user?.phone));
    _address = TextEditingController(text: user?.houseStreet ?? '');
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final digits = _phone.text.trim();
    if (digits.isNotEmpty) {
      final error = Phone.validate(digits);
      if (error != null) {
        _toast(error);
        return;
      }
    }

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile(
      phone: digits.isEmpty ? '' : Phone.toE164(digits),
      houseStreet: _address.text.trim(),
      barangay: ServiceArea.barangay,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      _toast(auth.error ?? 'Could not save your changes');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'My details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Barangay staff use these details to reach you about a run.',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            _SheetField(
              label: 'Mobile number',
              hint: '09XX XXX XXXX',
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
            ),
            const SizedBox(height: 12),
            _SheetField(
              label: 'Address',
              hint: 'House number and street',
              controller: _address,
              maxLines: 2,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.creamBright,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.location_city_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Barangay',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  Text(
                    ServiceArea.barangay,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  SizedBox(width: 5),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 13,
                    color: AppColors.inkMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.creamBright,
                        ),
                      )
                    : const Text(
                        'Save changes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.forest,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.inkMuted,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textDark,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
