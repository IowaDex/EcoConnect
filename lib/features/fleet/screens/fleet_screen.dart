import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../driver/models/garbage_truck.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../services/fleet_service.dart';
import '../widgets/fleet_truck_tile.dart';

/// Iswim's fleet registry.
///
/// Every truck gets a plate, a wheel count and a named driver. A truck is never
/// left without one — the form refuses to save an empty driver — and Iswim
/// pairs the driver's login from the accounts desk afterwards.
class FleetScreen extends StatefulWidget {
  const FleetScreen({super.key});

  @override
  State<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends State<FleetScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Keeps the trucks the desk can find by plate, body, driver or zone.
  List<GarbageTruck> _filter(List<GarbageTruck> trucks) {
    if (_query.trim().isEmpty) return trucks;
    return trucks.where((truck) => truckMatchesQuery(truck, _query)).toList();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EcoRadius.lg),
        ),
        icon: const Icon(Icons.add_rounded, size: 19),
        label: const Text(
          'Truck',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: StreamBuilder<List<GarbageTruck>>(
              stream: FleetService().watchTrucks(),
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState == ConnectionState.waiting;
                final trucks = snapshot.data ?? const <GarbageTruck>[];
                final paired = trucks
                    .where((truck) => (truck.driverAccountId ?? '').isNotEmpty)
                    .length;
                final searching = _query.trim().isNotEmpty;
                final visible = _filter(trucks);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
                  children: [
                    AppPageHeader(
                      title: 'Fleet registry',
                      subtitle:
                          'Every plate, its body and the driver who runs it.',
                      onBack: () => context.canPop()
                          ? context.pop()
                          : context.go('/iswim'),
                      actions: const [NotificationBell()],
                    ),
                    const SizedBox(height: EcoSpace.xs),
                    FadeSlideIn(
                      index: 0,
                      child: _SeedPrompt(
                        count: trucks.length,
                        onSeed: () => _seed(context),
                      ),
                    ),
                    FadeSlideIn(
                      index: 1,
                      child: DeskMetricRow(
                        metrics: [
                          DeskMetric(
                            icon: Icons.local_shipping_rounded,
                            label: 'Trucks',
                            value: loading ? '—' : '${trucks.length}',
                          ),
                          DeskMetric(
                            icon: Icons.person_outline_rounded,
                            label: 'Paired',
                            value: loading ? '—' : '$paired',
                          ),
                          DeskMetric(
                            icon: Icons.key_off_outlined,
                            label: 'No login',
                            value: loading ? '—' : '${trucks.length - paired}',
                            accent: AppColors.warning,
                            highlight: !loading && trucks.length > paired,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: EcoSpace.md),
                    if (!loading && trucks.length > paired)
                      Padding(
                        padding: const EdgeInsets.only(bottom: EcoSpace.sm),
                        child: EcoBanner(
                          message:
                              '${trucks.length - paired} '
                              '${trucks.length - paired == 1 ? 'truck has' : 'trucks have'} '
                              'no driver login yet. Pair the account from the '
                              'accounts desk so the crew can start a trip.',
                          icon: Icons.key_off_outlined,
                        ),
                      ),
                    EcoSearchField(
                      controller: _search,
                      hint: 'Search plate, driver or zone',
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    AnimatedSize(
                      duration: EcoMotion.fast,
                      curve: EcoMotion.enter,
                      alignment: Alignment.topCenter,
                      child: searching
                          ? Padding(
                              padding: const EdgeInsets.only(
                                top: EcoSpace.xs + 2,
                              ),
                              child: EcoResultCount(
                                shown: visible.length,
                                total: trucks.length,
                                singular: 'truck',
                                plural: 'trucks',
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: EcoSpace.lg),
                    // The add action lives in the FAB only — a second "Add
                    // truck" link beside the list heading duplicated it.
                    SectionLabel(
                      searching
                          ? 'TRUCKS · ${visible.length} OF ${trucks.length}'
                          : 'TRUCKS · ${trucks.length}',
                    ),
                    const SizedBox(height: EcoSpace.sm),
                    if (snapshot.hasError)
                      EcoBanner(
                        message: AppFeedback.describe(snapshot.error!),
                        icon: Icons.cloud_off_rounded,
                        color: AppColors.error,
                      )
                    else if (loading)
                      const _FleetSkeleton()
                    else if (trucks.isEmpty)
                      EmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: 'No trucks registered',
                        message:
                            'Add the first plate so a crew can be paired with '
                            'it before a trip ticket is issued.',
                        actionLabel: 'Add a truck',
                        onAction: () => _openForm(context),
                        compact: true,
                      )
                    else if (visible.isEmpty)
                      EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No truck matches',
                        message:
                            'No plate, driver or zone matches '
                            '"${_query.trim()}".',
                        actionLabel: 'Clear search',
                        onAction: _clearSearch,
                        compact: true,
                      )
                    else
                      for (var i = 0; i < visible.length; i++) ...[
                        FadeSlideIn(
                          index: i + 2,
                          child: FleetTruckTile(
                            truck: visible[i],
                            onTap: () => _openForm(context, truck: visible[i]),
                          ),
                        ),
                        if (i < visible.length - 1)
                          const SizedBox(height: EcoSpace.sm),
                      ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _seed(BuildContext context) async {
    try {
      await FleetService().seedRoster();
      if (!context.mounted) return;
      AppFeedback.success(context, '10 trucks added to the registry.');
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.error(context, 'Could not save: ${AppFeedback.describe(e)}');
    }
  }

  Future<void> _openForm(BuildContext context, {GarbageTruck? truck}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TruckForm(truck: truck),
    );
    if (saved != true || !context.mounted) return;
    AppFeedback.success(context, 'Truck saved to the registry.');
  }
}

/// Offers to copy the seeded roster the first time the registry is opened.
class _SeedPrompt extends StatelessWidget {
  const _SeedPrompt({required this.count, required this.onSeed});

  final int count;
  final VoidCallback onSeed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FleetService().watchIsRegistered(),
      builder: (context, seeded) {
        // Still the seeded list: offer to make it the real registry.
        if (seeded.data != false) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: EcoSpace.md),
          padding: const EdgeInsets.all(EcoSpace.md),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(EcoRadius.md),
            border: Border.all(color: AppColors.sage),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is still a mock list',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: EcoSpace.xxs),
              Text(
                'Save the $count seeded trucks to make this the real registry. '
                'Once even one is saved, this becomes the only list — so start '
                'with all of them.',
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.45,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: EcoSpace.sm),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: onSeed,
                  icon: const Icon(Icons.save_alt_rounded, size: 15),
                  label: const Text(
                    'Save all to registry',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(
                      horizontal: EcoSpace.md,
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
      },
    );
  }
}

class _FleetSkeleton extends StatelessWidget {
  const _FleetSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: 66,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(EcoRadius.md),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
            ),
            child: const Row(
              children: [
                SkeletonBox(width: 38, height: 38, radius: 19),
                SizedBox(width: EcoSpace.sm + 1),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 92, height: 12),
                    SizedBox(height: 7),
                    SkeletonBox(width: 158, height: 10, radius: 5),
                  ],
                ),
              ],
            ),
          ),
          if (i < 3) const SizedBox(height: EcoSpace.sm),
        ],
      ],
    );
  }
}

