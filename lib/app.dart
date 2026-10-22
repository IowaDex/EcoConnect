import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/models/user.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/user/screens/user_screen.dart';
import 'features/driver/screens/driver_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/admin/screens/admin_panel_screen.dart';
import 'features/splash/splash_screen.dart';

/// Where to send the user, or null to stay. Pure so it can be unit tested.
String? authRedirect({
  required bool initialized,
  required UserRole? role,
  required String location,
}) {
  // Stay on the splash until the saved session is restored, so a
  // logged-in user never sees the login screen flash.
  if (!initialized) return location == '/splash' ? null : '/splash';

  final isLoggedIn = role != null;
  final isAuthRoute = location == '/login' || location == '/signup';

  if (!isLoggedIn && !isAuthRoute) return '/login';
  if (isLoggedIn && (isAuthRoute || location == '/splash')) {
    if (role == UserRole.admin) return '/admin-dashboard';
    if (role == UserRole.driver) return '/driver';
    return '/user';
  }
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
        GoRoute(path: '/user', builder: (_, __) => const UserScreen()),
        GoRoute(path: '/driver', builder: (_, __) => const DriverScreen()),
        GoRoute(path: '/admin-dashboard', builder: (_, __) => const AdminDashboardScreen()),
        GoRoute(path: '/admin', builder: (_, __) => const AdminPanelScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EcoConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}