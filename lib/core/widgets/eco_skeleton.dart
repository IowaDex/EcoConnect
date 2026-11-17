import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/reduced_motion.dart';

/// A single shimmering placeholder block.
///
/// The shimmer is one repeating controller per box, which is cheap enough for
/// the handful of blocks a skeleton list draws. When the platform asks for
/// reduced motion the block stays a flat tint instead of pulsing.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.sage.withValues(alpha: 0.35);
    final highlight = AppColors.sage.withValues(alpha: 0.12);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: reduceMotion(context)
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(widget.radius),
              ),
            )
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    gradient: LinearGradient(
                      begin: Alignment(-1 + 2 * t, 0),
                      end: Alignment(1 + 2 * t, 0),
                      colors: [base, highlight, base],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// A stack of card-shaped placeholders, used while a list streams in.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 3,
    this.height = 96,
    this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 18),
  });

  final int count;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => Container(
        height: height,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.5)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 74, height: 10, radius: 5),
            SizedBox(height: 10),
            SkeletonBox(width: double.infinity, height: 13),
            SizedBox(height: 8),
            SkeletonBox(width: 140, height: 10, radius: 5),
          ],
        ),
      ),
    );
  }
}
