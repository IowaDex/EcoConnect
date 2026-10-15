import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().currentUser?.role ?? UserRole.user;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (role) {
        case UserRole.user:
          context.go('/user');
        case UserRole.driver:
          context.go('/driver');
        case UserRole.admin:
          context.go('/admin-dashboard');
      }
    });

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
