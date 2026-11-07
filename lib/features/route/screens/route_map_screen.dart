import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/maps.dart';
import '../../../core/widgets/empty_state.dart';
import '../models/route_plan.dart';

/// Full-screen route map for the driver: every pinned stop, the path between
/// them, and the truck when it is already reporting.
class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({
    super.key,
    required this.title,
    required this.stops,
    this.truck,
  });

  final String title;
  final List<RouteStop> stops;
  final LatLng? truck;

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final _map = MapController();
  int? _selected;

  List<RouteStop> get _mapped =>
      [for (final stop in widget.stops) if (stop.hasCoordinates) stop];

  @override
  void initState() {
    super.initState();
    if (_mapped.isNotEmpty) _selected = 0;
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  RouteStop? get _selectedStop {
    final stops = _mapped;
    final index = _selected;
    if (index == null || index < 0 || index >= stops.length) return null;
    return stops[index];
  }

  void _select(int index, {bool recenter = true}) {
    setState(() => _selected = index);
    if (!recenter) return;
    final stop = _mapped[index];
    _map.move(LatLng(stop.latitude!, stop.longitude!), 17);
  }

  Future<void> _directions(RouteStop stop) async {
    final opened = await openDirections(stop.latitude!, stop.longitude!);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  void _fit(List<LatLng> all) {
    if (all.isEmpty) return;
    if (all.length == 1) {
      _map.move(all.first, 16);
      return;
    }
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(all),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stops = _mapped;
    final points = [
      for (final stop in stops) LatLng(stop.latitude!, stop.longitude!),
    ];
    final all = [...points, if (widget.truck != null) widget.truck!];
    final selected = _selectedStop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              tooltip: 'Fit all stops',
              onPressed: () => _fit(all),
              icon: const Icon(Icons.fit_screen_rounded),
            ),
        ],
      ),
      body: all.isEmpty
          ? const EmptyState(
              icon: Icons.map_outlined,
              title: 'No pinned stops',
              message: 'Staff have not pinned map coordinates for this run yet.',
            )
          : Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: all.first,
                      initialZoom: 15,
                      initialCameraFit: all.length > 1
                          ? CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(all),
                              padding: const EdgeInsets.all(60),
                            )
                          : null,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.ecoconnect',
                        maxZoom: 19,
                      ),
                      if (points.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points,
                              strokeWidth: 4,
                              color: AppColors.primary.withValues(alpha: 0.75),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          for (var i = 0; i < stops.length; i++)
                            Marker(
                              point: LatLng(
                                stops[i].latitude!,
                                stops[i].longitude!,
                              ),
                              width: 34,
                              height: 34,
                              child: GestureDetector(
                                onTap: () => _select(i),
                                child: _StopPin(
                                  number: i + 1,
                                  selected: _selected == i,
                                ),
                              ),
                            ),
                          if (widget.truck != null)
                            Marker(
                              point: widget.truck!,
                              width: 34,
                              height: 34,
                              child: const _TruckPin(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                _StopPanel(
                  stops: stops,
                  selected: _selected,
                  stop: selected,
                  onSelect: _select,
                  onDirections:
                      selected == null ? null : () => _directions(selected),
                  onCenter:
                      selected == null ? null : () => _select(_selected!),
                ),
              ],
            ),
    );
  }
}

class _StopPanel extends StatelessWidget {
  const _StopPanel({
    required this.stops,
    required this.selected,
    required this.stop,
    required this.onSelect,
    required this.onDirections,
    required this.onCenter,
  });

  final List<RouteStop> stops;
  final int? selected;
  final RouteStop? stop;
  final void Function(int index) onSelect;
  final VoidCallback? onDirections;
  final VoidCallback? onCenter;

  @override
  Widget build(BuildContext context) {
    final current = stop;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stops.length > 1) ...[
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: stops.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final active = i == selected;
                    return GestureDetector(
                      onTap: () => onSelect(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primary
                              : AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${i + 1}. ${stops[i].name}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.darkGreen,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (current == null)
              const Text(
                'Tap a pin to see the details.',
                style: TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
              )
            else ...[
              Text(
                current.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              if (current.address != null)
                _detail(Icons.place_outlined, current.address!),
              if (current.schedule != null)
                _detail(Icons.schedule_rounded, current.schedule!),
              if (current.notes != null)
                _detail(Icons.notes_rounded, current.notes!),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onDirections,
                      icon: const Icon(Icons.directions_rounded, size: 16),
                      label: const Text('Directions'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onCenter,
                    icon: const Icon(Icons.my_location_rounded, size: 15),
                    label: const Text('Center'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopPin extends StatelessWidget {
  const _StopPin({required this.number, required this.selected});

  final int number;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.warning : AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
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
        '$number',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _TruckPin extends StatelessWidget {
  const _TruckPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: const Icon(
        Icons.local_shipping_rounded,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}
