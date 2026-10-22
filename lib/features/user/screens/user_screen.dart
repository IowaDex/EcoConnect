import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../dashboard/widgets/gps_button.dart';
import '../../dashboard/widgets/location_display.dart';
import '../../dashboard/widgets/location_map.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      locationProvider.startSharedLocationUpdates();
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
    context.read<LocationProvider>().prepareLogout();
    // The app-wide messenger survives the switch to the login screen.
    final messenger = ScaffoldMessenger.of(context);
    final removed = await context.read<AuthProvider>().logout();
    if (!removed) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Signed out, but your shared location could not be '
            'removed. Sign in when online and turn sharing off.'),
        backgroundColor: Colors.orange,
      ));
    }
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
            Icon(Icons.place, size: 24),
            SizedBox(width: 8),
            Text('EcoConnect'),
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
                            child: Icon(Icons.place, size: 30, color: colorScheme.onPrimaryContainer),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Welcome,', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                                Text(user?.displayName ?? 'User', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                Text('Role: User', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500)),
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
                  Text('Your Location', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
              Card(
                child: SwitchListTile(
                  title: const Text('Share my location'),
                  subtitle: Text(
                    locationProvider.isSharingLocation
                        ? 'Other signed-in users can see your latest location'
                        : 'Your location is private',
                  ),
                  value: locationProvider.isSharingLocation,
                  onChanged: locationProvider.setSharingLocation,
                  secondary: Icon(
                    locationProvider.isSharingLocation
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
