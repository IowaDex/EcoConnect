import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';

/// Second half of resident sign-up: confirm the email with Firebase's link.
///
/// Reached right after sign-up (the link was just sent) or from login when
/// someone has not confirmed yet. The resident is signed in but still pending;
/// once the link is clicked, "I've confirmed" sends the registration to the
/// barangay and signs them out until it is approved.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _resendSeconds = 60;

  String? _email;
  int _wait = 0;
  Timer? _timer;

  AuthProvider get _auth => context.read<AuthProvider>();

  @override
  void initState() {
    super.initState();
    _email = _auth.pendingSignupEmail;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_email == null) {
        context.go('/login');
        return;
      }
      // The link was just sent by sign-up (or earlier); wait before resending.
      _startCountdown();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.danger : null,
        ),
      );
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _wait = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _wait <= 1) {
        t.cancel();
        if (mounted) setState(() => _wait = 0);
        return;
      }
      setState(() => _wait--);
    });
  }

  Future<void> _resend() async {
    final ok = await _auth.resendVerificationLink();
    if (!mounted) return;
    if (!ok) {
      _toast(_auth.error ?? 'Could not send the email.', error: true);
      return;
    }
    _startCountdown();
    _toast('Link sent again to $_email');
  }

  Future<void> _confirmed() async {
    final ok = await _auth.confirmEmailVerified();
    if (!mounted) return;
    if (!ok) {
      _toast(
        _auth.error ??
            'Your email is not confirmed yet. Open the link in the email first.',
        error: true,
      );
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sent to your barangay'),
        content: const Text(
          'Your email is confirmed. Barangay Batasan Hills will now check your '
          'ID. You can sign in once they approve your account.',
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
  }

  Future<void> _cancel() async {
    await _auth.cancelPendingSignup();
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthProvider>().isLoading;
    final gutter = formGutter(MediaQuery.sizeOf(context).width);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppColors.forest,
                    ),
                    onPressed: _cancel,
                  ),
                  const SizedBox(width: 8),
                  const BrandWordmark(fontSize: 12),
                ],
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 48,
                color: AppColors.forest,
              ),
              const SizedBox(height: 14),
              const Text(
                'Confirm your\nemail',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a confirmation link to ${_email ?? 'your email'}. '
                'Open it, then come back here and tap the button below.',
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'I’ve confirmed my email',
                loading: busy,
                onPressed: _confirmed,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _wait > 0 ? null : _resend,
                  child: Text(
                    _wait > 0 ? 'Resend link in ${_wait}s' : 'Resend link',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Didn’t get it? Check your spam folder.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
