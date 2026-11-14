import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../driver/models/garbage_truck.dart';
import '../../driver/models/truck_crew_role.dart';
import '../../fleet/services/fleet_service.dart';
import '../providers/auth_provider.dart';
import '../services/provisioning_service.dart';

/// City Hall's account desk.
///
/// Nobody signs themselves up for a government account: City Hall creates the
/// login, the barangay gets the copy, and the crew receives an email and a
/// password to type once. A truck is never left without a driver, so a driver
/// account must be tied to a plate before it can be saved.
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final isSuperAdmin = me?.role == UserRole.cityHall;

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      appBar: AppBar(
        backgroundColor: AppColors.creamBright,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.forest),
          onPressed: () => context.canPop() ? context.pop() : context.go('/cityhall'),
        ),
        title: const Text(
          'Accounts',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.forest,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text(
          'Driver',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<List<ProvisionedAccount>>(
        stream: ProvisioningService().watchAccounts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              text: 'Could not load the list.\n${snapshot.error}',
            );
          }
          final accounts = snapshot.data ?? const <ProvisionedAccount>[];
          if (accounts.isEmpty) {
            return const _Message(
              text: 'No crew accounts yet. Tap "Driver" to create the first one.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
            children: [
              Text(
                '${accounts.length} accounts · only drivers and guides are '
                'created here, not self-signup',
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              for (final account in accounts) ...[
                _AccountTile(
                  account: account,
                  canManage: isSuperAdmin,
                  onTap: () => _openActions(context, account),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final handover = await showModalBottomSheet<_Handover>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AccountForm(),
    );
    if (handover == null || !context.mounted) return;
    await _showHandover(context, handover);
  }

  /// The password is shown once: Firebase keeps only a hash, so this dialog is
  /// the only chance to write it down.
  Future<void> _showHandover(BuildContext context, _Handover handover) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.creamBright,
        title: const Text(
          'Account created',
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
              'Show this to the crew now — it cannot be shown again. '
              'Once they sign in, they can change it in their profile.',
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
    ProvisionedAccount account,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionsSheet(account: account),
    );
  }
}

/// The email and password to hand over. Lives only in memory: the sheet pops
/// with it, the caller shows it once, and it is gone.
class _Handover {
  const _Handover({required this.email, required this.password});

  final String email;
  final String password;
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10.5,
          height: 1.6,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.canManage,
    required this.onTap,
  });

  final ProvisionedAccount account;
  final bool canManage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crew = account.crewRole?.label;
    final subtitle = [
      account.role.label,
      if (crew != null) crew,
      account.email,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canManage ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sage),
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: const BoxDecoration(
                  color: AppColors.cream,
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(account.role),
                    size: 17, color: AppColors.forest),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forest,
                      ),
                    ),
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
              if (!account.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'suspended',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                )
              else if (account.role == UserRole.driver &&
                  (account.truckId == null || account.truckId!.isEmpty))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'no truck',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              if (canManage)
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.moss),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(UserRole role) => switch (role) {
        UserRole.cityHall => Icons.account_balance_rounded,
        UserRole.iswim => Icons.business_center_rounded,
        UserRole.admin => Icons.shield_outlined,
        UserRole.driver => Icons.local_shipping_rounded,
        UserRole.user => Icons.person_outline_rounded,
      };
}

/// Reset the password, or freeze the login.
class _ActionsSheet extends StatefulWidget {
  const _ActionsSheet({required this.account});

  final ProvisionedAccount account;

  @override
  State<_ActionsSheet> createState() => _ActionsSheetState();
}

class _ActionsSheetState extends State<_ActionsSheet> {
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
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
            account.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
          Text(
            account.email,
            style: const TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 16),
          _Action(
            icon: Icons.lock_reset_rounded,
            label: 'Send a password reset',
            detail: 'Email from Firebase',
            onTap: _busy
                ? null
                : () => _run(
                      () => ProvisioningService().resetPassword(account.email),
                      'Reset email sent to ${account.email}',
                    ),
          ),
          const SizedBox(height: 8),
          _Action(
            icon: account.isActive
                ? Icons.block_rounded
                : Icons.play_circle_outline_rounded,
            label: account.isActive
                ? 'Suspend access'
                : 'Restore access',
            detail: account.isActive
                ? 'Can no longer sign in'
                : 'Can sign in again',
            danger: account.isActive,
            onTap: _busy
                ? null
                : () => _run(
                      () => ProvisioningService()
                          .setActive(account.uid, !account.isActive),
                      account.isActive
                          ? '${account.name} is now suspended'
                          : '${account.name} is active again',
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

/// The form the desk fills in. It only makes **crew** accounts: Iswim and City
/// Hall are separate accounts that already exist, so a driver and his truck is
/// the only thing left to provision.
class _AccountForm extends StatefulWidget {
  const _AccountForm();

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  TruckCrewRole _crewRole = TruckCrewRole.driver;
  GarbageTruck? _truck;
  bool _busy = false;
  List<GarbageTruck> _trucks = const [];

  @override
  void initState() {
    super.initState();
    _password.text = _suggestPassword();
    FleetService().watchTrucks().first.then((trucks) {
      if (!mounted) return;
      setState(() {
        _trucks = trucks;
        // A plate without a login is the one that needs this account.
        _truck = trucks.cast<GarbageTruck?>().firstWhere(
              (t) => t?.driverAccountId == null || t?.driverAccountId == '',
              orElse: () => trucks.isEmpty ? null : trucks.first,
            );
      });
    }).catchError((Object _) {
      // Offline: the form still opens, the truck list just stays empty and
      // the dropdown validator asks for one.
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  /// `Eco-` plus six digits: easy to read aloud on a phone call, still not a
  /// word anybody guesses.
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
          role: UserRole.driver,
          crewRole: _crewRole,
          truckId: _truck?.id,
          phone: _phone.text,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        _Handover(email: _email.text.trim(), password: _password.text),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error,
          ),
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
                'New driver account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Only Driver and Truck Guide accounts are created here. Iswim and '
                'City Hall are separate accounts and do not need to be '
                'created again.',
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
                  hintText: 'ramon@ecoconnect.test',
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
              TextFormField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Password',
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'New password',
                    icon: const Icon(Icons.casino_outlined, size: 17),
                    onPressed: () =>
                        setState(() => _password.text = _suggestPassword()),
                  ),
                ),
                validator: (value) => (value ?? '').length < 6
                    ? 'Use at least 6 characters'
                    : null,
              ),
              // Always a crew account, so the plate is always required.
              ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  children: [
                    for (final crew in TruckCrewRole.values)
                      ChoiceChip(
                        label: Text(crew.label),
                        selected: _crewRole == crew,
                        onSelected: (_) => setState(() => _crewRole = crew),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<GarbageTruck>(
                  initialValue: _truck,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assigned truck',
                    isDense: true,
                  ),
                  items: [
                    for (final truck in _trucks)
                      DropdownMenuItem(
                        value: truck,
                        child: Text(
                          '${truck.plateNumber} · ${truck.wheelerLabel}'
                          '${truck.driverAccountId == null ? ' · no login' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _truck = value),
                  validator: (value) =>
                      value == null ? 'Select a truck' : null,
                ),
                const SizedBox(height: 6),
                const Text(
                  'This truck opens first on their dashboard when they sign in.',
                  style: TextStyle(fontSize: 8.5, color: AppColors.inkMuted),
                ),
              ],
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
                      : const Text('Create driver account'),
                ),
              ),
            ],
          ),
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
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}
