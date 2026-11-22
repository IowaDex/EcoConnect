import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../admin/services/user_data_cleanup.dart';
import '../../auth/services/auth_service.dart';
import '../../location/repositories/location_repository.dart';

/// Asks the desk to confirm removing [name]'s account. True when confirmed.
///
/// Removal is only for a resident who no longer belongs to the barangay: it
/// deletes the login's profile, so the account can never sign in again.
Future<bool> confirmRemoveResident(BuildContext context, String? name) async {
  final label = (name ?? '').trim().isEmpty ? 'this resident' : name!.trim();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove this resident?'),
      content: Text(
        'This deletes $label\'s EcoConnect account, the ID they uploaded and '
        'their personal records. Use it only when the resident no longer '
        'lives in Batasan Hills.\n\nThe login stops working right away.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Remove account'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Deletes a resident's account and everything personal it stored.
///
/// Personal records go first: if a delete is refused, the account itself is
/// still there to retry instead of leaving a half-removed profile.
Future<void> deleteResidentAccount(String uid) async {
  await UserDataCleanup().deleteAllFor(uid);
  await AuthService().deleteUser(
    uid,
    deleteLocationData: () => LocationRepository().deleteAllFor(uid),
  );
}
