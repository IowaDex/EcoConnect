import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/account_type.dart';
import '../providers/auth_provider.dart';
import '../services/psgc_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../utils/phone.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/utils/image_payload.dart';
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

  PsgcOption? _provinceOption;
  PsgcOption? _cityOption;
  PsgcOption? _barangayOption;

  /// The resident's valid ID, checked by the barangay before they can sign in.
  UploadPayload? _idDocument;

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

  void _toProfile() {
    if (!_credentialsKey.currentState!.validate()) return;
    _next();
  }

  void _toId() {
    if (!_profileKey.currentState!.validate()) return;
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

  Future<void> _submit() async {
    if (_idDocument == null) {
      _toast('Please upload a valid ID first');
      return;
    }
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      name: _name.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      role: UserRole.user,
      accountType: AccountType.resident,
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
      // Still signed in: the next step confirms the emailed link.
      context.go('/verify-email');
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
    final gutter = formGutter(MediaQuery.sizeOf(context).width);

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
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: switch (_step) {
                      0 => _credentialsStep(auth),
                      1 => _profileStep(auth),
                      _ => _idStep(auth),
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
            label: 'Next',
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

  Widget _idStep(AuthProvider auth) {
    return Column(
      key: const ValueKey('id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Upload your\nvalid ID',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Barangay Batasan Hills checks your ID before your account is '
          'activated. Take or choose a clear photo of a government-issued ID '
          'that shows your name and address.',
          style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 18),
        ImagePickerField(
          key: const ValueKey('id-upload'),
          label: 'Valid ID',
          helper: 'Photo · only you and barangay staff can see it',
          value: _idDocument,
          onChanged: (value) => setState(() => _idDocument = value),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Create account',
          loading: auth.isLoading,
          onPressed: _submit,
        ),
        const SizedBox(height: 10),
        const Text(
          'Next, we email you a link to confirm your address.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
        ),
      ],
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
          const SizedBox(height: 14),
          AppTextField(
            label: 'House no/Unit/street',
            hint: 'House no/Unit/street',
            controller: _houseStreet,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter your street address'
                : null,
          ),
          const SizedBox(height: 26),
          PrimaryButton(
            label: 'Next',
            onPressed: _toId,
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
