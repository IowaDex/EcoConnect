import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/user/screens/user_screen.dart';
import 'features/user/screens/wallet_screen.dart';
import 'features/driver/screens/driver_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/admin_panel_screen.dart';
import 'features/admin/screens/live_routes_screen.dart';
import 'features/ai/screens/ask_ai_screen.dart';
import 'features/alerts/screens/alerts_screen.dart';
import 'features/community/screens/community_screen.dart';
import 'features/incident/screens/report_incident_screen.dart';
import 'features/staff/screens/drop_off_station_screen.dart';
import 'features/staff/screens/incident_desk_screen.dart';
import 'features/staff/screens/pending_accounts_screen.dart';
import 'features/staff/screens/route_plans_screen.dart';
import 'features/splash/screens/splash_screen.dart';
import 'features/tracking/screens/tracking_screen.dart';

const _residentRoutes = {
  '/user',
  '/tracking',
  '/report-incident',
  '/wallet',
  '/community',
  '/ask-ai',
  '/alerts',
};
const _driverRoutes = {'/driver'};
const _staffRoutes = {
  '/admin-dashboard',
  '/admin',
  '/incidents',
  '/pending-accounts',
  '/routes',
  '/dropoff',
  '/tracking',
  '/live-routes',
};

String _homeFor(UserRole role) => switch (role) {
      UserRole.admin => '/admin-dashboard',
      UserRole.driver => '/driver',
      UserRole.user => '/user',
    };

Set<String> _allowedFor(UserRole role) => switch (role) {
      UserRole.admin => _staffRoutes,
      UserRole.driver => _driverRoutes,
      UserRole.user => _residentRoutes,
    };

/// Where to send the user, or null to stay. Pure so it can be unit tested.
String? authRedirect({
  required bool initialized,
  required UserRole? role,
  required String location,
}) {
  // Stay on the splash until the saved session is restored, so a
  // logged-in user never sees the login screen flash.
  if (!initialized) return location == '/splash' ? null : '/splash';

  final isAuthRoute = location == '/login' ||
      location == '/signup' ||
      location == '/forgot-password';

  if (role == null) return isAuthRoute ? null : '/login';
  if (isAuthRoute || location == '/splash') return _homeFor(role);
  // A driver must not reach the staff desk by typing the URL, and vice versa.
  if (!_allowedFor(role).contains(location)) return _homeFor(role);
  return null;
}

class EcoConnectApp extends StatefulWidget {
  const EcoConnectApp({super.key});

  @override
  State<EcoConnectApp> createState() => _EcoConnectAppState();
}

class _EcoConnectAppState extends State<EcoConnectApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final auth = context.read<AuthProvider>();
        return authRedirect(
          initialized: auth.isInitialized,
          role: auth.currentUser?.role,
          location: state.matchedLocation,
        );
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
        GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(path: '/user', builder: (_, __) => const UserScreen()),
        GoRoute(path: '/driver', builder: (_, __) => const DriverScreen()),
        GoRoute(path: '/admin-dashboard', builder: (_, __) => const AdminDashboardScreen()),
        GoRoute(path: '/admin', builder: (_, __) => const AdminPanelScreen()),
        GoRoute(path: '/tracking', builder: (_, __) => const TrackingScreen()),
        GoRoute(path: '/live-routes', builder: (_, __) => const LiveRoutesScreen()),
        GoRoute(path: '/report-incident', builder: (_, __) => const ReportIncidentScreen()),
        GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
        GoRoute(path: '/community', builder: (_, __) => const CommunityScreen()),
        GoRoute(path: '/ask-ai', builder: (_, __) => const AskAiScreen()),
        GoRoute(path: '/alerts', builder: (_, __) => const AlertsScreen()),
        GoRoute(path: '/incidents', builder: (_, __) => const IncidentDeskScreen()),
        GoRoute(path: '/pending-accounts', builder: (_, __) => const PendingAccountsScreen()),
        GoRoute(path: '/routes', builder: (_, __) => const RoutePlansScreen()),
        GoRoute(path: '/dropoff', builder: (_, __) => const DropOffStationScreen()),
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
