import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/models/waste_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/map_config.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/eco_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../collection_points/models/collection_point.dart';
import '../../collection_points/services/collection_point_service.dart';
import '../../notifications/widgets/notification_bell.dart';

const _fallbackCentre = BatasanHills.center;

/// Designated collection points with a live map, driver assignments and
/// weekly schedules.
class CollectionPointsScreen extends StatefulWidget {
  const CollectionPointsScreen({super.key});

  @override
  State<CollectionPointsScreen> createState() => _CollectionPointsScreenState();
}

class _CollectionPointsScreenState extends State<CollectionPointsScreen> {
  final _service = CollectionPointService();
  final _map = MapController();
  bool _framed = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _frame(List<CollectionPoint> points) {
    if (_framed || points.isEmpty) return;
    _framed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coords = points.map((p) => p.latLng).toList();
      if (coords.length == 1) {
        _map.move(coords.first, 16);
      } else {
        _map.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(coords),
            padding: const EdgeInsets.all(40),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add point'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<CollectionPoint>>(
          stream: _service.watchAll(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(label: 'Loading collection points');
            }
            if (snapshot.hasError) {
              return ErrorView(message: AppFeedback.describe(snapshot.error!));
            }
            final points = snapshot.data ?? const <CollectionPoint>[];
            _frame(points);
            return Column(
              children: [
                AppPageHeader(
                  title: 'Collection points',
                  subtitle:
                      'Pin designated pickup locations and assign them to drivers.',
                  onBack: () => context.go('/admin-dashboard'),
                  actions: const [NotificationBell()],
                ),
                SizedBox(
                  height: 250,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: FlutterMap(
                          mapController: _map,
                          options: BatasanHills.options(
                            center: points.isEmpty
                                ? _fallbackCentre
                                : points.first.latLng,
                            zoom: BatasanHills.minZoom,
                          ),
                          children: [
                            BatasanHills.tiles(),
                            PolylineLayer(
                              polylines: _routes(points),
                            ),
                            MarkerLayer(
                              markers: [
                                for (final point in points)
                                  Marker(
                                    point: point.latLng,
                                    width: 42,
                                    height: 42,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _openDetail(context, point),
                                      child: _MapPin(point: point),
                                    ),
                                  ),
                              ],
                            ),
                            // The recentre button owns the bottom-right corner.
                            const OsmAttribution(alignment: Alignment.bottomLeft),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _MapButton(
                          icon: Icons.my_location_rounded,
                          onTap: () {
                            if (points.isNotEmpty) {
                              _map.move(points.first.latLng, 16);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Text(
                        '${points.length} designated location${points.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.route_rounded,
                          size: 13, color: AppColors.inkMuted),
                      const SizedBox(width: 4),
                      const Text(
                        'Lines link each driver\'s stops',
                        style: TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: points.isEmpty
                      ? EmptyState(
                          icon: Icons.add_location_alt_outlined,
                          title: 'No collection points yet',
                          message:
                              'Pin the first pickup location so drivers know where to go.',
                          actionLabel: 'Add collection point',
                          onAction: () => _openEditor(context),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                          itemCount: points.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final point = points[i];
                            return _PointCard(
                              point: point,
                              onTap: () => _openDetail(context, point),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Polyline> _routes(List<CollectionPoint> points) {
    final groups = <String, List<CollectionPoint>>{};
    for (final point in points) {
      final driver = point.driverId;
      if (driver == null || driver.isEmpty) continue;
      groups.putIfAbsent(driver, () => []).add(point);
    }
    return [
      for (final group in groups.values)
        if (group.length > 1)
          Polyline(
            points: group.map((p) => p.latLng).toList(),
            strokeWidth: 3,
            color: AppColors.primary.withValues(alpha: 0.55),
          ),
    ];
  }

  Future<void> _openDetail(BuildContext context, CollectionPoint point) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PointDetail(
        point: point,
        onEdit: () {
          Navigator.of(ctx).pop();
          _openEditor(context, existing: point);
        },
        onDelete: () async {
          Navigator.of(ctx).pop();
          await _delete(context, point);
        },
        onToggle: () async {
          Navigator.of(ctx).pop();
          try {
            await _service.toggleStatus(point);
            if (context.mounted) {
              AppFeedback.success(context, 'Location status updated');
            }
          } catch (e) {
            if (context.mounted) {
              AppFeedback.error(context, AppFeedback.describe(e));
            }
          }
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, CollectionPoint point) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Remove collection point?',
      message: '"${point.name}" will be removed from the map and driver routes.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !context.mounted) return;
    try {
      await _service.delete(point.id);
      if (context.mounted) AppFeedback.success(context, 'Location removed');
    } catch (e) {
      if (context.mounted) AppFeedback.error(context, AppFeedback.describe(e));
    }
  }

  Future<void> _openEditor(
    BuildContext context, {
    CollectionPoint? existing,
  }) async {
    final staff = context.read<AuthProvider>().currentUser;
    if (staff == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PointEditor(
        existing: existing,
        defaultBarangay: staff.barangay,
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.point});

  final CollectionPoint point;

  @override
  Widget build(BuildContext context) {
    final color = point.isActive ? AppColors.primary : AppColors.inkMuted;
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.delete_sweep_rounded,
        size: 20,
        color: Colors.white,
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 19, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({required this.point, required this.onTap});

  final CollectionPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: point.isActive
                  ? AppColors.lightGreen
                  : AppColors.inkMuted.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.place_rounded,
              size: 20,
              color: point.isActive ? AppColors.primary : AppColors.inkMuted,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        point.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: point.status.label,
                      color: point.status.color,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  point.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle_outlined,
                        size: 11, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        point.driverName ?? 'No driver assigned',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                    Text(
                      point.scheduleLabel,
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointDetail extends StatelessWidget {
  const _PointDetail({
    required this.point,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final CollectionPoint point;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
        children: [
          Row(
            children: [
              StatusBadge(
                label: point.status.label,
                color: point.status.color,
              ),
              const Spacer(),
              if (point.category != null)
                StatusBadge(
                  label: point.category!.shortLabel,
                  color: point.category!.color,
                  icon: point.category!.icon,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            point.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            point.address,
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 16),
          _row(Icons.map_outlined, point.barangay ?? 'Barangay not set'),
          _row(Icons.grid_view_rounded, point.zone ?? 'No zone set'),
          _row(
            Icons.person_pin_circle_outlined,
            point.driverName ?? 'No driver assigned',
          ),
          _row(Icons.schedule_rounded, point.scheduleLabel),
          _row(
            Icons.my_location_rounded,
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
          ),
          if (point.notes?.trim().isNotEmpty == true)
            _row(Icons.notes_rounded, point.notes!),
          const SizedBox(height: 18),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Edit location'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onToggle,
                    child: Text(
                      point.isActive ? 'Set inactive' : 'Set active',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Remove'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointEditor extends StatefulWidget {
  const _PointEditor({this.existing, this.defaultBarangay});

  final CollectionPoint? existing;
  final String? defaultBarangay;

  @override
  State<_PointEditor> createState() => _PointEditorState();
}

class _PointEditorState extends State<_PointEditor> {
  final _formKey = GlobalKey<FormState>();
  final _service = CollectionPointService();

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _barangay;
  late final TextEditingController _zone;
  late final TextEditingController _notes;
  late LatLng _position;
  late CollectionPointStatus _status;
  WasteCategory? _category;
  String? _driverId;
  String? _driverName;
  late Set<String> _days;
  TimeOfDay? _time;
  bool _saving = false;
  late Future<List<Map<String, dynamic>>> _drivers;

  static const _dayOptions = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _address = TextEditingController(text: existing?.address ?? '');
    _barangay = TextEditingController(
      text: existing?.barangay ?? widget.defaultBarangay ?? '',
    );
    _zone = TextEditingController(text: existing?.zone ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _position = existing?.latLng ?? _fallbackCentre;
    _status = existing?.status ?? CollectionPointStatus.active;
    _category = existing?.category;
    _driverId = existing?.driverId;
    _driverName = existing?.driverName;
    _days = {...?existing?.scheduleDays};
    _time = _parseTime(existing?.scheduleTime);
    _drivers = context.read<AuthProvider>().getDrivers();
  }

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _barangay, _zone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.save(
        id: widget.existing?.id,
        name: _name.text,
        address: _address.text,
        latitude: _position.latitude,
        longitude: _position.longitude,
        barangay: _barangay.text.trim().isEmpty ? null : _barangay.text.trim(),
        zone: _zone.text.trim().isEmpty ? null : _zone.text.trim(),
        driverId: _driverId,
        driverName: _driverName,
        scheduleDays: _days.toList()..sort(),
        scheduleTime: _time == null
            ? null
            : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
        category: _category,
        status: _status,
        notes: _notes.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(
        context,
        widget.existing == null
            ? 'Collection point added'
            : 'Collection point updated',
      );
    } catch (e) {
      if (mounted) AppFeedback.error(context, AppFeedback.describe(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null
                          ? 'Add collection point'
                          : 'Edit collection point',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Location name',
                          hintText: 'e.g. Purok 3 covered court',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().length < 3)
                                ? 'Please name this location'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          hintText: 'Street, landmark or coordinates',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Please add an address'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _barangay,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  const InputDecoration(labelText: 'Barangay'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _zone,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Zone / purok',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Tap the map to set the exact pin',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 190,
                          child: FlutterMap(
                            options: BatasanHills.options(
                              center: _position,
                              onTap: (_, point) =>
                                  setState(() => _position = point),
                            ),
                            children: [
                              BatasanHills.tiles(),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _position,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      size: 36,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_position.latitude.toStringAsFixed(5)}, ${_position.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<WasteCategory?>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Waste category (optional)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Any category'),
                          ),
                          for (final category in WasteCategory.values)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category.label),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _category = value),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _drivers,
                        builder: (context, snapshot) {
                          final drivers = snapshot.data ?? const [];
                          return DropdownButtonFormField<String?>(
                            initialValue: _driverId,
                            decoration: const InputDecoration(
                              labelText: 'Assigned driver',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('No driver assigned'),
                              ),
                              for (final driver in drivers)
                                DropdownMenuItem(
                                  value: driver['uid'] as String,
                                  child: Text(
                                    (driver['name'] as String?) ?? 'Driver',
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _driverId = value;
                                _driverName = value == null
                                    ? null
                                    : drivers
                                        .firstWhere(
                                          (d) => d['uid'] == value,
                                          orElse: () => const {},
                                        )['name'] as String?;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Collection days',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkGreen,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final day in _dayOptions)
                            FilterChip(
                              label: Text(day),
                              selected: _days.contains(day),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _days.add(day);
                                } else {
                                  _days.remove(day);
                                }
                              }),
                              labelStyle: TextStyle(
                                fontSize: 9.5,
                                color: _days.contains(day)
                                    ? Colors.white
                                    : AppColors.darkGreen,
                              ),
                              selectedColor: AppColors.primary,
                              showCheckmark: false,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.sage),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Text(
                                _time == null
                                    ? 'Set collection time'
                                    : _time!.format(context),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const Spacer(),
                              if (_time != null)
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _time = null),
                                  icon: const Icon(Icons.close_rounded, size: 16),
                                  color: AppColors.inkMuted,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'Gate code, landmark, access notes',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _status == CollectionPointStatus.active,
                        activeThumbColor: AppColors.primary,
                        title: const Text(
                          'Active location',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        onChanged: (value) => setState(
                          () => _status = value
                              ? CollectionPointStatus.active
                              : CollectionPointStatus.inactive,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.existing == null
                              ? 'Save collection point'
                              : 'Save changes',
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
