import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/map_config.dart';
import '../../../core/widgets/primary_button.dart';
import '../../location/services/geocoding_service.dart';
import '../../tickets/models/trip_ticket.dart';

/// Picks the streets a manual covers by tapping the map.
///
/// Typing route names was the slow part of building a manual, so each tap
/// drops a numbered pin and the street under it is named automatically by the
/// OSM geocoder. A name can still be corrected by tapping its chip. The screen
/// returns the points in the order they were tapped, so the driver's map can
/// draw the same streets later.
class ManualRoutePickerScreen extends StatefulWidget {
  const ManualRoutePickerScreen({super.key, required this.maxRoutes});

  /// Two for a four-wheeler, three for a six-wheeler.
  final int maxRoutes;

  @override
  State<ManualRoutePickerScreen> createState() =>
      _ManualRoutePickerScreenState();
}

class _RoutePin {
  _RoutePin({required this.id, required this.point, required this.name});

  final int id;
  final LatLng point;
  String name;
}

class _ManualRoutePickerScreenState extends State<ManualRoutePickerScreen> {
  final _mapController = MapController();
  final _geocoder = GeocodingService();
  final List<_RoutePin> _pins = [];
  int _nextId = 1;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addPin(LatLng point) {
    if (_pins.length >= widget.maxRoutes) {
      _toast(
        'This truck takes ${widget.maxRoutes} routes. Remove one to add '
        'another.',
      );
      return;
    }
    final pin = _RoutePin(
      id: _nextId++,
      point: point,
      name: 'Route ${_pins.length + 1}',
    );
    setState(() => _pins.add(pin));
    _namePin(pin);
  }

  /// Asks the geocoder for the street under the pin. A slow or failed lookup
  /// leaves the numbered label in place, so picking never waits on the network.
  Future<void> _namePin(_RoutePin pin) async {
    try {
      final name = await _geocoder.reverse(pin.point);
      if (!mounted || name == null || name.isEmpty) return;
      final index = _pins.indexWhere((item) => item.id == pin.id);
      if (index < 0) return;
      // A name the officer typed wins over the lookup.
      if (_pins[index].name != 'Route ${index + 1}') return;
      setState(() => _pins[index].name = name);
    } catch (_) {
      // Keep the fallback label.
    }
  }

  void _remove(int index) {
    setState(() => _pins.removeAt(index));
    // Keep the numbered fallback labels in step with the new order.
    for (var i = 0; i < _pins.length; i++) {
      if (_pins[i].name.startsWith('Route ')) {
        _pins[i].name = 'Route ${i + 1}';
      }
    }
  }

  Future<void> _rename(int index) async {
    final controller = TextEditingController(text: _pins[index].name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this route'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Street, purok or landmark',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => _pins[index].name = name);
  }

  @override
  Widget build(BuildContext context) {
    final points = [for (final pin in _pins) pin.point];

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pick the routes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        Text(
                          'Tap the map once per route · '
                          '${_pins.length}/${widget.maxRoutes}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_pins.isNotEmpty)
                    TextButton(
                      onPressed: () => _remove(_pins.length - 1),
                      child: const Text('Undo', style: TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FlutterMap(
                      mapController: _mapController,
                      options: BatasanHills.options(
                        center: points.isEmpty ? null : points.last,
                        onTap: (_, point) => _addPin(point),
                      ),
                      children: [
                        BatasanHills.tiles(),
                        BatasanHills.boundaryLayer(),
                        if (points.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: points,
                                strokeWidth: 4,
                                color: AppColors.forest.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            for (var i = 0; i < _pins.length; i++)
                              Marker(
                                point: _pins[i].point,
                                width: 30,
                                height: 30,
                                child: _RoutePinBadge(index: i + 1),
                              ),
                          ],
                        ),
                        const OsmAttribution(alignment: Alignment.centerRight),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: BoxDecoration(
                        color: AppColors.creamBright,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.forest.withValues(alpha: 0.16),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_pins.length}'
                                '${_pins.length == 1 ? ' route' : ' routes'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forest,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Tap a name to rename',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                          if (_pins.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'No routes yet — tap the street the truck '
                                'should cover. The name is filled in for you.',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  height: 1.4,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 34,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(top: 8),
                                itemCount: _pins.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 6),
                                itemBuilder: (context, index) => _RouteChip(
                                  index: index + 1,
                                  name: _pins[index].name,
                                  onRename: () => _rename(index),
                                  onRemove: () => _remove(index),
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          PrimaryButton(
                            label: 'Use these routes',
                            onPressed: _pins.isEmpty
                                ? null
                                : () => Navigator.of(context).pop([
                                    for (final pin in _pins)
                                      ManualRoutePoint(
                                        name: pin.name,
                                        latitude: pin.point.latitude,
                                        longitude: pin.point.longitude,
                                      ),
                                  ]),
                            height: 44,
                          ),
                        ],
                      ),
                    ),
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

class _RoutePinBadge extends StatelessWidget {
  const _RoutePinBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.forest,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        index.toString(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({
    required this.index,
    required this.name,
    required this.onRename,
    required this.onRemove,
  });

  final int index;
  final String name;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 2),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onRename,
            child: Text(
              '$index. $name',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.forest,
              ),
            ),
          ),
          InkWell(
            onTap: onRemove,
            customBorder: const CircleBorder(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
