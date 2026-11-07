import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _cooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  Timer? _timer;
  bool _sending = false;
  bool _sent = false;
  String? _error;
  int _cooldown = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _cooldown > 0) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await context.read<AuthProvider>().sendPasswordReset(_email.text);
    if (!mounted) return;

    setState(() {
      _sending = false;
      _error = error;
      _sent = error == null;
      if (error == null) _cooldown = _cooldownSeconds;
    });
    if (error == null) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown--);
        if (_cooldown <= 0) t.cancel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AppColors.forest),
                    onPressed: () => context.go('/login'),
                  ),
                  const SizedBox(width: 8),
                  const BrandWordmark(fontSize: 12),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter the email you signed up with and we will send '
                        'you a link to choose a new password.',
                        style: TextStyle(
                            fontSize: 11, height: 1.5, color: AppColors.inkMuted),
                      ),
                      const SizedBox(height: 26),
                      AppTextField(
                        label: 'Email',
                        hint: 'you@email.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        validator: Validators.validateEmail,
                        onFieldSubmitted: (_) => _send(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.danger),
                        ),
                      ],
                      if (_sent) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'If an account exists for ${_email.text.trim()}, a '
                            'reset link is on its way. Check your inbox and '
                            'spam folder.',
                            style: const TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                color: AppColors.forest),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: _cooldown > 0
                            ? 'Resend in ${_cooldown}s'
                            : _sent
                                ? 'Resend link'
                                : 'Send reset link',
                        loading: _sending,
                        onPressed: _cooldown > 0 ? null : _send,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text(
                            'Back to login',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700),
                          ),
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
}
