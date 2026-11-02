import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/models/user.dart';
import 'core/providers/auth_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/ai/screens/ask_ai_screen.dart';
import 'features/alerts/screens/alerts_screen.dart';
import 'features/community/screens/community_screen.dart';
import 'features/admin/screens/admin_panel_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/driver/screens/driver_screen.dart';
import 'features/incident/screens/report_incident_screen.dart';
import 'features/staff/screens/incident_desk_screen.dart';
import 'features/staff/screens/drop_off_station_screen.dart';
import 'features/staff/screens/pending_accounts_screen.dart';
import 'features/staff/screens/route_plans_screen.dart';
import 'features/user/screens/wallet_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/tracking/screens/tracking_screen.dart';
import 'features/user/screens/user_screen.dart';

class EcoConnectApp extends StatefulWidget {
  const EcoConnectApp({super.key});

  @override
  State<EcoConnectApp> createState() => _EcoConnectAppState();
}

class _EcoConnectAppState extends State<EcoConnectApp> {
  late final GoRouter _router;

  static const _residentRoutes = {
    '/dashboard',
    '/user',
    '/tracking',
    '/report-incident',
    '/wallet',
    '/community',
    '/ask-ai',
    '/alerts',
  };

  static const _driverRoutes = {'/dashboard', '/driver'};

  static const _staffRoutes = {
    '/dashboard',
    '/admin-dashboard',
    '/admin',
    '/incidents',
    '/pending-accounts',
    '/routes',
    '/dropoff',
    '/tracking',
  };

  static String _homeFor(UserRole? role) => switch (role) {
        UserRole.admin => '/admin-dashboard',
        UserRole.driver => '/driver',
        _ => '/user',
      };

  static Set<String> _allowedFor(UserRole? role) => switch (role) {
        UserRole.admin => _staffRoutes,
        UserRole.driver => _driverRoutes,
        _ => _residentRoutes,
      };

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        final isLoggedIn = auth.currentUser != null;
        final role = auth.currentUser?.role;
        final loc = state.matchedLocation;
        final isAuthRoute = loc == '/login' || loc == '/signup';

        if (loc == '/splash') return null;
        if (!isLoggedIn) return isAuthRoute ? null : '/login';

        final home = _homeFor(role);
        if (isAuthRoute) return home;

        // Role-based access control: a driver must not be able to open the
        // staff desk by typing the URL, and vice versa.
        if (!_allowedFor(role).contains(loc)) return home;
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/user', builder: (_, __) => const UserScreen()),
        GoRoute(path: '/tracking', builder: (_, __) => const TrackingScreen()),
        GoRoute(
            path: '/report-incident',
            builder: (_, __) => const ReportIncidentScreen()),
        GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
        GoRoute(
            path: '/community',
            builder: (_, __) => const CommunityScreen()),
        GoRoute(path: '/ask-ai', builder: (_, __) => const AskAiScreen()),
        GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
        GoRoute(
            path: '/incidents', builder: (_, __) => const IncidentDeskScreen()),
        GoRoute(
            path: '/pending-accounts',
            builder: (_, __) => const PendingAccountsScreen()),
        GoRoute(path: '/driver', builder: (_, __) => const DriverScreen()),
        GoRoute(
            path: '/routes', builder: (_, __) => const RoutePlansScreen()),
        GoRoute(
            path: '/dropoff',
            builder: (_, __) => const DropOffStationScreen()),
        GoRoute(
            path: '/admin-dashboard',
            builder: (_, __) => const AdminDashboardScreen()),
        GoRoute(path: '/admin', builder: (_, __) => const AdminPanelScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EcoConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // The EcoConnect design system is a light-only brand palette.
      themeMode: ThemeMode.light,
      routerConfig: _router,
    );
  }
}
