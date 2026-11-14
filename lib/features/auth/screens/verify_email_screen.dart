import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/primary_button.dart';

/// Second half of resident sign-up: type the 6-digit code that was emailed.
///
/// Reached right after sign-up, or from login when someone left before
/// entering the code. The resident is signed in but still pending; a correct
/// code sends the registration to the barangay and signs them out until it is
/// approved.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _resendSeconds = 60;

  final _code = TextEditingController();
  String? _email;
  int _wait = 0;
  Timer? _timer;
  bool _sending = false;

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
      _send();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
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

  Future<void> _send() async {
    setState(() => _sending = true);
    final sentTo = await _auth.requestEmailCode();
    if (!mounted) return;
    setState(() => _sending = false);
    if (sentTo == null) {
      _toast(_auth.error ?? 'Could not send the code.', error: true);
      return;
    }
    _startCountdown();
    _toast('Code sent to $sentTo');
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      _toast('Enter the 6-digit code.', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    final ok = await _auth.verifyEmailCode(code);
    if (!mounted) return;
    if (!ok) {
      _toast(_auth.error ?? 'That code did not work.', error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sent to your barangay'),
        content: const Text(
          'Your email is verified. Barangay Batasan Hills will now check your '
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
              const Text(
                'Check your\nemail',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a 6-digit code to ${_email ?? 'your email'}. '
                'It expires in 10 minutes.',
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 24),
              TextField(
                key: const ValueKey('otp-field'),
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 26,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forest,
                ),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                ),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Verify and send to barangay',
                loading: busy,
                onPressed: _verify,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: (_wait > 0 || _sending) ? null : _send,
                  child: Text(
                    _sending
                        ? 'Sending…'
                        : _wait > 0
                            ? 'Resend code in ${_wait}s'
                            : 'Resend code',
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