class _TruckForm extends StatefulWidget {
  const _TruckForm({this.truck});

  final GarbageTruck? truck;

  @override
  State<_TruckForm> createState() => _TruckFormState();
}

class _TruckFormState extends State<_TruckForm> {
  final _formKey = GlobalKey<FormState>();
  late final _plate = TextEditingController(text: widget.truck?.plateNumber);
  late final _driver = TextEditingController(text: widget.truck?.driverName);
  late final _zone = TextEditingController(
    text: widget.truck?.zone ?? 'Zone 1',
  );

  late int _wheelers = widget.truck?.wheelers ?? 4;
  late String _body = widget.truck?.bodyType ?? 'Compactor';
  bool _busy = false;

  @override
  void dispose() {
    _plate.dispose();
    _driver.dispose();
    _zone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.truck;
    final truck = GarbageTruck(
      id: existing?.id ?? '',
      plateNumber: _plate.text.trim().toUpperCase(),
      wheelers: _wheelers,
      bodyType: _body,
      barangay: existing?.barangay ?? 'Batasan Hills',
      zone: _zone.text.trim(),
      centerLatitude: existing?.centerLatitude ?? 14.6792,
      centerLongitude: existing?.centerLongitude ?? 121.0961,
      driverName: _driver.text.trim(),
      driverAccountId: existing?.driverAccountId,
    );

    setState(() => _busy = true);
    try {
      await FleetService().saveTruck(truck);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Could not save: ${AppFeedback.describe(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(EcoRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: EcoSpace.md),
              Text(
                widget.truck == null ? 'New truck' : 'Edit truck',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'The plate is the registry key — saving it twice updates the '
                'same truck.',
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.45,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: EcoSpace.md),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Plate number',
                  hintText: 'SK 4821',
                  isDense: true,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter a plate number'
                    : null,
              ),
              const SizedBox(height: EcoSpace.sm + 2),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _wheelers,
                      decoration: const InputDecoration(
                        labelText: 'Wheeler',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 4, child: Text('4-wheeler')),
                        DropdownMenuItem(value: 6, child: Text('6-wheeler')),
                        DropdownMenuItem(value: 8, child: Text('8-wheeler')),
                      ],
                      onChanged: (value) =>
                          setState(() => _wheelers = value ?? _wheelers),
                    ),
                  ),
                  const SizedBox(width: EcoSpace.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _body,
                      decoration: const InputDecoration(
                        labelText: 'Body',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Compactor',
                          child: Text('Compactor'),
                        ),
                        DropdownMenuItem(
                          value: 'Mini compactor',
                          child: Text('Mini compactor'),
                        ),
                        DropdownMenuItem(
                          value: 'Dump truck',
                          child: Text('Dump truck'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _body = value ?? _body),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EcoSpace.sm + 2),
              TextFormField(
                controller: _zone,
                decoration: const InputDecoration(
                  labelText: 'Zone',
                  isDense: true,
                ),
              ),
              const SizedBox(height: EcoSpace.sm + 2),
              TextFormField(
                controller: _driver,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Driver (name)',
                  isDense: true,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Driver cannot be empty'
                    : null,
              ),
              const SizedBox(height: EcoSpace.xs),
              const Text(
                'Iswim creates the driver login from the accounts desk.',
                style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
              ),
              const SizedBox(height: EcoSpace.lg),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(EcoRadius.md),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save truck'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
