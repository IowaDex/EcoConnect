import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_bottom_nav.dart';

/// Bottom navigation for the driver side: Home, Routes, Completed, Profile.
///
/// The bar itself is the shared [AppBottomNav]; this wrapper only supplies the
/// crew's four destinations so a driver and a resident see the same control.
class DriverNavBar extends StatelessWidget {
  const DriverNavBar({super.key, required this.currentIndex});

  final int currentIndex;

  static const _routes = [
    '/driver',
    '/driver-routes',
    '/driver-completed',
    '/driver-profile',
  ];

  @override
  Widget build(BuildContext context) {
    return AppBottomNav(
      currentIndex: currentIndex,
      items: const [
        (icon: Icons.home_rounded, label: 'Home'),
        (icon: Icons.route_rounded, label: 'Routes'),
        (icon: Icons.check_circle_outline_rounded, label: 'Completed'),
        (icon: Icons.person_outline_rounded, label: 'Profile'),
      ],
      onTap: (index) {
        if (index == currentIndex) return;
        context.go(_routes[index]);
      },
    );
  }
}
