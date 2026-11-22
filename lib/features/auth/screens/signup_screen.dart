import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/account_type.dart';
import '../providers/auth_provider.dart';
import '../../../core/constants/service_area.dart';
import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/constants/resident_areas.dart';
import '../utils/phone.dart';
import '../utils/type_only_formatter.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/area_field.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/auth_type.dart';
import '../widgets/password_strength.dart';
import '../widgets/social_button.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/image_picker_field.dart';
import '../../../core/utils/image_payload.dart';

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
  final _birthdateText = TextEditingController();
  final _phone = TextEditingController();
  final _areaText = TextEditingController();
  final _areaOther = TextEditingController();
  final _houseStreet = TextEditingController();

  int _step = 0;

  /// +1 when moving forward, -1 when moving back. The step transition slides
  /// in from the side the visitor is travelling towards.
  int _direction = 1;

  final _scroll = ScrollController();

  bool _obscure = true;
  bool _confirmObscure = true;

  DateTime? _birthdate;

  /// The subdivision / area / sitio picked from the list, before the "Other"
  /// free-text fallback is applied.
  String? _area;

  /// The resident's valid ID, checked by the barangay before they can sign in.
  UploadPayload? _idDocument;

  @override
  void dispose() {
    for (final c in [
      _email,
      _password,
      _confirmPassword,
      _name,
      _birthdateText,
      _phone,
      _areaText,
      _areaOther,
      _houseStreet,
    ]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    setState(() {
      _direction = 1;
      _step++;
    });
    _scrollToTop();
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      // Leaving signup always returns to the landing page, never straight to
      // the login form: the visitor may still want the overview.
      context.go('/welcome');
      return;
    }
    setState(() {
      _direction = -1;
      _step--;
    });
    _scrollToTop();
  }

  /// A new step starts at its own top. Without this, going back from the
  /// bottom of the profile step lands the visitor halfway down the first one.
  void _scrollToTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toProfile() {
    if (!_credentialsKey.currentState!.validate()) return;
    _next();
  }

  void _submitFromProfile() {
    if (!_profileKey.currentState!.validate()) return;
    _submit();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _pickArea() async {
    final picked = await showAreaPicker(context, selected: _area);
    if (picked == null || !mounted) return;
    setState(() {
      _area = picked;
      _areaText.text = picked;
      // Switching away from "Other" drops the typed area so it is not saved
      // by mistake.
      if (!ResidentAreas.isOther(picked)) _areaOther.clear();
    });
  }

  /// The area as it is stored: the picked option, or the typed one when the
  /// resident chose "Other / Not Listed".
  String get _resolvedArea => ResidentAreas.isOther(_area)
      ? _areaOther.text.trim()
      : (_area ?? '');

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
      accountType: AccountType.resident,
      verificationDocument: _idDocument,
      profile: {
        if (_birthdate != null) 'birthdate': _birthdate!.toIso8601String(),
        if (_birthdate != null) 'age': _ageFromBirthdate(_birthdate!),
        'phone': Phone.toE164(_phone.text),
        'subdivision': _resolvedArea,
        'houseStreet': _houseStreet.text.trim(),
        'barangay': ServiceArea.barangay,
        'city': ServiceArea.city,
        'province': ServiceArea.province,
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
    final metrics = ScreenMetrics.of(context);
    final gutter = formGutter(metrics.size.width);

    // A band, not a hero: the two steps are long forms, so the artwork gets a
    // strip that carries the brand and gives the fields the rest of the page.
    final bandHeight = (metrics.size.height * 0.23).clamp(150.0, 215.0);

    return PopScope(
      // System / browser back on the first step would close the app, so send
      // the visitor back to the landing page instead.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.creamBright,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: bandHeight,
              child: _SignupBand(
                topInset: metrics.padding.top + 8,
                onBack: _back,
              ),
            ),
            Positioned.fill(
              top: bandHeight - 24,
              child: AuthSheet(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    22,
                    gutter,
                    28 + metrics.padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StepBar(step: _step),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final slide = Tween<Offset>(
                            begin: Offset(0.06 * _direction, 0),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: slide,
                              child: child,
                            ),
                          );
                        },
                        // The two steps are both plain Forms, so without a key
                        // of their own the switcher would update in place
                        // instead of sliding one out and the next in.
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            0 => _credentialsStep(auth),
                            _ => _profileStep(auth),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
          const AuthHeading(
            eyebrow: 'NEW RESIDENT',
            title: 'Create your account',
            subtitle:
                'Start tracking your collection schedule with Barangay '
                'Batasan Hills.',
          ),
          const SizedBox(height: 24),
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
            // The password cannot be selected or copied out, so the
            // confirmation below can only be typed by hand.
            enableInteractiveSelection: false,
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
            // No copy, no paste, no autofill: the resident has to type the
            // password a second time, so a typo in the first field cannot be
            // duplicated by pasting it back in.
            enableInteractiveSelection: false,
            inputFormatters: const [TypeOnlyFormatter()],
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
          AuthAltAction(
            prompt: 'Already have an account?',
            action: 'Log in',
            onTap: () => context.go('/login'),
          ),
          const SizedBox(height: 20),
          const AuthOrDivider(),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SocialSignInButton(
                mark: GoogleMark(),
                tooltip: 'Continue with Google',
              ),
              SizedBox(width: 14),
              SocialSignInButton(
                mark: Icon(
                  Icons.facebook,
                  size: 19,
                  color: Color(0xFF1877F2),
                ),
                tooltip: 'Continue with Facebook',
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
          const AuthHeading(
            eyebrow: 'RESIDENT PROFILE',
            title: 'Where do we collect?',
            subtitle:
                'The barangay uses this to match you to the right collection '
                'route.',
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            icon: Icons.person_outline_rounded,
            label: 'PERSONAL DETAILS',
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          const _SectionHeader(
            icon: Icons.home_outlined,
            label: 'HOME ADDRESS',
          ),
          const SizedBox(height: 12),
          const _ServiceAreaCard(),
          const SizedBox(height: 14),
          AreaField(
            label: 'Subdivision / Area / Sitio',
            hint: 'Select your subdivision, area or sitio',
            controller: _areaText,
            onTap: _pickArea,
            validator: (_) =>
                _area == null ? 'Please select your area' : null,
          ),
          // "Other / Not Listed" is the only option that needs typing, so the
          // extra field appears only when it is picked.
          if (ResidentAreas.isOther(_area)) ...[
            const SizedBox(height: 14),
            AppTextField(
              label: 'Specify your area',
              hint: 'Subdivision, area or sitio',
              controller: _areaOther,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter your area'
                  : null,
            ),
          ],
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
          const SizedBox(height: 24),
          const _SectionHeader(
            icon: Icons.badge_outlined,
            label: 'VERIFY YOUR IDENTITY',
          ),
          const SizedBox(height: 10),
          const Text(
            'Barangay Batasan Hills checks your ID before activating your '
            'account. Take or choose a clear photo of a government-issued ID '
            'that shows your name and address.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: 12),
          ImagePickerField(
            key: const ValueKey('id-upload'),
            label: 'Valid ID',
            helper: 'Photo or PDF · only you and barangay staff can see it',
            documentMode: true,
            previewHeight: 150,
            value: _idDocument,
            onChanged: (value) => setState(() => _idDocument = value),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Create account',
            loading: auth.isLoading,
            onPressed: _submitFromProfile,
          ),
          const SizedBox(height: 10),
          const Text(
            'Next, we email you a link to confirm your address.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 12),
          AuthAltAction(
            prompt: 'Already have an account?',
            action: 'Log in',
            onTap: () => context.go('/login'),
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

/// The branded strip above the form: scene, wordmark and the step the visitor
/// is on. Shorter than the login hero because both sign-up steps are long
/// forms and the fields need the page.
class _SignupBand extends StatelessWidget {
  const _SignupBand({required this.topInset, required this.onBack});

  final double topInset;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const AuthScene(),
        // A pale wash over the top half only: the brand row needs a clean
        // field, the road and the truck below it are the point of the strip.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.55],
                colors: [Color(0xF2EAF5EA), Color(0x00EAF5EA)],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, topInset, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AuthBackButton(onTap: onBack),
                  const SizedBox(width: 12),
                  // Expanded, not Flexible: the row divides evenly, so the pill
                  // lands exactly on the right margin.
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BrandLockup(fontSize: 20, letterSpacing: 1.2),
                    ),
                  ),
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AuthAreaPill(compact: true),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two segments that fill in as the visitor advances, with the count spelled
/// out beside them so the visitor knows how much is left.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: EcoMotion.base,
              curve: EcoMotion.enter,
              height: 4,
              decoration: BoxDecoration(
                color: i <= step
                    ? AppColors.primary
                    : AppColors.sage.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Text(
          'STEP ${step + 1} OF 2',
          style: authSans(
            size: 8.5,
            weight: FontWeight.w800,
            letterSpacing: 1.1,
            color: AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// A titled rule that opens a group of fields, e.g. `HOME ADDRESS`.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 26,
          width: 26,
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.6)),
          ),
          child: Icon(icon, size: 15, color: AppColors.primary),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: authSans(
            size: 9.5,
            weight: FontWeight.w800,
            letterSpacing: 1.2,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider()),
      ],
    );
  }
}
