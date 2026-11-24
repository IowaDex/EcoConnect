import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/auth_type.dart';
import '../../../core/design/eco_tokens.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/reduced_motion.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/primary_button.dart';

/// Password recovery, in two beats: ask for the address, then wait for the
/// link.
///
/// The screen reuses the entry shell, so it opens on the same scene and the
/// same sheet as login — the visitor does not lose their place in the flow.
/// Once the link is on its way the form is replaced by a receipt: the address
/// it went to, a send cooldown that drains in front of them, and a way back to
/// the form if they mistyped it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  /// Firebase hands out one reset link per request, and its default action
  /// link expires after an hour. The cooldown is a send limit, not the link's
  /// lifetime: it keeps a double tap from firing two emails.
  static const _cooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  late final AnimationController _cooldown = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _cooldownSeconds),
  );

  bool _sending = false;
  bool _sent = false;
  String? _error;

  bool get _coolingDown => _cooldown.isAnimating;

  @override
  void dispose() {
    _cooldown.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _coolingDown) return;
    // The form is only in the tree before the first send. Resending from the
    // receipt skips validation because the address already passed it.
    if (!_sent && !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _sending = true;
      _error = null;
    });

    final error = await context.read<AuthProvider>().sendPasswordReset(
      _email.text.trim(),
    );
    if (!mounted) return;

    setState(() {
      _sending = false;
      _error = error;
      // A failed resend leaves the receipt in place: the first link still
      // exists, and the visitor should not be thrown back to the form.
      if (error == null) _sent = true;
    });
    if (error == null) _cooldown.forward(from: 0);
  }

  /// Back to the form with the address still filled in, so a typo is a small
  /// correction rather than a retype.
  void _editEmail() {
    _cooldown.reset();
    setState(() {
      _sent = false;
      _error = null;
    });
  }

  void _backToLogin() => context.go('/login');

  @override
  Widget build(BuildContext context) {
    // The receipt grows out of the form, so the two states share one page
    // frame instead of swapping to a second screen.
    final motion = reduceMotion(context) ? Duration.zero : EcoMotion.base;

    return AuthPageShell(
      onBack: _backToLogin,
      backTooltip: 'Back to login',
      headline: 'Locked out?\nWe\'ll get you back in.',
      heroSubtitle:
          'One secure link, sent to the email on your account. Open it, choose '
          'a new password, and you are done.',
      heroSteps: const [
        AuthHeroStep('Enter the email you signed up with'),
        AuthHeroStep('Open the link we send you'),
        AuthHeroStep('Choose a new password'),
      ],
      form: AnimatedSize(
        duration: motion,
        curve: EcoMotion.enter,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: motion,
          switchInCurve: EcoMotion.enter,
          switchOutCurve: EcoMotion.exit,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _sent ? _receipt() : _form(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — the form
  // ---------------------------------------------------------------------------

  Widget _form() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          key: const ValueKey('form'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FadeSlideIn(
              index: 0,
              offset: 10,
              child: AuthHeading(
                eyebrow: 'PASSWORD RECOVERY',
                title: 'Forgot password?',
                subtitle:
                    'Enter the email you signed up with and we will send you '
                    'a link to choose a new password.',
              ),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              index: 1,
              child: AppTextField(
                label: 'Email',
                hint: 'you@email.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                // A pasted address often carries a trailing space, which reads
                // as "invalid email" with no visible reason.
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                autofillHints: const [AutofillHints.email],
                validator: Validators.validateEmail,
                onChanged: (_) {
                  // A stale error under a field the visitor just corrected is
                  // worse than no error at all.
                  if (_error != null) setState(() => _error = null);
                },
                onFieldSubmitted: (_) => _send(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 2,
                offset: 8,
                child: _ErrorNote(message: _error!),
              ),
            ],
            const SizedBox(height: 22),
            FadeSlideIn(
              index: 3,
              child: PrimaryButton(
                label: 'Send reset link',
                height: 54,
                loading: _sending,
                onPressed: _send,
              ),
            ),
            const SizedBox(height: 12),
            const FadeSlideIn(index: 4, child: _PrivacyNote()),
            const SizedBox(height: 4),
            FadeSlideIn(
              index: 5,
              child: AuthAltAction(
                prompt: 'Remembered it?',
                action: 'Back to login',
                onTap: _backToLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — the receipt
  // ---------------------------------------------------------------------------

  Widget _receipt() {
    final email = _email.text.trim();

    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        key: const ValueKey('sent'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          const _SuccessMark(),
          const SizedBox(height: 20),
          Text(
            'Check your inbox',
            textAlign: TextAlign.center,
            style: authSans(
              size: 26,
              weight: FontWeight.w800,
              height: 1.12,
              letterSpacing: -0.8,
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'We sent a reset link to '),
                TextSpan(
                  text: email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGreen,
                  ),
                ),
                const TextSpan(
                  text: '. Open it to choose a new password.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: authSans(size: 12, height: 1.55, color: AppColors.inkMuted),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorNote(message: _error!),
          ],
          const SizedBox(height: 22),
          _ResendPanel(
            cooldown: _cooldown,
            totalSeconds: _cooldownSeconds,
            sending: _sending,
            onResend: _send,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Use a different email',
            outlined: true,
            height: 50,
            onPressed: _sending ? null : _editEmail,
          ),
          const SizedBox(height: 6),
          AuthAltAction(
            prompt: 'Remembered it?',
            action: 'Log in',
            onTap: _backToLogin,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

/// The confirmation mark: a soft mint disc that settles into place once.
class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);

    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: still ? Duration.zero : const Duration(milliseconds: 560),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          // easeOutBack overshoots 1 before it settles; the disc may scale
          // past its size, but it must never go fully transparent again.
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.72 + 0.28 * t, child: child),
        ),
        child: Container(
          height: 76,
          width: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.lightGreen, Color(0xFFD7EDD9)],
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.darkGreen.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 34,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The resend control and its countdown.
///
/// The bar drains over the full minute rather than stepping once per second,
/// so the wait reads as a deadline instead of a frozen label. The button stays
/// in the same place and the same size while disabled, so nothing jumps when
/// the cooldown ends.
class _ResendPanel extends StatelessWidget {
  const _ResendPanel({
    required this.cooldown,
    required this.totalSeconds,
    required this.sending,
    required this.onResend,
  });

  final AnimationController cooldown;
  final int totalSeconds;
  final bool sending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cooldown,
      builder: (context, _) {
        final remaining = (totalSeconds * (1 - cooldown.value)).ceil();
        final ready = remaining <= 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              label: ready
                  ? 'Resend link'
                  : 'Resend in ${_minutesAndSeconds(remaining)}',
              outlined: true,
              height: 50,
              loading: sending,
              onPressed: ready ? onResend : null,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(EcoRadius.pill),
              child: LinearProgressIndicator(
                value: 1 - cooldown.value,
                minHeight: 4,
                backgroundColor: AppColors.mint,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ready
                  ? 'Still nothing? Check your spam folder.'
                  : 'We hold the next send for a minute so your inbox is not '
                        'flooded.',
              textAlign: TextAlign.center,
              style: authSans(
                size: 11,
                height: 1.45,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// An inline failure with an icon, so it reads as a message and not as a
/// stray line of red text.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(EcoRadius.sm),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: authSans(
                size: 11.5,
                height: 1.45,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The quiet promise under the button: what the link does, and what the app
/// will never ask for.
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 13,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            'The link works once and expires after an hour. We never ask for '
            'your password by email.',
            style: authSans(
              size: 11,
              height: 1.5,
              color: AppColors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// 45 → "0:45", 60 → "1:00".
String _minutesAndSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
