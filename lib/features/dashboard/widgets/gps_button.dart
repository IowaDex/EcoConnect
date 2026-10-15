import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/location_provider.dart';

class GpsButton extends StatelessWidget {
  const GpsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // GPS Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: locationProvider.isLoading
                    ? null
                    : () async {
                        await locationProvider.getCurrentLocation();

                        // Show error if any
                        if (locationProvider.error != null && context.mounted) {
                          _showLocationError(context, locationProvider);
                        }
                      },
                icon: locationProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.gps_fixed),
                label: Text(
                  locationProvider.isLoading
                      ? 'Getting Location...'
                      : 'Get Current Location',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            // Error message
            if (locationProvider.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locationProvider.error!,
                        style: TextStyle(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => locationProvider.getCurrentLocation(),
                      color: colorScheme.onErrorContainer,
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLocationError(BuildContext context, LocationProvider locationProvider) {
    final error = locationProvider.error ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red.shade600,
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            if (error.contains('disabled')) {
              locationProvider.openLocationSettings();
            } else if (error.contains('permission')) {
              locationProvider.openAppSettings();
            }
          },
        ),
      ),
    );

    // Clear error after showing
    Future.delayed(const Duration(seconds: 1), () {
      locationProvider.clearError();
    });
  }
}