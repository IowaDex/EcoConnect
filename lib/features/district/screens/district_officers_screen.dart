import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/resident_areas.dart';
import '../../../core/constants/service_area.dart';
import '../../../core/constants/service_districts.dart';
import '../../../core/widgets/eco_page.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/provisioning_service.dart';
import '../../auth/utils/validators.dart';
import '../../auth/widgets/password_strength.dart';
import '../../calls/providers/call_provider.dart';

/// City Hall's District Officer desk.
///
/// The DSQC is the only office that mints this login. The officer then gets a
/// dashboard of their own, where a delay alert from City Hall arrives as a
/// ringing in-app call.
class DistrictOfficersScreen extends StatefulWidget {
  const DistrictOfficersScreen({super.key});

  @override
  State<DistrictOfficersScreen> createState() => _DistrictOfficersScreenState();
}

class _DistrictOfficersScreenState extends State<DistrictOfficersScreen> {
  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().currentUser?.role;
    final canManage = role == UserRole.cityHall;

    return EcoPageScaffold(
      eyebrow: 'CITY HALL · DISTRICT OFFICERS',
      title: 'District Officers',
      subtitle:
          'Create the officer login City Hall rings when a collection runs '
          'late. The officer confirms the reason with DSQC, then calls the '
          'barangay.',
      icon: Icons.support_agent_rounded,
      onBack: () => ecoBack(context, '/cityhall'),
      fab: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text(
                'Officer',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: StreamBuilder<List<ProvisionedAccount>>(
        stream: ProvisioningService().watchDistrictOfficers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'Could not load the officers.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.6,
                  color: AppColors.inkMuted,
                ),
              ),
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
          final officers = snapshot.data ?? const <ProvisionedAccount>[];
          if (officers.isEmpty) {
            return const _EmptyOfficers();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              _SosShortcut(onTap: () => context.push('/sos')),
              const SizedBox(height: 10),
              if (officers.any((officer) => officer.isActive))
                _ContactButton(
                  onTap: () => _contactOfficer(context, officers),
                ),
              if (officers.any((officer) => officer.isActive))
                const SizedBox(height: 14),
              _HowItWorks(),
              const SizedBox(height: 14),
              for (final officer in officers) ...[
                _OfficerTile(
                  officer: officer,
                  canManage: canManage,
                  onCall: () => _callOfficer(context, officer),
                  onActions: canManage
                      ? () => _openActions(context, officer)
                      : null,
                ),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _callOfficer(
    BuildContext context,
    ProvisionedAccount officer,
  ) async {
    final calls = context.read<CallProvider>();
    if (calls.busy) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('A call is already in progress.'),
            backgroundColor: AppColors.warning,
          ),
        );
      return;
    }
    if (!officer.isActive) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('That officer account is suspended.'),
            backgroundColor: AppColors.warning,
          ),
        );
      return;
    }
    await calls.startCall(
      toRole: UserRole.districtOfficer.name,
      toUid: officer.uid,
      context: 'general',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Calling ${officer.name}…'),
          backgroundColor: AppColors.forest,
        ),
      );
  }

  Future<void> _openForm(BuildContext context) async {
    final handover = await showModalBottomSheet<_Handover>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _OfficerForm(),
    );
    if (handover == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.creamBright,
        title: const Text(
          'District Officer account created',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hand these over now. Firebase keeps only a hash, so the '
              'password cannot be shown again.',
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 12),
            _HandoverRow(label: 'Email', value: handover.email),
            const SizedBox(height: 6),
            _HandoverRow(label: 'Password', value: handover.password),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openActions(
    BuildContext context,
    ProvisionedAccount officer,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfficerActions(officer: officer),
    );
  }

  Future<void> _contactOfficer(
    BuildContext context,
    List<ProvisionedAccount> officers,
  ) async {
    final active = officers.where((officer) => officer.isActive).toList();
    final alert = await showModalBottomSheet<_OfficerAlert>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactOfficerSheet(officers: active),
    );
    if (alert == null || !context.mounted) return;

    final calls = context.read<CallProvider>();
    if (calls.busy) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('A call is already in progress.'),
            backgroundColor: AppColors.warning,
          ),
        );
      return;
    }
    await calls.startCall(
      toRole: UserRole.districtOfficer.name,
      toUid: alert.officer.uid,
      context: 'delay',
      reference: '${alert.incident} · ${alert.area}',
      note: alert.details,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Alerting ${alert.officer.name} · ${alert.incident}…',
          ),
          backgroundColor: AppColors.forest,
        ),
      );
  }
}

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.lg),
        border: Border.all(color: AppColors.sage),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DELAY CALL FLOW',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.forest,
            ),
          ),
          SizedBox(height: 7),
          _Step(
            number: '1',
            text: 'ISWIM reports the truck problem to DSQC.',
          ),
          _Step(
            number: '2',
            text: 'DSQC files the complete incident and sends the SOS.',
          ),
          _Step(
            number: '3',
            text: 'The officer for that district gets the alert with sound, '
                'vibration and the full details.',
          ),
          _Step(
            number: '4',
            text: 'The officer calls the affected barangay staff in the app.',
          ),
          _Step(
            number: '5',
            text: 'The officer updates the coordination status; every call is '
                'saved to the incident and the call history.',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 16,
            width: 16,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: AppColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                height: 1.4,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficerTile extends StatelessWidget {
  const _OfficerTile({
    required this.officer,
    required this.canManage,
    required this.onCall,
    this.onActions,
  });

  final ProvisionedAccount officer;
  final bool canManage;
  final VoidCallback onCall;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    final phone = officer.phone?.trim() ?? '';
    final district = officer.district?.trim() ?? '';
    final subtitle = [
      officer.email,
      if (district.isNotEmpty) district else 'No district assigned',
      if (phone.isNotEmpty) phone,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: const BoxDecoration(
              color: AppColors.cream,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 19,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        officer.name,
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
                    _StatusPill(active: officer.isActive),
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
            message: 'Call ${officer.name}',
            child: IconButton(
              onPressed: onCall,
              icon: const Icon(
                Icons.call_rounded,
                size: 18,
                color: AppColors.forest,
              ),
            ),
          ),
          if (canManage)
            IconButton(
              onPressed: onActions,
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: AppColors.moss,
              ),
            ),
        ],
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

class _EmptyOfficers extends StatelessWidget {
  const _EmptyOfficers();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 62,
              width: 62,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                size: 28,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No District Officer yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap Officer to create the login City Hall will ring when a '
              'truck runs late.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.55,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Handover {
  const _Handover({required this.email, required this.password});

  final String email;
  final String password;
}

class _OfficerForm extends StatefulWidget {
  const _OfficerForm();

  @override
  State<_OfficerForm> createState() => _OfficerFormState();
}

class _OfficerFormState extends State<_OfficerForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _district = ServiceDistricts.defaultDistrict;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _password.text = _suggestPassword();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  String _suggestPassword() {
    final random = Random.secure();
    final digits = List.generate(6, (_) => random.nextInt(10)).join();
    return 'Eco-$digits!';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ProvisioningService().create(
        ProvisionRequest(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          role: UserRole.districtOfficer,
          phone: _phone.text,
          district: _district,
        ),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(_Handover(email: _email.text.trim(), password: _password.text));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: AppColors.error),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.sage,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'New District Officer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'This account can receive SOS alerts and ring the barangay. '
                'An SOS is routed only to the officer assigned to its district.',
                style: TextStyle(
                  fontSize: 9,
                  height: 1.45,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  isDense: true,
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'officer.ecoconnect@gmail.com',
                  isDense: true,
                ),
                validator: (value) {
                  final email = (value ?? '').trim();
                  if (email.isEmpty) return 'Enter an email';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _district,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assigned district',
                  isDense: true,
                ),
                items: [
                  for (final district in ServiceDistricts.all)
                    DropdownMenuItem(
                      value: district,
                      child: Text(
                        district,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                onChanged: (value) => setState(
                  () => _district = value ?? ServiceDistricts.defaultDistrict,
                ),
                validator: (value) => ServiceDistricts.isValid(value)
                    ? null
                    : 'Choose the district this officer covers',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Password',
                  isDense: true,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _showPassword
                            ? 'Hide password'
                            : 'Show password',
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 17,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                      IconButton(
                        tooltip: 'Generate a password',
                        icon: const Icon(Icons.casino_outlined, size: 17),
                        onPressed: () =>
                            setState(() => _password.text = _suggestPassword()),
                      ),
                    ],
                  ),
                ),
                validator: Validators.validatePasswordStrength,
              ),
              const SizedBox(height: 8),
              PasswordStrengthChecklist(password: _password.text),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create officer account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficerActions extends StatefulWidget {
  const _OfficerActions({required this.officer});

  final ProvisionedAccount officer;

  @override
  State<_OfficerActions> createState() => _OfficerActionsState();
}

class _OfficerActionsState extends State<_OfficerActions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(done), backgroundColor: AppColors.forest),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: AppColors.error),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDistrict() async {
    final officer = widget.officer;
    final current = officer.district?.trim();
    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: AppColors.creamBright,
        title: const Text(
          'Assigned district',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
        children: [
          for (final district in ServiceDistricts.all)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(district),
              child: Row(
                children: [
                  Icon(
                    district == current
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: district == current
                        ? AppColors.forest
                        : AppColors.inkMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    district,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    await _run(
      () => ProvisioningService().setDistrict(officer.uid, chosen),
      '${officer.name} now covers $chosen',
    );
  }

  @override
  Widget build(BuildContext context) {
    final officer = widget.officer;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      decoration: const BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            officer.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          Text(
            officer.email,
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 16),
          _Action(
            icon: Icons.map_outlined,
            label: 'Assign district',
            detail: officer.district?.trim().isNotEmpty == true
                ? 'Currently ${officer.district}'
                : 'No district assigned — SOS cannot reach this officer',
            onTap: _busy ? null : _pickDistrict,
          ),
          const SizedBox(height: 8),
          _Action(
            icon: Icons.lock_reset_rounded,
            label: 'Send a password reset',
            detail: 'Email from Firebase',
            onTap: _busy
                ? null
                : () => _run(
                    () => ProvisioningService().resetPassword(officer.email),
                    'Reset email sent to ${officer.email}',
                  ),
          ),
          const SizedBox(height: 8),
          _Action(
            icon: officer.isActive
                ? Icons.block_rounded
                : Icons.play_circle_outline_rounded,
            label: officer.isActive ? 'Suspend access' : 'Restore access',
            detail: officer.isActive
                ? 'Stops the app ringing for this officer'
                : 'Can receive calls again',
            danger: officer.isActive,
            onTap: _busy
                ? null
                : () => _run(
                    () => ProvisioningService().setActive(
                      officer.uid,
                      !officer.isActive,
                    ),
                    officer.isActive
                        ? '${officer.name} is suspended'
                        : '${officer.name} is active again',
                  ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? AppColors.error : AppColors.forest;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.sage),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: tint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: tint,
                      ),
                    ),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosShortcut extends StatelessWidget {
  const _SosShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.danger,
          side: const BorderSide(color: AppColors.danger),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: const Icon(Icons.notifications_active_outlined, size: 18),
        label: const Text('SOS incidents'),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forest,
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: const Icon(Icons.campaign_rounded, size: 18),
        label: const Text('Contact District Officer'),
      ),
    );
  }
}

class _OfficerAlert {
  const _OfficerAlert({
    required this.officer,
    required this.area,
    required this.incident,
    required this.details,
  });

  final ProvisionedAccount officer;
  final String area;
  final String incident;
  final String details;
}

/// City Hall's "contact the officer" form: who to ring, which area, and why.
///
/// The incident and area become the call reference, so the officer sees the
/// reason on the incoming-call screen and the call history keeps it.
class _ContactOfficerSheet extends StatefulWidget {
  const _ContactOfficerSheet({required this.officers});

  final List<ProvisionedAccount> officers;

  @override
  State<_ContactOfficerSheet> createState() => _ContactOfficerSheetState();
}

class _ContactOfficerSheetState extends State<_ContactOfficerSheet> {
  static const _incidents = [
    'Garbage truck delay',
    'Garbage truck breakdown',
    'Missed collection',
    'Route disruption',
    'Operational problem',
    'Other incident',
  ];

  static const _wholeArea = 'Whole barangay';

  final _details = TextEditingController();
  late ProvisionedAccount _officer;
  String _area = _wholeArea;
  String _incident = _incidents.first;

  @override
  void initState() {
    super.initState();
    _officer = widget.officers.first;
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areas = [_wholeArea, ...ResidentAreas.all];
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Contact District Officer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '${ServiceArea.displayName} · the officer\'s phone rings and '
              'vibrates, even outside this screen.',
              style: TextStyle(
                fontSize: 9,
                height: 1.45,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<ProvisionedAccount>(
              initialValue: _officer,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'District Officer',
                isDense: true,
              ),
              items: [
                for (final officer in widget.officers)
                  DropdownMenuItem(
                    value: officer,
                    child: Text(
                      officer.name,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _officer = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _area,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Affected area',
                isDense: true,
              ),
              items: [
                for (final area in areas)
                  DropdownMenuItem(
                    value: area,
                    child: Text(area, style: const TextStyle(fontSize: 11)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _area = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _incident,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Incident',
                isDense: true,
              ),
              items: [
                for (final incident in _incidents)
                  DropdownMenuItem(
                    value: incident,
                    child: Text(
                      incident,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _incident = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Truck plate, minutes late, what to tell the barangay',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  _OfficerAlert(
                    officer: _officer,
                    area: _area,
                    incident: _incident,
                    details: _details.text.trim(),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                label: const Text('Send alert and ring'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HandoverRow extends StatelessWidget {
  const _HandoverRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.inkMuted,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                tooltip: 'Copy $label',
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 15,
                  color: AppColors.forest,
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text('$label copied'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
