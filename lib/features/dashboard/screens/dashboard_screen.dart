import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';
import '../../../core/models/user.dart';
import '../widgets/gps_button.dart';
import '../widgets/location_display.dart';
import '../widgets/location_map.dart';

class DashboardScreen extends StatefulWidget {
  final bool isDemo;

  const DashboardScreen({
    super.key,
    this.isDemo = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = context.read<LocationProvider>();
      if (!locationProvider.hasLocation) {
        locationProvider.getCurrentLocation();
      }
    });
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
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
    final role = user?.role ?? UserRole.user;
    final isEmailVerified = user?.emailVerified ?? false;

    // Role-specific logo/icon
    final IconData roleIcon = role == UserRole.driver
        ? Icons.local_shipping // Truck icon
        : role == UserRole.admin
        ? Icons.admin_panel_settings
        : Icons.place; // Landmark icon

    // If user is Admin, show Admin view
    if (role == UserRole.admin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => context.go('/admin'),
              tooltip: 'Admin Panel',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Logout',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 80,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Admin',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome, ${user?.displayName ?? 'Admin'}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.manage_accounts),
                label: const Text('Manage Users'),
                onPressed: () => context.go('/admin'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Common view for Driver and User (with different logos)
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roleIcon, size: 24),
            const SizedBox(width: 8),
            Text(role == UserRole.driver ? 'EcoConnect Driver' : 'EcoConnect'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Card with role icon
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
                            child: Icon(
                              roleIcon,
                              size: 30,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome,',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  user?.displayName ?? 'User',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  role == UserRole.driver ? 'Role: Driver' : 'Role: User',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Email verification status
                      Row(
                        children: [
                          Icon(
                            isEmailVerified
                                ? Icons.verified_user
                                : Icons.warning_amber_rounded,
                            color: isEmailVerified
                                ? Colors.green
                                : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isEmailVerified
                                  ? 'Email verified'
                                  : 'Email not verified',
                              style: TextStyle(
                                color: isEmailVerified
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Location Section Title
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    role == UserRole.driver ? 'Driver Location' : 'Your Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Location Display
              const LocationDisplay(),
              const SizedBox(height: 16),

              // GPS Button
              const GpsButton(),
              const SizedBox(height: 24),

              // Map Display
              const LocationMap(),
              const SizedBox(height: 24),

              // Real-time Tracking Toggle
              Card(
                child: SwitchListTile(
                  title: const Text('Real-time Tracking'),
                  subtitle: Text(
                    locationProvider.isTracking
                        ? 'Updating location automatically'
                        : 'Enable to track location in real-time',
                  ),
                  value: locationProvider.isTracking,
                  onChanged: (value) {
                    if (value) {
                      locationProvider.startTracking();
                    } else {
                      locationProvider.stopTracking();
                    }
                  },
                  secondary: Icon(
                    Icons.gps_fixed,
                    color: locationProvider.isTracking
                        ? Colors.green
                        : colorScheme.onSurfaceVariant,
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