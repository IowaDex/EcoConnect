import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/auth_type.dart';
import '../widgets/social_button.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/primary_button.dart';

/// Above this window width the page splits into an illustration pane and a
/// form pane instead of stacking the two. Chosen so a small laptop or a
/// tablet in landscape gets the desktop composition, not a stretched phone.
const double _splitBreakpoint = 900;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  DateTime? _lastResendAttempt;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // /welcome is a public route; the router redirect immediately resolves
      // the role home from the restored session, the same path sign-up uses.
      context.go('/welcome');
    } else if (authProvider.loginErrorType ==
        AuthErrorType.needsEmailVerification) {
      // Signed up but has not confirmed their email: finish it now.
      context.go('/verify-email');
    } else if (authProvider.loginErrorType == AuthErrorType.emailNotVerified) {
      _showUnverifiedDialog(_emailController.text.trim());
    } else if (authProvider.error != null) {
      _snack(authProvider.error!, isError: true);
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.danger : AppColors.forest,
        ),
      );
  }

  void _showUnverifiedDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email not verified'),
        content: const Text(
          'Your email is not verified yet. Check your inbox and tap the '
          'verification link before logging in.\n\nVerification links expire '
          'after 10 minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (_lastResendAttempt != null) {
                final elapsed = DateTime.now().difference(_lastResendAttempt!);
                if (elapsed.inMinutes < 10) {
                  final remaining = 10 - elapsed.inMinutes;
                  Navigator.of(ctx).pop();
                  _snack(
                    'Please wait $remaining more minute(s) before resending.',
                  );
                  return;
                }
              }
              Navigator.of(ctx).pop();
              try {
                await context.read<AuthProvider>().resendVerificationEmail(
                  email,
                  _passwordController.text,
                );
                _lastResendAttempt = DateTime.now();
                if (!mounted) return;
                _snack('Verification email sent! It expires in 10 minutes.');
              } catch (e) {
                if (!mounted) return;
                _snack(
                  'Failed to resend: ${e.toString().replaceFirst('Exception: ', '')}',
                  isError: true,
                );
              }
            },
            child: const Text('Resend email'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final metrics = ScreenMetrics.of(context);
    final wide = metrics.size.width >= _splitBreakpoint;
    final form = _buildForm(auth);

    return Scaffold(
      backgroundColor: AppColors.creamBright,
      body: wide
          ? _WideLayout(form: form, metrics: metrics)
          : _StackedLayout(form: form, metrics: metrics),
    );
  }

  /// The form itself, with no page chrome around it — the two layouts place
  /// the same tree differently. Every block enters on its own beat, top to
  /// bottom, so the screen assembles instead of appearing all at once.
  Widget _buildForm(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FadeSlideIn(
              index: 0,
              offset: 10,
              child: AuthHeading(
                eyebrow: 'ACCOUNT ACCESS',
                title: 'Welcome back',
                subtitle:
                    'Log in to follow the collection truck and keep your '
                    'barangay requests in one place.',
              ),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              index: 1,
              child: AppTextField(
                label: 'Email',
                hint: 'you@email.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                // A pasted address often carries a trailing space, which reads
                // as "invalid email" with no visible reason. Drop whitespace as
                // it is typed.
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: Validators.validateEmail,
                autofillHints: const [AutofillHints.email],
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 2,
              child: AppTextField(
                label: 'Password',
                hint: 'Input password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                validator: Validators.validatePassword,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _handleLogin(),
                suffix: IconButton(
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  iconSize: 18,
                  tooltip: _obscurePassword
                      ? 'Show password'
                      : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.inkMuted,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            FadeSlideIn(
              index: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/forgot-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: authSans(size: 11.5, weight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              index: 4,
              child: PrimaryButton(
                label: 'Log in',
                height: 54,
                loading: auth.isLoading,
                onPressed: _handleLogin,
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 5,
              child: AuthAltAction(
                prompt: 'New to EcoConnect?',
                action: 'Create an account',
                onTap: () => context.go('/signup'),
              ),
            ),
            const SizedBox(height: 22),
            const FadeSlideIn(index: 6, child: AuthOrDivider()),
            const SizedBox(height: 14),
            const FadeSlideIn(
              index: 7,
              child: SocialWideButton(
                mark: GoogleMark(size: 20),
                label: 'Continue with Google',
                tooltip: 'Continue with Google',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Layouts
// -----------------------------------------------------------------------------

/// Phone and portrait-tablet composition: the scene across the top, the form
/// on a sheet that rides 28px over the bottom of it.
class _StackedLayout extends StatelessWidget {
  const _StackedLayout({required this.form, required this.metrics});

  final Widget form;
  final ScreenMetrics metrics;

  /// How far the sheet overlaps the artwork, so its rounded corners sit on the
  /// scene instead of on a flat band of colour.
  static const double _sheetOverlap = 28;

  @override
  Widget build(BuildContext context) {
    final height = metrics.size.height;
    final keyboardUp = metrics.viewInsets.bottom > 0;

    // The scene gives up its height as the window shrinks: a short landscape
    // phone gets a strip, and an open keyboard leaves only the brand row.
    final double heroHeight;
    if (keyboardUp) {
      heroHeight = (height * 0.22).clamp(120.0, 170.0);
    } else if (metrics.isShort) {
      heroHeight = (height * 0.36).clamp(170.0, 290.0);
    } else {
      heroHeight = (height * 0.38).clamp(230.0, 380.0);
    }

    final gutter = formGutter(metrics.size.width);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: heroHeight,
          child: _HeroPane(
            wide: false,
            showHeadline: !keyboardUp && heroHeight >= 215,
            showSubtitle: !keyboardUp && heroHeight >= 300,
            topInset: metrics.padding.top + 8,
            // While the keyboard is up the sheet covers nothing, so the band
            // does not need to reserve room for the overlap.
            bottomInset: keyboardUp ? 12 : _sheetOverlap + 18,
          ),
        ),
        Positioned.fill(
          top: heroHeight - _sheetOverlap,
          child: AuthSheet(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                gutter,
                28,
                gutter,
                24 + metrics.padding.bottom,
              ),
              child: form,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tablet-landscape and desktop composition: the scene and the form sit side
/// by side, each with a full-height column of its own.
class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.form, required this.metrics});

  final Widget form;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 11,
          child: _HeroPane(
            wide: true,
            showHeadline: metrics.size.height >= 560,
            showSubtitle: metrics.size.height >= 680,
            topInset: metrics.padding.top + 28,
            bottomInset: 40 + metrics.padding.bottom,
          ),
        ),
        Expanded(
          flex: 9,
          child: Container(
            color: AppColors.creamBright,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 44,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: form,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// The illustration pane
// -----------------------------------------------------------------------------

/// The splash scene with the brand, a two-line headline and — on the wide
/// layout — the three things the app actually does.
///
/// The scene is washed at the top so the dark-green wordmark stays legible
/// against the sky, and washed dark at the bottom so white display type reads
/// over the road. Between the two washes the artwork is untouched, which is
/// what keeps the truck visible.
class _HeroPane extends StatelessWidget {
  const _HeroPane({
    required this.wide,
    required this.showHeadline,
    required this.showSubtitle,
    required this.topInset,
    required this.bottomInset,
  });

  final bool wide;
  final bool showHeadline;
  final bool showSubtitle;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final onDark = wide;
    final brandColor = onDark ? Colors.white : AppColors.darkGreen;
    // Both layouts set their headline over the darkened foot of the scene, so
    // the supporting line is white in both — dark ink would vanish there.
    final muted = Colors.white.withValues(alpha: 0.88);

    return Stack(
      fit: StackFit.expand,
      children: [
        const AuthScene(),
        if (wide)
          // One continuous wash: the split pane carries white display type at
          // the foot and a white wordmark at the head, so the scene has to stay
          // dark across its whole height rather than only at the two ends.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.45, 1],
                  colors: [
                    Color(0xE61B5E20),
                    Color(0x991B5E20),
                    Color(0xE60E3A12),
                  ],
                ),
              ),
            ),
          )
        else ...[
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.36],
                  colors: [Color(0xF2EAF5EA), Color(0x00EAF5EA)],
                ),
              ),
            ),
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.40, 1],
                  colors: [Color(0x00123415), Color(0xD9123415)],
                ),
              ),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(
            wide ? 44 : 18,
            topInset,
            wide ? 44 : 18,
            bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AuthBackButton(
                    onDark: onDark,
                    tooltip: 'Back to home',
                    onTap: () => context.go('/welcome'),
                  ),
                  SizedBox(width: wide ? 18 : 12),
                  // Shrinks rather than overflows when the system text size is
                  // turned up on a narrow phone. Expanded, not Flexible, so the
                  // row divides evenly and the pill lands on the right margin.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: BrandLockup(
                        fontSize: wide ? 26 : 20,
                        color: brandColor,
                        letterSpacing: wide ? 1.8 : 1.2,
                      ),
                    ),
                  ),
                  if (wide)
                    const Spacer()
                  else
                    const Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AuthAreaPill(compact: true),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              if (showHeadline)
                FadeSlideIn(
                  index: 2,
                  offset: 18,
                  child: Text(
                    'Know when.\nKnow where.',
                    style: authSans(
                      size: wide ? 40 : 27,
                      weight: FontWeight.w800,
                      height: 1.1,
                      letterSpacing: wide ? -1.4 : -0.9,
                      color: Colors.white,
                    ).copyWith(
                      // The scene behind the type is not uniform, so the shadow
                      // carries legibility wherever the wash is thin.
                      shadows: const [
                        Shadow(
                          color: Color(0x59123415),
                          blurRadius: 14,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              if (showSubtitle) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 380 : 320),
                  child: Text(
                    wide
                        ? 'Real-time truck tracking, collection reminders and a '
                              'direct line to your barangay — in one place.'
                        : 'Track the truck and never miss a collection day.',
                    style: authSans(
                      size: wide ? 13.5 : 12,
                      weight: FontWeight.w500,
                      height: 1.6,
                      color: muted,
                    ).copyWith(
                      shadows: const [
                        Shadow(
                          color: Color(0x4D123415),
                          blurRadius: 10,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (wide) ...[
                const SizedBox(height: 30),
                const _FeatureRow(
                  icon: Icons.local_shipping_outlined,
                  label: 'Watch the collection truck move in real time',
                ),
                const SizedBox(height: 14),
                const _FeatureRow(
                  icon: Icons.notifications_active_outlined,
                  label: 'Get reminded the day before collection',
                ),
                const SizedBox(height: 14),
                const _FeatureRow(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'File requests and reports with your barangay',
                ),
                const SizedBox(height: 34),
                const AuthAreaPill(onDark: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: authSans(
              size: 12.5,
              weight: FontWeight.w500,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}
