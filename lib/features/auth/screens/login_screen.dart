import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';

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
      context.go('/dashboard');
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
                  _snack('Please wait $remaining more minute(s) before resending.');
                  return;
                }
              }
              Navigator.of(ctx).pop();
              try {
                await AuthService().resendVerificationEmail(
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
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Expanded(flex: 4, child: _LoginHero()),
              Expanded(
                flex: 7,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forest.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: Text(
                              'Log in Account',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          AppTextField(
                            label: 'Email',
                            hint: 'you@email.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: Validators.validateEmail,
                            autofillHints: const [AutofillHints.email],
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
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
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.inkMuted,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _snack('Password reset coming soon'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.only(top: 6, bottom: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'forgot password',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            label: 'Log in',
                            loading: authProvider.isLoading,
                            onPressed: _handleLogin,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'No account?',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go('/signup'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Sign up',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const _ContinueWithDivider(),
                          const SizedBox(height: 14),
                          const _SocialRow(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BrandLockup(fontSize: 27),
          SizedBox(height: 14),
          Text(
            'Know When, Know Where!',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.forest,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 52),
            child: Text(
              'Real-time garbage truck tracking and timely notifications, making '
              'waste disposal easier and more convenient.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, height: 1.5, color: AppColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueWithDivider extends StatelessWidget {
  const _ContinueWithDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(
          icon: Icons.g_mobiledata_rounded,
          color: const Color(0xFFDB4437),
          onTap: () => _notice(context),
        ),
        const SizedBox(width: 14),
        _SocialButton(
          icon: Icons.facebook,
          color: const Color(0xFF1877F2),
          onTap: () => _notice(context),
        ),
      ],
    );
  }

  void _notice(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Social sign-in is coming soon')),
      );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
