import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/models/route_plan.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';

/// Lets staff lay out the collection route by tapping the map. Each tap adds
/// an ordered stop that both the driver and the residents will see.
class StopPickerScreen extends StatefulWidget {
  const StopPickerScreen({
    super.key,
    required this.initialStops,
    this.zone,
  });

  final List<RouteStop> initialStops;
  final String? zone;

  @override
  State<StopPickerScreen> createState() => _StopPickerScreenState();
}

class _StopPickerScreenState extends State<StopPickerScreen> {
  static const _fallback = LatLng(14.5995, 120.9842);

  final _mapController = MapController();
  late List<RouteStop> _stops;

  @override
  void initState() {
    super.initState();
    _stops = List<RouteStop>.from(widget.initialStops);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = context.read<LocationProvider>();
      if (!location.hasLocation) location.getCurrentLocation();
      final first = _stops.where((stop) => stop.hasCoordinates).firstOrNull;
      if (first != null) {
        _mapController.move(
          LatLng(first.latitude!, first.longitude!),
          15,
        );
      } else if (location.hasLocation) {
        _mapController.move(
          LatLng(location.latitude!, location.longitude!),
          15,
        );
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _addStop(LatLng point) {
    setState(() {
      _stops = [
        ..._stops,
        RouteStop(
          name: 'Stop ${_stops.length + 1}',
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      ];
    });
  }

  void _removeAt(int index) {
    setState(() => _stops = [..._stops]..removeAt(index));
  }

  Future<void> _rename(int index) async {
    final controller = TextEditingController(text: _stops[index].name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this stop'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Purok, street or landmark',
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() {
      _stops = [..._stops];
      _stops[index] = _stops[index].renamed(name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapped = <LatLng>[
      for (final stop in _stops)
        if (stop.hasCoordinates)
          LatLng(stop.latitude!, stop.longitude!),
    ];

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
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: AppColors.inkMuted),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Route stops',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                        Text(
                          widget.zone == null || widget.zone!.isEmpty
                              ? 'Tap the map to add a stop'
                              : 'Tap the map to add a stop in ${widget.zone!}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_stops.isNotEmpty)
                    TextButton(
                      onPressed: () => _removeAt(_stops.length - 1),
                      child: const Text(
                        'Undo',
                        style: TextStyle(fontSize: 10),
                      ),
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
                      options: MapOptions(
                        initialCenter: mapped.isEmpty ? _fallback : mapped.first,
                        initialZoom: 15,
                        minZoom: 5,
                        maxZoom: 19,
                        onTap: (_, point) => _addStop(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.ecoconnect',
                          maxZoom: 19,
                        ),
                        if (mapped.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: mapped,
                                strokeWidth: 4,
                                color: AppColors.forest.withValues(alpha: 0.75),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            for (var i = 0; i < _stops.length; i++)
                              if (_stops[i].hasCoordinates)
                                Marker(
                                  point: LatLng(_stops[i].latitude!,
                                      _stops[i].longitude!),
                                  width: 30,
                                  height: 30,
                                  child: _StopPin(index: i + 1),
                                ),
                          ],
                        ),
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
                                '${_stops.length}${_stops.length == 1 ? ' stop' : ' stops'}',
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
                          if (_stops.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                'No stops yet — tap anywhere on the map to '
                                'drop the first pin.',
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
                                itemCount: _stops.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 6),
                                itemBuilder: (context, index) => _StopChip(
                                  index: index + 1,
                                  name: _stops[index].name,
                                  onRename: () => _rename(index),
                                  onRemove: () => _removeAt(index),
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          PrimaryButton(
                            label: 'Use these stops',
                            onPressed: () =>
                                Navigator.of(context).pop(_stops),
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

class _StopPin extends StatelessWidget {
  const _StopPin({required this.index});

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

class _StopChip extends StatelessWidget {
  const _StopChip({
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
              child: Icon(Icons.close_rounded,
                  size: 13, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
