import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../../auth/services/auth_service.dart';
import '../models/shared_location.dart';

class LocationMap extends StatefulWidget {
  const LocationMap({super.key});

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    final isDriver = authProvider.currentUser?.role == UserRole.driver;
    final markerIcon = isDriver ? Icons.local_shipping : Icons.place;

    if (!locationProvider.hasLocation) {
      return Card(
        child: Container(
          height: 250,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'Location not available',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get your location to see it on the map',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final latitude = locationProvider.latitude!;
    final longitude = locationProvider.longitude!;
    final position = LatLng(latitude, longitude);
    final otherLocations = locationProvider.sharedLocations.where(
      (location) => location.userId != authProvider.currentUser?.uid,
    );

    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Map container
            Container(
              height: 300,
              color: Colors.grey.shade200,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: position,
                  initialZoom: 16,
                  minZoom: 5,
                  maxZoom: 19,
                  interactionOptions: const InteractionOptions(
                    flags: ~InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  // OpenStreetMap tile layer
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ecoconnect',
                    maxZoom: 19,
                  ),
                  // Marker layer with current position
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: position,
                        width: 60,
                        height: 60,
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                markerIcon,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...otherLocations.map(
                        (location) => _buildSharedMarker(
                          context,
                          location,
                          colorScheme,
                        ),
                      ),
                    ],
                  ),
                  // Accuracy circle
                  if (locationProvider.currentPosition?.accuracy != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: position,
                          radius: locationProvider.currentPosition!.accuracy /
                              111000, // Convert meters to degrees (approx)
                          useRadiusInMeter: true,
                          color:
                              colorScheme.primary.withValues(alpha: 0.1),
                          borderColor: colorScheme.primary,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Location info footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Location',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          _mapController.move(position, 16);
                        },
                        icon: const Icon(Icons.center_focus_strong, size: 18),
                        label: const Text('Center'),
                      ),
                    ],
                  ),
                  if (locationProvider.currentPosition?.accuracy != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.gps_fixed,
                          size: 16,
                          color: _getAccuracyColor(locationProvider
                              .currentPosition!.accuracy),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Accuracy: ±${locationProvider.currentPosition!.accuracy.round()}m',
                          style: TextStyle(
                            color: _getAccuracyColor(locationProvider
                                .currentPosition!.accuracy),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildSharedMarker(
    BuildContext context,
    SharedLocation location,
    ColorScheme colorScheme,
  ) {
    return Marker(
      point: LatLng(location.latitude, location.longitude),
      width: 130,
      height: 72,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              location.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                fontSize: 11,
              ),
            ),
          ),
          Icon(
            location.role == 'driver'
                ? Icons.local_shipping
                : Icons.person_pin_circle,
            color: colorScheme.secondary,
            size: 28,
          ),
        ],
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy < 10) return Colors.green;
    if (accuracy < 30) return Colors.green.shade700;
    if (accuracy < 50) return Colors.orange;
    return Colors.red;
  }
}
