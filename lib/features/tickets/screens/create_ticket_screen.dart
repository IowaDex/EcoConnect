import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../driver/models/garbage_truck.dart';
import '../../fleet/services/fleet_service.dart';
import '../services/ticket_service.dart';

/// A driver account as Iswim sees it when issuing a ticket.
class FleetDriver {
  const FleetDriver({
    required this.uid,
    required this.name,
    this.truckId,
  });

  final String uid;
  final String name;
  final String? truckId;
}

/// Iswim issues the ticket: pick the truck, the driver comes with it.
class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _route = TextEditingController();
  final _notes = TextEditingController();
  final _windowStart = TextEditingController(text: '06:00');
  final _windowEnd = TextEditingController(text: '10:00');

  GarbageTruck? _truck;
  int _wave = 1;
  bool _busy = false;
  List<FleetDriver> _drivers = const [];
  List<GarbageTruck> _trucks = const [];
  StreamSubscription<List<GarbageTruck>>? _fleetSub;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    // The fleet registry is the source of truth: a truck Iswim added this
    // morning is issuable this afternoon without a rebuild.
    _fleetSub = FleetService().watchTrucks().listen((trucks) {
      if (!mounted) return;
      setState(() {
        _trucks = trucks;
        // The selected truck may have been re-plated or removed.
        final current = _truck;
        if (current != null) {
          _truck = trucks.cast<GarbageTruck?>().firstWhere(
                (t) => t?.id == current.id,
                orElse: () => null,
              );
        }
      });
    });
  }

  @override
  void dispose() {
    _fleetSub?.cancel();
    _route.dispose();
    _notes.dispose();
    _windowStart.dispose();
    _windowEnd.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .limit(100)
          .get();
      if (!mounted) return;
      setState(() {
        _drivers = snap.docs.map((doc) {
          final data = doc.data();
          return FleetDriver(
            uid: doc.id,
            name: (data['name'] as String?)?.trim().isNotEmpty == true
                ? data['name'] as String
                : (data['email'] as String? ?? 'Driver'),
            truckId: data['assignedTruckId'] as String?,
          );
        }).toList(growable: false);
      });
    } catch (_) {
      // Without the directory Iswim can still issue against the roster name;
      // the driver simply will not get the in-app notification.
    }
  }

  FleetDriver? get _driverForTruck {
    final truck = _truck;
    if (truck == null) return null;
    for (final driver in _drivers) {
      if (driver.truckId == truck.id) return driver;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final truck = _truck;
    final user = context.read<AuthProvider>().currentUser;
    if (truck == null || user == null) return;

    final driver = _driverForTruck;
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    setState(() => _busy = true);
    try {
      final ticket = await TicketService().create(
        truckId: truck.id,
        plateNumber: truck.plateNumber,
        wheelers: truck.wheelers,
        driverId: driver?.uid ?? truck.driverAccountId ?? '',
        driverName: driver?.name ?? truck.driverName,
        route: _route.text.trim(),
        zone: truck.zone,
        date: date,
        windowStart: _windowStart.text.trim(),
        windowEnd: _windowEnd.text.trim(),
        notes: _notes.text.trim(),
        wave: _wave,
        createdBy: user.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${ticket.code} sent to ${ticket.driverName}'),
            backgroundColor: AppColors.forest,
          ),
        );
      context.go('/tickets/${ticket.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Could not issue the ticket: $e'),
            backgroundColor: AppColors.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final truck = _truck;
    final driver = _driverForTruck;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.canPop() ? context.pop() : context.go('/iswim'),
        ),
        title: const Text(
          'New trip ticket',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          children: [
            const Text(
              'Truck and driver',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<GarbageTruck>(
              initialValue: _truck,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Truck (plate · wheeler)',
                isDense: true,
              ),
              items: [
                for (final item in _trucks)
                  DropdownMenuItem(
                    value: item,
                    child: Text(
                      '${item.plateNumber} · ${item.wheelerLabel} · '
                      '${item.driverName}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _truck = value),
              validator: (value) => value == null ? 'Select a truck' : null,
            ),
            if (truck != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sage),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_circle_rounded,
                        size: 15, color: AppColors.forest),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        driver == null
                            ? '${truck.driverName} · no login account yet'
                            : '${driver.name} · linked account',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _route,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Route / streets',
                hintText: 'Hal. Sampaguita St, Mabini St, Rosal St',
                isDense: true,
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter the route' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _windowStart,
                    decoration: const InputDecoration(
                      labelText: 'Simula',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _windowEnd,
                    decoration: const InputDecoration(
                      labelText: 'End',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Wave',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final wave in const [1, 2])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Wave $wave'),
                      selected: _wave == wave,
                      onSelected: (_) => setState(() => _wave = wave),
                    ),
                  ),
                const Spacer(),
                if (_wave == 2)
                  const Flexible(
                    child: Text(
                      'Allowed even while Wave 1 is ongoing',
                      style: TextStyle(fontSize: 8.5, color: AppColors.moss),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
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
                    : const Text('Send to driver'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The driver is notified automatically. They cannot '
              'start the trip until they accept it. City Hall receives '
              'a copy immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
