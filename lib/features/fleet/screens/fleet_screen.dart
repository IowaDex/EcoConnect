import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../driver/models/garbage_truck.dart';
import '../services/fleet_service.dart';

/// Iswim's fleet registry.
///
/// Every truck gets a plate, a wheel count and a named driver. A truck is never
/// left without one — the form refuses to save an empty driver — and City Hall
/// links the driver's login afterwards.
class FleetScreen extends StatelessWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBright,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text(
          'Truck',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        title: const Text(
          'Fleet registry',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: StreamBuilder<List<GarbageTruck>>(
        stream: FleetService().watchTrucks(),
        builder: (context, snapshot) {
          final trucks = snapshot.data ?? const <GarbageTruck>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
            children: [
              StreamBuilder<bool>(
                stream: FleetService().watchIsRegistered(),
                builder: (context, seeded) {
                  // Still the seeded list: offer to make it the real registry.
                  if (seeded.data != false) return const SizedBox.shrink();
                  return _SeedBanner(
                    count: trucks.length,
                    onSeed: () => _seed(context),
                  );
                },
              ),
              Text(
                '${trucks.length} trucks · bawat isa may permanenteng driver',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 10),
              for (final truck in trucks) ...[
                _TruckTile(
                  truck: truck,
                  onTap: () => _openForm(context, truck: truck),
                ),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _seed(BuildContext context) async {
    try {
      await FleetService().seedRoster();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Nailagay na sa registry ang 10 truck.'),
            backgroundColor: AppColors.forest,
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Hindi na-save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _openForm(BuildContext context, {GarbageTruck? truck}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TruckForm(truck: truck),
    );
  }
}

class _SeedBanner extends StatelessWidget {
  const _SeedBanner({required this.count, required this.onSeed});

  final int count;
  final VoidCallback onSeed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mock list pa lang ito',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'I-save ang $count seeded truck para maging totoong registry. '
            'Pag may naisave nang kahit isa, ito na ang tanging listahan — '
            'kaya simulan sa lahat.',
            style: const TextStyle(
              fontSize: 9,
              height: 1.45,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: FilledButton.icon(
              onPressed: onSeed,
              icon: const Icon(Icons.save_alt_rounded, size: 14),
              label: const Text(
                'I-save lahat sa registry',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckTile extends StatelessWidget {
  const _TruckTile({required this.truck, required this.onTap});

  final GarbageTruck truck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sage),
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    size: 17, color: AppColors.forest),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      truck.plateNumber,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
                    Text(
                      '${truck.wheelerLabel} · ${truck.bodyType} · '
                      '${truck.driverName}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (truck.driverAccountId == null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'walang login',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.moss),
            ],
          ),
        ),
      ),
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
  late final _zone = TextEditingController(text: widget.truck?.zone ?? 'Zone 1');

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
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Hindi na-save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.truck == null ? 'Bagong truck' : 'I-edit ang truck',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Plate number',
                  hintText: 'SK 4821',
                  isDense: true,
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Ilagay ang plate' : null,
              ),
              const SizedBox(height: 12),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _body,
                      decoration: const InputDecoration(
                        labelText: 'Body',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Compactor', child: Text('Compactor')),
                        DropdownMenuItem(
                            value: 'Mini compactor',
                            child: Text('Mini compactor')),
                        DropdownMenuItem(
                            value: 'Dump truck', child: Text('Dump truck')),
                      ],
                      onChanged: (value) => setState(() => _body = value ?? _body),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _zone,
                decoration: const InputDecoration(
                  labelText: 'Zone',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _driver,
                decoration: const InputDecoration(
                  labelText: 'Driver (pangalan)',
                  isDense: true,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Bawal ang bakanteng driver'
                    : null,
              ),
              const SizedBox(height: 6),
              const Text(
                'Si City Hall ang gagawa ng login account ng driver na ito.',
                style: TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
                      : const Text('I-save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
