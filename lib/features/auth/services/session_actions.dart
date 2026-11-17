import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/confirm_logout.dart';
import '../../location/providers/location_provider.dart';
import '../providers/auth_provider.dart';

/// Asks for confirmation, drops the shared location pin, signs out and lands
/// on the login screen.
///
/// Every desk used to repeat these six lines. Keeping them in one place means
/// the pin is always cleaned up before the rules stop allowing the write.
Future<void> confirmAndLogout(BuildContext context) async {
  if (!await confirmLogout(context)) return;
  if (!context.mounted) return;

  final auth = context.read<AuthProvider>();
  await context.read<LocationProvider>().endSession();
  await auth.logout();
  if (context.mounted) context.go('/login');
}
