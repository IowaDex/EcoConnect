import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// How an account is classified. Government personnel keep the resident
/// dashboard but unlock the special collection request feature once verified.
enum AccountType { resident, government }

extension AccountTypeX on AccountType {
  String get label => this == AccountType.government
      ? 'Government personnel'
      : 'Regular resident';

  String get shortLabel =>
      this == AccountType.government ? 'Government' : 'Resident';

  IconData get icon => this == AccountType.government
      ? Icons.badge_outlined
      : Icons.home_outlined;

  static AccountType fromName(String? name) =>
      name == 'government' ? AccountType.government : AccountType.resident;
}

/// Verification lifecycle for an account or uploaded ID.
enum VerificationStatus { unverified, pending, verified, rejected }

extension VerificationStatusX on VerificationStatus {
  String get label => switch (this) {
        VerificationStatus.unverified => 'Unverified',
        VerificationStatus.pending => 'Pending verification',
        VerificationStatus.verified => 'Verified',
        VerificationStatus.rejected => 'Rejected',
      };

  Color get color => switch (this) {
        VerificationStatus.unverified => AppColors.inkMuted,
        VerificationStatus.pending => AppColors.warning,
        VerificationStatus.verified => AppColors.primary,
        VerificationStatus.rejected => AppColors.error,
      };

  IconData get icon => switch (this) {
        VerificationStatus.unverified => Icons.help_outline_rounded,
        VerificationStatus.pending => Icons.hourglass_top_rounded,
        VerificationStatus.verified => Icons.verified_rounded,
        VerificationStatus.rejected => Icons.gpp_bad_outlined,
      };

  static VerificationStatus fromName(String? name) =>
      VerificationStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => VerificationStatus.unverified,
      );
}
