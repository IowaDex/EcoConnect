import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../dashboard/widgets/gps_button.dart';
import '../../dashboard/widgets/location_display.dart';
import '../../dashboard/widgets/location_map.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      if (!locationProvider.hasLocation) locationProvider.getCurrentLocation();
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final user = authProvider.currentUser;
    final isEmailVerified = user?.emailVerified ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping, size: 24),
            SizedBox(width: 8),
            Text('EcoConnect Driver'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout, tooltip: 'Logout'),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(Icons.local_shipping, size: 30, color: colorScheme.onPrimaryContainer),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome,', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                                Text(user?.displayName ?? 'Driver', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                Text('Role: Driver', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isEmailVerified ? Icons.verified_user : Icons.warning_amber_rounded,
                            color: isEmailVerified ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEmailVerified ? 'Email verified' : 'Email not verified',
                            style: TextStyle(color: isEmailVerified ? Colors.green : Colors.orange, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.location_on, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Driver Location', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const LocationDisplay(),
              const SizedBox(height: 16),
              const GpsButton(),
              const SizedBox(height: 24),
              const LocationMap(),
              const SizedBox(height: 24),
              Card(
                child: SwitchListTile(
                  title: const Text('Real-time Tracking'),
                  subtitle: Text(locationProvider.isTracking ? 'Updating location automatically' : 'Enable to track location in real-time'),
                  value: locationProvider.isTracking,
                  onChanged: (value) => value ? locationProvider.startTracking() : locationProvider.stopTracking(),
                  secondary: Icon(Icons.gps_fixed, color: locationProvider.isTracking ? Colors.green : colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
