import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/location_provider.dart';

class LocationDisplay extends StatelessWidget {
  const LocationDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Location icon and label
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: locationProvider.hasLocation
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    locationProvider.hasLocation
                        ? Icons.location_on
                        : Icons.location_off,
                    color: locationProvider.hasLocation
                        ? Colors.green
                        : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Location',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        locationProvider.hasLocation
                            ? 'Coordinates captured'
                            : 'No location yet',
                        style: TextStyle(
                          color: locationProvider.hasLocation
                              ? Colors.green
                              : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Coordinates display
            if (locationProvider.hasLocation) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Latitude
              Row(
                children: [
                  Expanded(
                    child: _CoordinateTile(
                      label: 'Latitude',
                      value: locationProvider.latitude!.toStringAsFixed(6),
                      icon: Icons.arrow_upward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CoordinateTile(
                      label: 'Longitude',
                      value: locationProvider.longitude!.toStringAsFixed(6),
                      icon: Icons.arrow_forward,
                    ),
                  ),
                ],
              ),

              // Accuracy indicator
              if (locationProvider.currentPosition?.accuracy != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        size: 16,
                        color: _getAccuracyColor(
                            locationProvider.currentPosition!.accuracy),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Accuracy: ±${locationProvider.currentPosition!.accuracy.round()}m',
                        style: TextStyle(
                          color: _getAccuracyColor(
                              locationProvider.currentPosition!.accuracy),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // No location message
            if (!locationProvider.hasLocation && !locationProvider.isLoading)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Tap "Get Current Location" to fetch your GPS coordinates',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
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

class _CoordinateTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CoordinateTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}