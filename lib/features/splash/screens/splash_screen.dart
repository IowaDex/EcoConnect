import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/eco_loading.dart';

/// Boot screen. The collection truck drives across its panel while a tip card
/// cycles through household recycling advice, so the wait reads as part of the
/// product instead of a blank spinner.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the fade/rise of the brand and the loading panel.
  late final AnimationController _intro;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _timer = Timer(const Duration(milliseconds: 2200), _next);
  }

  void _next() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isInitialized) {
      // Session still restoring; /login would bounce back here, so wait.
      _timer = Timer(const Duration(milliseconds: 200), _next);
      return;
    }
    final user = auth.currentUser;
    if (user == null) {
      context.go('/welcome');
      return;
    }
    switch (user.role) {
      case UserRole.admin:
        context.go('/admin-dashboard');
      case UserRole.driver:
        context.go('/driver');
      case UserRole.user:
        context.go('/user');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE4F3E0), Color(0xFFF4FAF1), Color(0xFFE8F4E2)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Shrink the artwork on short windows so the truck panel never
              // collides with the wordmark or the status line.
              final width = math
                  .min(constraints.maxWidth - 56, constraints.maxHeight * 0.34)
                  .clamp(210.0, 330.0);
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: SlideTransition(
                    position: rise,
                    child: FadeTransition(
                      opacity: fade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandLockup(fontSize: 25),
                          const SizedBox(height: 8),
                          const Text(
                            'KNOW WHEN, KNOW WHERE',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 30),
                          EcoLoadingBody(
                            width: width,
                            tipInterval: const Duration(milliseconds: 1900),
                          ),
                          const SizedBox(height: 24),
                          const EcoLoadingDots(color: AppColors.forest),
                          const SizedBox(height: 10),
                          const Text(
                            'Preparing your barangay feed',
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.3,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
