import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/service_area.dart';
import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/provisioning_service.dart';
import '../../calls/providers/call_provider.dart';
import '../../sos/services/sos_service.dart';

/// The barangay desks a District Officer can ring.
///
/// After an SOS, the officer opens this list already filtered to the affected
/// barangay. Each row is one `admin` account; the call targets that person,
/// not the whole desk, and carries the incident reference into the history.
class BarangayStaffDirectoryScreen extends StatelessWidget {
  const BarangayStaffDirectoryScreen({
    super.key,
    this.barangay,
    this.incidentId,
    this.incidentCode,
    this.incidentReason,
  });

  /// When set, only staff for this barangay are listed.
  final String? barangay;
  final String? incidentId;
  final String? incidentCode;
  final String? incidentReason;

  bool get _hasIncident =>
      (incidentId ?? '').trim().isNotEmpty &&
      (incidentCode ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final affected = (barangay ?? '').trim();
    return EcoPageScaffold(
      eyebrow: _hasIncident
          ? 'SOS ${incidentCode!} · BARANGAY DIRECTORY'
          : 'DISTRICT OFFICER · BARANGAY DIRECTORY',
      title: affected.isEmpty ? 'Barangay staff' : affected,
      subtitle: affected.isEmpty
          ? 'Call the desk that owns the affected area and explain the delay, '
                'so residents can be informed.'
          : 'The staff assigned to $affected. Pick the person who will brief '
                'the barangay about this incident.',
      icon: Icons.contact_phone_rounded,
      onBack: () => ecoBack(context, '/district-officer'),
      body: StreamBuilder<List<ProvisionedAccount>>(
        stream: ProvisioningService().watchBarangayStaff(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_rounded,
              text: 'Could not load the barangay staff.\n${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.forest,
                strokeWidth: 2,
              ),
            );
          }
          final all = snapshot.data ?? const <ProvisionedAccount>[];
          final staff = affected.isEmpty
              ? all
              : all
                    .where(
                      (member) => _areaOf(member).toLowerCase() ==
                          affected.toLowerCase(),
                    )
                    .toList(growable: false);
          if (all.isEmpty) {
            return const _Message(
              icon: Icons.groups_outlined,
              text:
                  'No barangay staff account yet.\nCity Hall provisions the '
                  'barangay desk logins.',
            );
          }
          if (staff.isEmpty) {
            return _Message(
              icon: Icons.person_search_rounded,
              text:
                  'No staff account is assigned to $affected.\nCall City Hall '
                  'so the barangay desk login is created for this area.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              if (_hasIncident) ...[
                _IncidentBanner(
                  code: incidentCode!,
                  reason: incidentReason ?? '',
                  barangay: affected,
                ),
                const SizedBox(height: 12),
              ],
              const _Note(),
              const SizedBox(height: 14),
              for (final member in staff) ...[
                _StaffTile(
                  member: member,
                  incidentId: incidentId,
                  incidentCode: incidentCode,
                  incidentReason: incidentReason,
                ),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _IncidentBanner extends StatelessWidget {
  const _IncidentBanner({
    required this.code,
    required this.reason,
    required this.barangay,
  });

  final String code;
  final String reason;
  final String barangay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sos_rounded, size: 18, color: AppColors.error),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calling about $code',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$reason · $barangay',
                  style: const TextStyle(
                    fontSize: 9.5,
                    height: 1.4,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy staff profiles may not carry a barangay. The deployment serves one
/// barangay, so an empty area means the served area rather than "unknown".
String _areaOf(ProvisionedAccount member) {
  final area = (member.barangay ?? '').trim();
  return area.isEmpty ? ServiceArea.barangay : area;
}

class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.sage),
      ),
      child: const Text(
        'Calls stay inside EcoConnect. Pick the barangay that owns the '
        'affected area; every call is saved to your call history.',
        style: TextStyle(
          fontSize: 10,
          height: 1.5,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.member,
    this.incidentId,
    this.incidentCode,
    this.incidentReason,
  });

  final ProvisionedAccount member;
  final String? incidentId;
  final String? incidentCode;
  final String? incidentReason;

  Future<void> _call(BuildContext context) async {
    final calls = context.read<CallProvider>();
    if (calls.busy) {
      _snack(context, 'A call is already in progress.', AppColors.warning);
      return;
    }
    if (!member.isActive) {
      _snack(context, 'That staff account is suspended.', AppColors.warning);
      return;
    }
    final area = member.barangay?.trim();
    final hasIncident =
        (incidentId ?? '').trim().isNotEmpty &&
        (incidentCode ?? '').trim().isNotEmpty;
    await calls.startCall(
      toRole: 'admin',
      toUid: member.uid,
      context: hasIncident ? 'sos' : 'delay',
      reference: hasIncident
          ? incidentCode!.trim()
          : (area == null || area.isEmpty ? null : area),
      incidentId: hasIncident ? incidentId!.trim() : null,
      barangay: area,
      note: hasIncident
          ? '${incidentReason?.trim().isNotEmpty == true ? incidentReason!.trim() : 'SOS incident'}'
                '${area == null || area.isEmpty ? '' : ' · $area'}'
          : null,
    );
    if (!context.mounted) return;
    _snack(context, 'Calling ${member.name}…', AppColors.forest);
    // Ringing the barangay is the coordination step, so the incident moves on
    // its own instead of waiting for a separate button.
    if (hasIncident) {
      final user = context.read<AuthProvider>().currentUser;
      if (user != null && user.role == UserRole.districtOfficer) {
        SosService()
            .markCoordinating(
              incidentId!.trim(),
              uid: user.uid,
              name: user.displayName ?? 'District Officer',
            )
            .catchError((Object _) {});
      }
    }
  }

  void _snack(BuildContext context, String text, Color tone) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: tone));
  }

  @override
  Widget build(BuildContext context) {
    final area = _areaOf(member);
    final phone = member.phone?.trim() ?? '';
    final subtitle = [area, if (phone.isNotEmpty) phone].join(' · ');

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        children: [
          _Avatar(member: member),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusPill(active: member.isActive),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Call ${member.name}',
            child: IconButton(
              onPressed: () => _call(context),
              icon: const Icon(
                Icons.call_rounded,
                size: 18,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member});

  final ProvisionedAccount member;

  @override
  Widget build(BuildContext context) {
    final photo = member.photoUrl;
    return Container(
      height: 40,
      width: 40,
      decoration: const BoxDecoration(
        color: AppColors.cream,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null || photo.isEmpty
          ? const Icon(
              Icons.shield_outlined,
              size: 19,
              color: AppColors.forest,
            )
          : Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.shield_outlined,
                size: 19,
                color: AppColors.forest,
              ),
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final tone = active ? AppColors.forest : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'active' : 'suspended',
        style: TextStyle(
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          color: tone,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: EmptyState(
          icon: icon,
          title: 'Barangay staff',
          message: text,
        ),
      ),
    );
  }
}
