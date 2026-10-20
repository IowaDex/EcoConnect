import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/repositories/location_repository.dart';

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
                            ? 'Location available'
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

            if (locationProvider.hasLocation) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _syncIcon(locationProvider.syncState),
                    size: 16,
                    color: _syncColor(locationProvider.syncState),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _syncMessage(locationProvider),
                    style: TextStyle(
                      color: _syncColor(locationProvider.syncState),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
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
                  'Tap "Get Current Location" to display your location on the map',
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

  String _syncMessage(LocationProvider provider) {
    switch (provider.syncState) {
      case LocationSyncState.synced:
        return 'Location synced';
      case LocationSyncState.pending:
        return '${provider.pendingCount} location(s) waiting to sync';
      case LocationSyncState.syncing:
        return 'Syncing location';
      case LocationSyncState.offline:
        return 'Saved offline; waiting for connection';
      case LocationSyncState.failed:
        return 'Saved locally; sync will retry';
    }
  }

  IconData _syncIcon(LocationSyncState state) {
    switch (state) {
      case LocationSyncState.synced:
        return Icons.cloud_done;
      case LocationSyncState.pending:
      case LocationSyncState.syncing:
        return Icons.cloud_upload;
      case LocationSyncState.offline:
        return Icons.cloud_off;
      case LocationSyncState.failed:
        return Icons.sync_problem;
    }
  }

  Color _syncColor(LocationSyncState state) {
    switch (state) {
      case LocationSyncState.synced:
        return Colors.green;
      case LocationSyncState.pending:
      case LocationSyncState.syncing:
        return Colors.orange;
      case LocationSyncState.offline:
      case LocationSyncState.failed:
        return Colors.red;
    }
  }
}