import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/account_type.dart';
import '../providers/auth_provider.dart';
import '../services/psgc_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../utils/phone.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';
import '../widgets/psgc_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _credentialsKey = GlobalKey<FormState>();
  final _profileKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  final _houseStreet = TextEditingController();
  final _barangay = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();

  int _step = 0;
  bool _obscure = true;
  UserRole _role = UserRole.user;
  AccountType _accountType = AccountType.resident;
  UploadPayload? _idDocument;
  bool _idError = false;

  bool get _isGovernment => _accountType == AccountType.government;

  PsgcOption? _provinceOption;
  PsgcOption? _cityOption;
  PsgcOption? _barangayOption;

  @override
  void dispose() {
    for (final c in [
      _email,
      _password,
      _confirmPassword,
      _name,
      _age,
      _phone,
      _houseStreet,
      _barangay,
      _city,
      _province,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      // Leaving signup always returns to the landing page, never straight to
      // the login form: the visitor may still want the overview.
      context.go('/welcome');
    } else {
      setState(() => _step--);
    }
  }

  void _toCredentials() => _next();

  void _toProfile() {
    if (!_credentialsKey.currentState!.validate()) return;
    _next();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickProvince() async {
    final picked = await showPsgcPicker(
      context,
      title: 'Select province',
      load: PsgcService.instance.provinces,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _provinceOption = picked;
      _province.text = picked.name;
      _cityOption = null;
      _city.clear();
      _barangayOption = null;
      _barangay.clear();
    });
  }

  Future<void> _pickCity() async {
    final province = _provinceOption;
    if (province == null) {
      _toast('Select your province first');
      return;
    }
    final picked = await showPsgcPicker(
      context,
      title: 'Select city / municipality',
      load: () => PsgcService.instance.cities(province.code),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _cityOption = picked;
      _city.text = picked.name;
      _barangayOption = null;
      _barangay.clear();
    });
  }

  Future<void> _pickBarangay() async {
    final city = _cityOption;
    if (city == null) {
      _toast('Select your city first');
      return;
    }
    final picked = await showPsgcPicker(
      context,
      title: 'Select barangay',
      load: () => PsgcService.instance.barangays(city.code),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _barangayOption = picked;
      _barangay.text = picked.name;
    });
  }

  void _toVerification() {
    if (!_profileKey.currentState!.validate()) return;
    if (_isGovernment) {
      _next();
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    // The profile form is only mounted on step 2. On the ID step it has
    // already been validated by _toVerification.
    if (_step == 2 && !_profileKey.currentState!.validate()) return;
    if (_isGovernment && _idDocument == null) {
      setState(() => _idError = true);
      return;
    }
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      role: _role,
      accountType: _isGovernment
          ? AccountType.government
          : AccountType.resident,
      verificationDocument: _idDocument,
      profile: {
        'age': int.tryParse(_age.text.trim()),
        'phone': Phone.toE164(_phone.text),
        'houseStreet': _houseStreet.text.trim(),
        'barangay': _barangayOption?.name ?? '',
        'city': _cityOption?.name ?? '',
        'province': _provinceOption?.name ?? '',
      },
    );

    if (!mounted) return;

    if (success) {
      final needsApproval = _role != UserRole.user;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(
            needsApproval
                ? 'Account submitted'
                : _isGovernment
                ? 'Verify your email'
                : 'Check your inbox',
          ),
          content: Text(
            needsApproval
                ? 'Your driver account is waiting for approval. Verify your '
                      'email, then sign in once barangay staff approves your '
                      'account.'
                : _isGovernment
                ? 'We sent a verification link to ${_email.text.trim()}. '
                      'Verify your email, then sign in. Your government ID is '
                      'pending barangay staff review — special collection '
                      'requests unlock after approval.'
                : 'We sent a verification link to ${_email.text.trim()}. '
                      'Verify your email within 10 minutes, then log in.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/login');
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(auth.error!),
            backgroundColor: AppColors.danger,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return PopScope(
      // System / browser back on the first step would close the app, so send
      // the visitor back to the landing page instead.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: AppColors.forest,
                      ),
                      onPressed: _back,
                    ),
                    const SizedBox(width: 8),
                    const BrandWordmark(fontSize: 12),
                    const Spacer(),
                    if (_step == 0)
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Log in'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: switch (_step) {
                      0 => _roleStep(),
                      1 => _credentialsStep(auth),
                      2 => _profileStep(auth),
                      _ => _verificationStep(auth),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleStep() {
    const options =
        <({UserRole role, String title, String subtitle, IconData icon})>[
          (
            role: UserRole.user,
            title: 'Resident',
            subtitle: 'Track collection, report issues and earn rewards',
            icon: Icons.home_outlined,
          ),
          (
            role: UserRole.driver,
            title: 'Driver',
            subtitle: 'Run your assigned route and broadcast your location',
            icon: Icons.local_shipping_outlined,
          ),
          // No self-service staff signup: the rules only let a profile be created
          // as user/driver, so staff accounts are promoted to admin by an admin.
        ];

    return Column(
      key: const ValueKey('role'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select your role',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Driver accounts are reviewed by barangay staff before '
          'they can sign in.',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 22),
        for (final option in options) ...[
          _RoleCard(
            title: option.title,
            subtitle: option.subtitle,
            icon: option.icon,
            selected: _role == option.role,
            onTap: () => setState(() => _role = option.role),
          ),
          const SizedBox(height: 12),
        ],
        if (_role == UserRole.user) ...[
          const SizedBox(height: 8),
          const Text(
            'Account type',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AccountTypeCard(
                  type: AccountType.resident,
                  selected: _accountType == AccountType.resident,
                  onTap: () =>
                      setState(() => _accountType = AccountType.resident),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AccountTypeCard(
                  type: AccountType.government,
                  selected: _accountType == AccountType.government,
                  onTap: () =>
                      setState(() => _accountType = AccountType.government),
                ),
              ),
            ],
          ),
          if (_isGovernment) ...[
            const SizedBox(height: 10),
            const Text(
              'Government personnel must upload an official ID after the '
              'profile step. Special collection requests unlock only after '
              'barangay staff verify it.',
              style: TextStyle(
                fontSize: 9,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Continue', onPressed: _toCredentials),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Already have an account?',
              style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Login',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _credentialsStep(AuthProvider auth) {
    return Form(
      key: _credentialsKey,
      child: Column(
        key: const ValueKey('credentials'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign up Account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create an account to start tracking your collection schedule.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 26),
          AppTextField(
            label: 'Name',
            hint: 'Full name',
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (v) => Validators.validateName(v?.trim()),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Email',
            hint: 'you@email.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Password',
            hint: 'Input password',
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            validator: Validators.validatePassword,
            suffix: IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 18,
              iconSize: 18,
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.inkMuted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Confirm password',
            hint: 'Re-enter password',
            controller: _confirmPassword,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            validator: (v) =>
                Validators.validateConfirmPassword(v, _password.text),
            onFieldSubmitted: (_) => _toProfile(),
          ),
          const SizedBox(height: 26),
          PrimaryButton(
            label: 'Sign up',
            loading: auth.isLoading,
            onPressed: _toProfile,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'continue with',
                  style: TextStyle(
                    fontSize: 8.5,
                    letterSpacing: 0.4,
                    color: AppColors.inkMuted.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _social(Icons.g_mobiledata_rounded, const Color(0xFFDB4437)),
              const SizedBox(width: 14),
              _social(Icons.facebook, const Color(0xFF1877F2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileStep(AuthProvider auth) {
    return Form(
      key: _profileKey,
      child: Column(
        key: const ValueKey('profile'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create your\nProfile with us',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Age',
                  hint: 'Age',
                  controller: _age,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1 || n > 120) return 'Invalid age';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppTextField(
                  label: 'Phone number',
                  hint: '09XX XXX XXXX',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: Phone.validate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'House no/Unit/street',
            hint: 'House no/Unit/street',
            controller: _houseStreet,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter your street address'
                : null,
          ),
          const SizedBox(height: 14),
          PsgcField(
            label: 'Province',
            hint: 'Select province',
            controller: _province,
            onTap: _pickProvince,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please select your province'
                : null,
          ),
          const SizedBox(height: 14),
          PsgcField(
            label: 'City',
            hint: _provinceOption == null
                ? 'Select province first'
                : 'Select city / municipality',
            controller: _city,
            enabled: _provinceOption != null,
            onTap: _pickCity,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please select your city'
                : null,
          ),
          const SizedBox(height: 14),
          PsgcField(
            label: 'Barangay',
            hint: _cityOption == null ? 'Select city first' : 'Select barangay',
            controller: _barangay,
            enabled: _cityOption != null,
            onTap: _pickBarangay,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please select your barangay'
                : null,
          ),
          const SizedBox(height: 26),
          PrimaryButton(
            label: _isGovernment ? 'Continue to ID upload' : 'Create account',
            loading: auth.isLoading,
            onPressed: _toVerification,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verificationStep(AuthProvider auth) {
    return Column(
      key: const ValueKey('verification'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Verify your\nGovernment Role',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: AppColors.darkGreen,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Upload a clear photo or PDF of your official government ID. '
          'Barangay staff review it before special collection requests are '
          'enabled for your account.',
          style: TextStyle(
            fontSize: 11,
            height: 1.55,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 20),
        ImagePickerField(
          value: _idDocument,
          documentMode: true,
          label: 'Official government ID',
          helper: 'JPG, PNG or PDF · max 600 KB',
          previewHeight: 200,
          onChanged: (value) => setState(() {
            _idDocument = value;
            if (value != null) _idError = false;
          }),
        ),
        if (_idError) ...[
          const SizedBox(height: 8),
          const Text(
            'Please upload your government ID before submitting.',
            style: TextStyle(fontSize: 10.5, color: AppColors.error),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lightGreen.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your ID is stored separately from your public profile and is '
                  'only visible to you and authorized barangay staff.',
                  style: TextStyle(
                    fontSize: 9.5,
                    height: 1.5,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Submit for verification',
          loading: auth.isLoading,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _step = 2),
          child: const Text('Back to profile'),
        ),
      ],
    );
  }

  Widget _social(IconData icon, Color color) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Social sign-in is coming soon')),
        ),
      customBorder: const CircleBorder(),
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: AppColors.creamBright,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.sage),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final AccountType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGov = type == AccountType.government;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightGreen : AppColors.creamBright,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.sage,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isGov ? Icons.badge_outlined : Icons.home_outlined,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.inkMuted,
                ),
                const Spacer(),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 16,
                  color: selected ? AppColors.primary : AppColors.sage,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isGov ? 'Government personnel' : 'Regular resident',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isGov ? 'Requires ID verification' : 'Standard household account',
              style: const TextStyle(
                fontSize: 8.5,
                height: 1.4,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.mint : AppColors.creamBright,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.sage,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: selected ? AppColors.forest : AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : AppColors.forest,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9.5,
                      height: 1.4,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? AppColors.forest : AppColors.sage,
            ),
          ],
        ),
      ),
    );
  }
}
