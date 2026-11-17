import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/reduced_motion.dart';
import 'eco_loading.dart';
import 'motion.dart';

/// Friendly placeholder shown when a list or query has no results.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 28,
          vertical: compact ? 24 : 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FloatingBadge(icon: icon, compact: compact),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: AppColors.darkGreen,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 7),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The empty-state mark: a soft green disc that breathes a few pixels, with
/// the icon fading in once. Still when the platform asks for reduced motion.
class _FloatingBadge extends StatefulWidget {
  const _FloatingBadge({required this.icon, required this.compact});

  final IconData icon;
  final bool compact;

  @override
  State<_FloatingBadge> createState() => _FloatingBadgeState();
}

class _FloatingBadgeState extends State<_FloatingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 52.0 : 68.0;
    final badge = Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(
        color: AppColors.lightGreen,
        shape: BoxShape.circle,
      ),
      child: Icon(
        widget.icon,
        size: widget.compact ? 24 : 30,
        color: AppColors.primary,
      ),
    );

    if (reduceMotion(context)) {
      return FadeSlideIn(child: badge);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -2.5 * _controller.value),
          child: child,
        );
      },
      child: FadeSlideIn(child: badge),
    );
  }
}

/// Centred truck loader with an optional label. Delegates to [EcoLoadingView]
/// so every waiting screen in the app shares the same motion.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => EcoLoadingView(label: label);
}

/// Standard error state with a retry action.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 34,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
