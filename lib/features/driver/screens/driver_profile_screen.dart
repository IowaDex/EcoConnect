import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/confirm_logout.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../location/providers/location_provider.dart';
import '../../route/models/route_plan.dart';
import '../../route/services/route_service.dart';
import '../widgets/driver_nav_bar.dart';

/// Driver profile: identity, account state, shortcuts and sign-out.
class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    if (!await confirmLogout(context) || !context.mounted) return;
    final auth = context.read<AuthProvider>();
    final location = context.read<LocationProvider>();
    await location.endSession();
    await auth.logout();
    if (context.mounted) context.go('/login');
  }

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
                            fontSize: 10,
                            color: AppColors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const StatusBadge(
                              label: 'Driver',
                              color: AppColors.primary,
                              icon: Icons.local_shipping_outlined,
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
                          value: user.phone ?? 'Not set',
                        ),
                        _InfoRow(
                          icon: Icons.location_city_outlined,
                          label: 'Barangay',
                          value: user.barangay ?? 'Not set',
                        ),
                        _InfoRow(
                          icon: Icons.home_outlined,
                          label: 'Address',
                          value: user.fullAddress,
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
        final stops = (snapshot.data ?? const <RoutePlan>[])
            .fold<int>(0, (sum, plan) => sum + plan.stops.length);
        return EcoCard(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: _Stat(value: '$runs', label: 'Runs completed')),
              Container(height: 34, width: 1, color: AppColors.sage),
              Expanded(child: _Stat(value: '$stops', label: 'Stops served')),
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
          style: const TextStyle(fontSize: 9, color: AppColors.inkMuted),
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
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
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
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
