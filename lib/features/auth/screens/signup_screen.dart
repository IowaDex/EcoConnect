import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/account_type.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/service_area.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_payload.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/utils/responsive.dart';
import '../utils/phone.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/password_strength.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';

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
  final _phone = TextEditingController();
  final _birthdateText = TextEditingController();
  final _houseStreet = TextEditingController();

  int _step = 0;
  bool _obscure = true;
  bool _confirmObscure = true;

  DateTime? _birthdate;

  /// A photo of the resident's ID or proof of address. Reviewed by the
  /// barangay desk before the registration is accepted.
  UploadPayload? _idFile;

  @override
  void dispose() {
    for (final c in [
      _email,
      _password,
      _confirmPassword,
      _name,
      _phone,
      _birthdateText,
      _houseStreet,
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

  static int _ageFromBirthdate(DateTime born) {
    final now = DateTime.now();
    var years = now.year - born.year;
    if (now.month < born.month ||
        (now.month == born.month && now.day < born.day)) {
      years--;
    }
    return years;
  }

  static String _formatBirthdate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 18, 1, 1),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: 'Select your birthdate',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthdate = picked;
      _birthdateText.text = _formatBirthdate(picked);
    });
  }

  Future<void> _submit() async {
    if (!_profileKey.currentState!.validate()) return;
    if (_idFile == null) {
      AppFeedback.error(
        context,
        'Upload a photo of your barangay ID or proof of residence.',
      );
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
      profile: {
        if (_birthdate != null) 'birthdate': _birthdate!.toIso8601String(),
        if (_birthdate != null) 'age': _ageFromBirthdate(_birthdate!),
        'phone': Phone.toE164(_phone.text),
        'houseStreet': _houseStreet.text.trim(),
        'barangay': ServiceArea.barangay,
        'city': ServiceArea.city,
        'province': ServiceArea.province,
        'barangayId': _idFile!.toMap(),
      },
    );

    if (!mounted) return;

    if (success) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Check your inbox'),
          content: Text(
            'We sent a verification link to ${_email.text.trim()}. '
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
                      _ => _profileStep(auth),
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
            // Same guard as the login screen: no invisible whitespace.
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Password',
            hint: 'Create a strong password',
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            validator: Validators.validatePasswordStrength,
            suffix: IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 18,
              iconSize: 18,
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.inkMuted,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 10),
          PasswordStrengthChecklist(password: _password.text),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Confirm password',
            hint: 'Re-enter password',
            controller: _confirmPassword,
            obscureText: _confirmObscure,
            textInputAction: TextInputAction.done,
            validator: (v) =>
                Validators.validateConfirmPassword(v, _password.text),
            onFieldSubmitted: (_) => _toProfile(),
            suffix: IconButton(
              padding: EdgeInsets.zero,
              splashRadius: 18,
              iconSize: 18,
              tooltip: _confirmObscure ? 'Show password' : 'Hide password',
              icon: Icon(
                _confirmObscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.inkMuted,
              ),
              onPressed: () =>
                  setState(() => _confirmObscure = !_confirmObscure),
            ),
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
          AppTextField(
            label: 'Birthdate',
            hint: 'Select your birthdate',
            controller: _birthdateText,
            readOnly: true,
            onTap: _pickBirthdate,
            textInputAction: TextInputAction.next,
            suffix: const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: AppColors.inkMuted,
            ),
            validator: (_) {
              if (_birthdate == null) return 'Please select your birthdate';
              final age = _ageFromBirthdate(_birthdate!);
              if (age < 1 || age > 120) return 'Enter a valid birthdate';
              return null;
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
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
          const SizedBox(height: 14),
          const _ServiceAreaCard(),
          const SizedBox(height: 14),
          ImagePickerField(
            value: _idFile,
            onChanged: (value) => setState(() => _idFile = value),
            label: 'Barangay ID or proof of residence',
            helper:
                'JPG or PNG · reviewed once to confirm you live in Batasan Hills',
            documentMode: true,
            previewHeight: 150,
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
            label: 'Create account',
            loading: auth.isLoading,
            onPressed: _submit,
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
}

/// The address is fixed: this deployment only serves one barangay.
class _ServiceAreaCard extends StatelessWidget {
  const _ServiceAreaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ServiceArea.barangay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGreen,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '${ServiceArea.city} · ${ServiceArea.province}',
                  style: TextStyle(fontSize: 9.5, color: AppColors.inkMuted),
                ),
                SizedBox(height: 4),
                Text(
                  'EcoConnect is deployed for this barangay only, so the '
                  'address is set for you.',
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.45,
                    color: AppColors.inkMuted,
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
