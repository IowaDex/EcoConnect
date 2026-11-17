import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/role_hero.dart';
import '../../dashboard/widgets/role_top_bar.dart';
import '../../fleet/services/fleet_service.dart';
import '../../location/providers/location_provider.dart';
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
            RoleTopBar(onLogout: _logout),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: StreamBuilder<List<GarbageTruck>>(
                    stream: FleetService().watchTrucks(),
                    builder: (context, snapshot) {
                      final loading =
                          snapshot.connectionState == ConnectionState.waiting;
                      final fleet = snapshot.data ?? const <GarbageTruck>[];
                      final paired = fleet
                          .where(
                            (truck) => (truck.driverAccountId ?? '').isNotEmpty,
                          )
                          .length;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: [
                          FadeSlideIn(
                            index: 0,
                            child: RoleHero(
                              icon: Icons.local_shipping_rounded,
                              eyebrow: 'BATASAN HILLS · CREW',
                              greeting: greeting(),
                              title: 'Select your truck',
                              subtitle:
                                  'The barangay assigns the plate. Pick yours '
                                  'and the trip dashboard opens for that '
                                  'vehicle.',
                              chip: RoleChip(
                                label: role.label,
                                icon: role.icon,
                              ),
                              stats: loading
                                  ? const []
                                  : [
                                      RoleStat(
                                        icon: Icons.local_shipping_rounded,
                                        label: 'Trucks',
                                        value: fleet.length,
                                      ),
                                      RoleStat(
                                        icon: Icons.person_outline_rounded,
                                        label: 'Paired',
                                        value: paired,
                                      ),
                                    ],
                            ),
                          ),
                          const SizedBox(height: EcoSpace.lg),
                          const SectionLabel('ASSIGNED TRUCKS'),
                          const SizedBox(height: EcoSpace.xs),
                          Text(
                            '${fleet.length} trucks assigned by Barangay '
                            'Batasan Hills. Tap your plate to open the trip '
                            'dashboard.',
                            style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: EcoSpace.sm),
                          if (snapshot.hasError)
                            const EcoBanner(
                              message:
                                  'Could not load the fleet. Check your '
                                  'connection and reopen the app.',
                              icon: Icons.cloud_off_rounded,
                              color: AppColors.error,
                            )
                          else if (loading)
                            const _FleetSkeleton()
                          else if (fleet.isEmpty)
                            const EmptyState(
                              icon: Icons.local_shipping_outlined,
                              title: 'No truck assigned yet',
                              message:
                                  'The barangay has not registered a plate '
                                  'for this crew. Ask the fleet desk to add '
                                  'one, then reopen this screen.',
                              compact: true,
                            )
                          else
                            for (var i = 0; i < fleet.length; i++) ...[
                              FadeSlideIn(
                                index: i + 1,
                                child: _TruckCard(
                                  truck: fleet[i],
                                  selected:
                                      trucks.selectedTruck?.id == fleet[i].id,
                                  onTap: () => _open(fleet[i]),
                                ),
                              ),
                              if (i < fleet.length - 1)
                                const SizedBox(height: EcoSpace.sm),
                            ],
                          const SizedBox(height: EcoSpace.lg),
                          FadeSlideIn(
                            index: 2,
                            child: _RolePreviewSwitch(
                              role: role,
                              onChanged: (next) async {
                                final provider = context.read<TruckProvider>();
                                final accountRole =
                                    user?.crewRole ?? TruckCrewRole.driver;
                                await provider.setRoleOverride(
                                  next == accountRole ? null : next,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
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

class _FleetSkeleton extends StatelessWidget {
  const _FleetSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: 92,
            padding: const EdgeInsets.all(EcoSpace.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(EcoRadius.lg),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 42, height: 42, radius: 21),
                SizedBox(width: EcoSpace.sm + 3),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 96, height: 13),
                    SizedBox(height: 8),
                    SkeletonBox(width: 150, height: 10, radius: 5),
                    SizedBox(height: 6),
                    SkeletonBox(width: 110, height: 9, radius: 5),
                  ],
                ),
              ],
            ),
          ),
          if (i < 2) const SizedBox(height: EcoSpace.sm),
        ],
      ],
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
    return HoverLift(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EcoRadius.lg),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(
              EcoSpace.md,
              EcoSpace.md,
              EcoSpace.sm,
              EcoSpace.md,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.mint : Colors.white,
              borderRadius: BorderRadius.circular(EcoRadius.lg),
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
                const SizedBox(width: EcoSpace.sm + 3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              truck.plateNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                          const SizedBox(width: EcoSpace.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(
                                EcoRadius.pill,
                              ),
                            ),
                            child: Text(
                              truck.wheelerLabel,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: EcoSpace.xxs),
                      Text(
                        truck.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        truck.areaLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
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
      padding: const EdgeInsets.fromLTRB(
        EcoSpace.md,
        EcoSpace.sm + 1,
        EcoSpace.md,
        EcoSpace.sm + 1,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SIGNED IN AS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: EcoSpace.xs),
          Row(
            children: [
              for (final option in TruckCrewRole.values) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(option),
                    child: AnimatedContainer(
                      duration: EcoMotion.base,
                      curve: EcoMotion.enter,
                      padding: const EdgeInsets.symmetric(
                        vertical: EcoSpace.sm,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: option == role
                            ? AppColors.forest
                            : AppColors.cream,
                        borderRadius: BorderRadius.circular(EcoRadius.sm + 1),
                      ),
                      child: Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 11,
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
                  const SizedBox(width: EcoSpace.sm),
              ],
            ],
          ),
          const SizedBox(height: EcoSpace.xs),
          Text(
            role.blurb,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
