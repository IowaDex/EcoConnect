import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/desk_ui.dart';
import '../../../core/widgets/eco_page.dart';
import '../../../core/widgets/eco_skeleton.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/utils/paging.dart';
import '../../../core/widgets/eco_pagination.dart';
import '../../driver/models/truck_crew_role.dart';
import '../providers/auth_provider.dart';
import '../services/provisioning_service.dart';
import '../utils/validators.dart';
import '../widgets/password_strength.dart';

/// The state tabs above the account list.
///
/// The desk only ever lists one kind of account — Iswim's crew, or the
/// barangay's guides — so the tabs filter by state, not by role. Role tabs
/// would have been three permanently empty tabs.
enum _StatusFilter { all, active, suspended }

extension on _StatusFilter {
  String get label => switch (this) {
    _StatusFilter.all => 'All',
    _StatusFilter.active => 'Active',
    _StatusFilter.suspended => 'Suspended',
  };

  bool matches(ProvisionedAccount account) => switch (this) {
    _StatusFilter.all => true,
    _StatusFilter.active => account.isActive,
    _StatusFilter.suspended => !account.isActive,
  };
}

/// The account desk. Two roles reach it and each sees only its own people:
/// Iswim makes the driver logins, the barangay makes its truck guides.
/// Neither may touch an Iswim, City Hall or barangay account.
///
/// Nobody signs themselves up for a crew account. This desk hands out
/// credentials and nothing else — the plate is assigned later, in the
/// collection manual Iswim writes, so a brand-new driver holds no truck.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final _search = TextEditingController();
  String _query = '';
  _StatusFilter _filter = _StatusFilter.all;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = '';
      _filter = _StatusFilter.all;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final scope = accountScopeFor(me?.role);
    final drivers = scope == AccountScope.drivers;

    return EcoPageScaffold(
      eyebrow: drivers ? 'ISWIM · ACCOUNTS' : 'BARANGAY · TRUCK GUIDES',
      title: drivers ? 'Driver accounts' : 'Truck guides',
      subtitle: drivers
          ? 'Driver logins are created here. Guides belong to the barangay; '
                'Iswim, City Hall and barangay accounts are not managed from '
                'this desk.'
          : 'Your truck guide logins are created here. Iswim, City Hall and '
                'barangay accounts are not managed from this desk.',
      icon: Icons.badge_outlined,
      onBack: () => ecoBack(context, drivers ? '/iswim' : '/admin-dashboard'),
      // An icon action, not a floating button: the FAB sat on top of the
      // pagination bar once the list grew past one page.
      actions: [
        if (scope.canProvision)
          EcoIconAction(
            icon: Icons.person_add_alt_1_rounded,
            tooltip: drivers
                ? 'Create a driver account'
                : 'Create a truck guide account',
            onTap: () => _openForm(context, scope),
          ),
      ],
      body: StreamBuilder<List<ProvisionedAccount>>(
        stream: ProvisioningService().watchAccounts(scope),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SkeletonCardList(count: 4, leading: true, gap: 8),
            );
          }
          if (snapshot.hasError) {
            return DeskEmptyQueue(
              icon: Icons.cloud_off_rounded,
              title: 'Accounts are not loading',
              message: '${snapshot.error}',
            );
          }

          final all = snapshot.data ?? const <ProvisionedAccount>[];
          final query = _query.trim().toLowerCase();
          final accounts = all
              .where((account) {
                if (!_filter.matches(account)) return false;
                if (query.isEmpty) return true;
                return account.name.toLowerCase().contains(query) ||
                    account.email.toLowerCase().contains(query);
              })
              .toList(growable: false);
          final page = clampPage(_page, accounts.length, _pageSize);
          final visible = pageSlice(accounts, page, _pageSize);

          // The desk only counts logins. A driver holds no plate until a
          // collection manual puts him on one, so "no truck" is not a fault
          // here and does not belong in the numbers.
          final suspended = all.where((a) => !a.isActive).length;

          return DeskQueueView(
            metrics: [
              DeskMetric(
                icon: drivers
                    ? Icons.local_shipping_outlined
                    : Icons.person_pin_circle_outlined,
                label: drivers ? 'Drivers' : 'Guides',
                value: '${all.length}',
                accent: AppColors.primary,
              ),
              DeskMetric(
                icon: Icons.pause_circle_outlined,
                label: 'Suspended',
                value: '$suspended',
                accent: AppColors.warning,
                highlight: suspended > 0,
              ),
            ],
            search: EcoSearchField(
              controller: _search,
              hint: 'Search name or email',
              onChanged: (value) => setState(() {
                _query = value;
                _page = 0;
              }),
            ),
            filters: DeskSegmented<_StatusFilter>(
              value: _filter,
              onChanged: (next) => setState(() {
                _filter = next;
                _page = 0;
              }),
              segments: [
                for (final filter in _StatusFilter.values)
                  DeskSegment<_StatusFilter>(
                    value: filter,
                    label: filter.label,
                  ),
              ],
            ),
            resultLine: DeskResultLine(
              label: accounts.isEmpty
                  ? 'No accounts match'
                  : '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
              onClear: _query.isNotEmpty || _filter != _StatusFilter.all
                  ? _clear
                  : null,
            ),
            empty: DeskEmptyQueue(
              icon: all.isEmpty
                  ? Icons.badge_outlined
                  : Icons.search_off_rounded,
              title: all.isEmpty ? 'No accounts yet' : 'No accounts match',
              message: all.isEmpty
                  ? drivers
                        ? 'Create the first driver login with the button in the '
                              'header. A driver cannot sign in until his '
                              'account exists.'
                        : 'Create the first guide login with the button in the '
                              'header. A guide cannot sign in until his '
                              'account exists.'
                  : 'Try another word, or clear the filter.',
              actionLabel: all.isEmpty ? 'Create an account' : 'Clear filters',
              actionIcon: all.isEmpty
                  ? Icons.person_add_alt_1_rounded
                  : Icons.filter_alt_off_outlined,
              onAction: all.isEmpty ? () => _openForm(context, scope) : _clear,
            ),
            itemCount: visible.length,
            itemBuilder: (context, i) => _AccountTile(
              account: visible[i],
              canManage: scope.canProvision,
              onTap: () => _openActions(context, visible[i]),
            ),
            pagination: EcoPaginationBar(
              page: page,
              pageSize: _pageSize,
              total: accounts.length,
              onPageChanged: (value) => setState(() => _page = value),
              onPageSizeChanged: (value) => setState(() {
                _pageSize = value;
                _page = 0;
              }),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, AccountScope scope) async {
    final handover = await showModalBottomSheet<_Handover>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountForm(scope: scope),
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
        title: Text(
          'Account created',
          style: EcoType.panelTitle(dialogContext, color: AppColors.forest),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Show this to the crew now — it cannot be shown again. '
              'Once they sign in, they can change it in their profile.',
              style: EcoType.bodySmall(
                dialogContext,
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: EcoSpace.sm),
            _HandoverRow(label: 'Email', value: handover.email),
            const SizedBox(height: EcoSpace.xs),
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

  Future<void> _openActions(BuildContext context, ProvisionedAccount account) {
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
    // The role is always "driver" — a guide is a driver profile with a
    // crewRole — so the crew role is what names the person, and repeating
    // "Driver · Truck Driver" would just stutter.
    final subtitle = [
      account.crewRole?.label ?? account.role.label,
      account.email,
    ].join(' · ');
    // A fresh driver has no plate yet — the manual assigns it — so the only
    // state worth flagging on this desk is a suspended login.
    return DeskRailCard(
      railColor: account.isActive ? AppColors.primary : AppColors.error,
      onTap: canManage ? onTap : null,
      child: Row(
        children: [
          DeskInitialAvatar(name: account.name, size: 34),
          const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.cardTitle(
                    context,
                    color: AppColors.forest,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          if (!account.isActive)
            const _StatePill(label: 'suspended', color: AppColors.error),
          if (canManage)
            const Padding(
              padding: EdgeInsets.only(left: EcoSpace.xxs),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.moss,
              ),
            ),
        ],
      ),
    );
  }
}

/// The one-word state on an account row: suspended, or no plate yet.
class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EcoRadius.pill),
      ),
      child: Text(
        label,
        style: EcoType.meta(
          context,
          color: color,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(
        EcoSpace.lg,
        EcoSpace.sm,
        EcoSpace.lg,
        EcoSpace.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The theme's bottomSheetTheme already draws the drag handle.
          Text(
            account.crewRole?.label.toUpperCase() ?? 'ACCOUNT',
            style: EcoType.eyebrow(context, color: AppColors.primary),
          ),
          const SizedBox(height: EcoSpace.xxs),
          Text(
            account.name,
            style: EcoType.panelTitle(context, color: AppColors.forest),
          ),
          const SizedBox(height: EcoSpace.xxs),
          Text(
            account.email,
            style: EcoType.meta(context, color: AppColors.inkMuted),
          ),
          const SizedBox(height: EcoSpace.lg),
          _Action(
            icon: Icons.lock_reset_rounded,
            label: 'Send a password reset',
            detail: 'Firebase emails the link',
            onTap: _busy
                ? null
                : () => _run(
                    () => ProvisioningService().resetPassword(account.email),
                    'Reset email sent to ${account.email}',
                  ),
          ),
          const SizedBox(height: EcoSpace.xs),
          _Action(
            icon: account.isActive
                ? Icons.block_rounded
                : Icons.play_circle_outline_rounded,
            label: account.isActive ? 'Suspend access' : 'Restore access',
            detail: account.isActive
                ? 'Can no longer sign in'
                : 'Can sign in again',
            danger: account.isActive,
            onTap: _busy
                ? null
                : () => _run(
                    () => ProvisioningService().setActive(
                      account.uid,
                      !account.isActive,
                    ),
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
    final tint = danger ? AppColors.error : AppColors.primary;
    return DeskRailCard(
      railColor: tint,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: EcoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: EcoType.cardTitle(
                    context,
                    color: danger ? AppColors.error : AppColors.forest,
                    weight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  style: EcoType.meta(context, color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 17,
            color: AppColors.moss,
          ),
        ],
      ),
    );
  }
}

/// The form the desk fills in. It makes exactly one kind of login — the one
/// its [AccountScope] owns — because Iswim, City Hall and the barangay are
/// separate accounts that already exist.
class _AccountForm extends StatefulWidget {
  const _AccountForm({required this.scope});

  final AccountScope scope;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;

  /// The desk's one kind of login. Never null: the sheet only opens when the
  /// scope can provision.
  TruckCrewRole get _kind => widget.scope.kind ?? TruckCrewRole.driver;
  bool get _isGuide => _kind == TruckCrewRole.guide;

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
          crewRole: _kind,
          phone: _phone.text,
        ),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(_Handover(email: _email.text.trim(), password: _password.text));
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
    return Container(
      padding: EdgeInsets.only(
        left: EcoSpace.lg,
        right: EcoSpace.lg,
        top: EcoSpace.sm,
        bottom: EcoSpace.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.creamBright,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcoRadius.xl)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The theme's bottomSheetTheme already draws the drag handle.
              Text(
                _isGuide ? 'NEW TRUCK GUIDE' : 'NEW DRIVER',
                style: EcoType.eyebrow(context, color: AppColors.primary),
              ),
              const SizedBox(height: EcoSpace.xxs),
              Text(
                _isGuide ? 'Create a guide login' : 'Create a driver login',
                style: EcoType.panelTitle(context, color: AppColors.forest),
              ),
              const SizedBox(height: EcoSpace.xs),
              Text(
                'Iswim, City Hall and barangay accounts are never created '
                'here.',
                style: EcoType.bodySmall(context, color: AppColors.inkMuted),
              ),
              const SizedBox(height: EcoSpace.lg),
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
              const SizedBox(height: EcoSpace.sm),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'ramon.ecoconnect@gmail.com',
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
              const SizedBox(height: EcoSpace.sm),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: EcoSpace.sm),
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
                        tooltip: 'Copy password',
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _password.text),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Password copied'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                        },
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
              const SizedBox(height: EcoSpace.xs),
              PasswordStrengthChecklist(password: _password.text),
              const SizedBox(height: EcoSpace.lg),
              _FormNote(
                icon: Icons.assignment_outlined,
                text: _isGuide
                    ? 'No truck is chosen here. The guide joins a crew in the '
                          'collection manual.'
                    : 'No truck is chosen here. The driver gets his plate from '
                          'the collection manual Iswim writes.',
              ),
              const SizedBox(height: EcoSpace.lg),
              PrimaryButton(
                label: 'Create ${_isGuide ? 'guide' : 'driver'} account',
                loading: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet line that answers the question the missing field would raise.
class _FormNote extends StatelessWidget {
  const _FormNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(EcoSpace.sm),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: EcoSpace.xs),
          Expanded(
            child: Text(
              text,
              style: EcoType.bodySmall(context, color: AppColors.forest),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: EcoSpace.sm,
        vertical: EcoSpace.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(EcoRadius.md),
        border: Border.all(color: AppColors.sage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: EcoType.eyebrow(context, color: AppColors.inkMuted),
          ),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: EcoType.identifier(context, color: AppColors.forest),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
