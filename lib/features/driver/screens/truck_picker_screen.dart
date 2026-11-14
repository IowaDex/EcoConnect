import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../auth/providers/auth_provider.dart';
import '../../fleet/services/fleet_service.dart';
import '../../location/providers/location_provider.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../models/garbage_truck.dart';
import '../models/truck_crew_role.dart';
import '../providers/truck_provider.dart';

/// First screen after a driver or guide signs in.
///
/// The barangay assigns the truck, so the crew does not type anything: they
/// pick their plate from the fleet list and the dashboard opens for that
/// vehicle. Both crew roles see the same list — the guide is the alternative
/// for a driver without a phone.
class TruckPickerScreen extends StatefulWidget {
  const TruckPickerScreen({super.key});

  @override
  State<TruckPickerScreen> createState() => _TruckPickerScreenState();
}

class _TruckPickerScreenState extends State<TruckPickerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TruckProvider>().restore();
    });
  }

  Future<void> _open(GarbageTruck truck) async {
    await context.read<TruckProvider>().select(truck);
    if (!mounted) return;
    context.go('/driver');
  }

  Future<void> _logout() async {
    final confirmed = await confirmLogout(
      context,
      message: 'You can sign back in with the same account any time.',
    );
    if (!confirmed || !mounted) return;
    final trucks = context.read<TruckProvider>();
    final auth = context.read<AuthProvider>();
    final location = context.read<LocationProvider>();
    await trucks.clear();
    await location.endSession();
    await auth.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final trucks = context.watch<TruckProvider>();
    final user = auth.currentUser;
    final role = trucks.resolveRole(user?.crewRole ?? TruckCrewRole.driver);

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                children: [
                  const BrandWordmark(fontSize: 10.5),
                  const Spacer(),
                  const NotificationBell(
                    iconSize: 19,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 2),
                  InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.logout_rounded,
                          size: 18, color: AppColors.inkMuted),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
                children: [
                  _RoleBadge(role: role),
                  const SizedBox(height: 14),
                  const Text(
                    'Select your truck',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // The registry Iswim maintains, so a plate added this
                  // morning shows up here without a rebuild.
                  StreamBuilder<List<GarbageTruck>>(
                    stream: FleetService().watchTrucks(),
                    builder: (context, snapshot) {
                      final fleet = snapshot.data ?? const <GarbageTruck>[];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${fleet.length} trucks assigned by Barangay '
                            'Batasan Hills. Tap your plate to open the trip '
                            'dashboard.',
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 18),
                          for (final truck in fleet) ...[
                            _TruckCard(
                              truck: truck,
                              selected: trucks.selectedTruck?.id == truck.id,
                              onTap: () => _open(truck),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _RolePreviewSwitch(
                    role: role,
                    onChanged: (next) async {
                      final provider = context.read<TruckProvider>();
                      final accountRole = user?.crewRole ?? TruckCrewRole.driver;
                      await provider.setRoleOverride(
                        next == accountRole ? null : next,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Names who is holding the device. Both roles run the same dashboard.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final TruckCrewRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 14, color: AppColors.forest),
          const SizedBox(width: 7),
          Text(
            role.label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckCard extends StatelessWidget {
  const _TruckCard({
    required this.truck,
    required this.selected,
    required this.onTap,
  });

  final GarbageTruck truck;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.mint : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.sage,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  size: 20,
                  color: selected ? Colors.white : AppColors.forest,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          truck.plateNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: AppColors.forest,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            truck.wheelerLabel,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      truck.description,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      truck.areaLabel,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.moss,
                      ),
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
      ),
    );
  }
}

/// Lets one account preview both crew views until the barangay console issues
/// separate driver and guide logins.
class _RolePreviewSwitch extends StatelessWidget {
  const _RolePreviewSwitch({required this.role, required this.onChanged});

  final TruckCrewRole role;
  final ValueChanged<TruckCrewRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Signed in as',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final option in TruckCrewRole.values) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(option),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: option == role
                            ? AppColors.forest
                            : AppColors.cream,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: option == role
                              ? Colors.white
                              : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                if (option != TruckCrewRole.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            role.blurb,
            style: const TextStyle(
              fontSize: 9,
              height: 1.4,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
