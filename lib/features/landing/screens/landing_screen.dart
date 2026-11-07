import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';

/// Public landing page. The first thing a signed-out visitor sees: a
/// hand-drawn garbage truck driving along a highway, with the brand promise
/// and the two entry points into the app.
///
/// Everything is vector-drawn with [CustomPainter] and driven by three
/// animation controllers, so it ships without bitmap or Lottie assets and
/// stays smooth on low-end Android devices.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  /// Truck travelling across the scene.
  late final AnimationController _drive;

  /// Cloud drift and gentle parallax.
  late final AnimationController _ambient;

  /// Wheel rotation. Runs faster than the drive loop so the wheels read as
  /// rolling rather than sliding.
  late final AnimationController _wheels;

  /// Entrance animation for the copy and buttons.
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _drive = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();
    _wheels = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _drive.dispose();
    _ambient.dispose();
    _wheels.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sceneHeight =
                (constraints.maxHeight * 0.54).clamp(230.0, 470.0);
            return Column(
              children: [
                SizedBox(
                  height: sceneHeight,
                  width: double.infinity,
                  child: RepaintBoundary(
                    child: _HighwayScene(
                      drive: _drive,
                      ambient: _ambient,
                      wheels: _wheels,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: _LandingPanel(intro: _intro),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LandingPanel extends StatelessWidget {
  const _LandingPanel({required this.intro});

  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: intro, curve: Curves.easeOut);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: intro, curve: Curves.easeOutCubic));

    return SlideTransition(
      position: rise,
      child: FadeTransition(
        opacity: fade,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: BrandLockup(fontSize: 26)),
              const SizedBox(height: 16),
              const Text(
                'Smarter waste collection\nfor every barangay',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  height: 1.22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Connecting Communities for a Cleaner and Greener Tomorrow.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.55,
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: 18),
              const _FeatureRow(),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => context.go('/signup'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Get Started'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () => context.go('/login'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('I already have an account'),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Real-time truck tracking · Collection requests · Community programs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5,
                  height: 1.5,
                  letterSpacing: 0.1,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.local_shipping_rounded, label: 'Track'),
    (icon: Icons.assignment_outlined, label: 'Request'),
    (icon: Icons.recycling_rounded, label: 'Recycle'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(_items[i].icon, size: 19, color: AppColors.primary),
                  const SizedBox(height: 5),
                  Text(
                    _items[i].label,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Sky, hills, trees, clouds, road and the truck.
class _HighwayScene extends StatelessWidget {
  const _HighwayScene({
    required this.drive,
    required this.ambient,
    required this.wheels,
  });

  final Animation<double> drive;
  final Animation<double> ambient;
  final Animation<double> wheels;

  static const double _truckWidth = 168;
  static const double _truckHeight = 92;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final roadHeight = (height * 0.30).clamp(64.0, 104.0);
        final truckScale = (width / 420).clamp(0.78, 1.15);
        final truckW = _truckWidth * truckScale;
        final truckH = _truckHeight * truckScale;

        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: ambient,
                  builder: (context, _) => CustomPaint(
                    painter: _BackdropPainter(ambient.value, roadHeight),
                  ),
                ),
              ),
              // Floating recycling marks add life without stealing focus.
              Positioned(
                left: width * 0.08,
                top: height * 0.16,
                child: AnimatedBuilder(
                  animation: ambient,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      0,
                      math.sin(ambient.value * math.pi * 2) * 7,
                    ),
                    child: Transform.rotate(
                      angle: math.sin(ambient.value * math.pi * 2) * 0.12,
                      child: child,
                    ),
                  ),
                  child: const _FloatingMark(
                    icon: Icons.recycling_rounded,
                    size: 22,
                    color: Color(0xFF8BC78E),
                  ),
                ),
              ),
              Positioned(
                right: width * 0.10,
                top: height * 0.28,
                child: AnimatedBuilder(
                  animation: ambient,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      0,
                      math.cos(ambient.value * math.pi * 2) * 9,
                    ),
                    child: child,
                  ),
                  child: const _FloatingMark(
                    icon: Icons.eco_rounded,
                    size: 18,
                    color: Color(0xFFA5D6A7),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: roadHeight,
                child: AnimatedBuilder(
                  animation: drive,
                  builder: (context, _) => CustomPaint(
                    painter: _RoadPainter(drive.value),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: roadHeight * 0.36,
                height: truckH,
                child: AnimatedBuilder(
                  animation: drive,
                  builder: (context, child) {
                    // Constant-speed traversal with a one-truck gap between
                    // loops so the scene never looks like a jump cut.
                    final travel = width + truckW * 2;
                    final x = -truckW + drive.value * travel;
                    final bob = math.sin(drive.value * math.pi * 14) * 1.2;
                    return Transform.translate(
                      offset: Offset(x, bob),
                      child: child,
                    );
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: truckW,
                      height: truckH,
                      child: AnimatedBuilder(
                        animation: wheels,
                        builder: (context, _) => CustomPaint(
                          painter: _TruckPainter(
                            wheelTurn: wheels.value,
                            scale: truckScale,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FloatingMark extends StatelessWidget {
  const _FloatingMark({
    required this.icon,
    required this.size,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color.withValues(alpha: 0.75));
  }
}

/// Sky, sun, clouds, hills, grass and trees.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.progress, this.roadHeight);

  final double progress;
  final double roadHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky.
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFDCEFDD), Color(0xFFF7FAF7)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), sky);

    // Sun with a soft halo.
    final sun = Offset(w * 0.80, h * 0.20);
    canvas.drawCircle(
      sun,
      h * 0.13,
      Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      sun,
      h * 0.075,
      Paint()..color = const Color(0xFFFFE082),
    );

    // Clouds drift slowly and wrap around.
    _cloud(canvas, w, h, baseX: 0.12, baseY: 0.16, scale: 1.0, speed: 0.9);
    _cloud(canvas, w, h, baseX: 0.52, baseY: 0.09, scale: 0.72, speed: 0.55);
    _cloud(canvas, w, h, baseX: 0.84, baseY: 0.24, scale: 0.86, speed: 0.75);

    final groundTop = h - roadHeight;

    // Distant hill.
    final farHill = Path()
      ..moveTo(0, groundTop)
      ..quadraticBezierTo(w * 0.18, groundTop - h * 0.20, w * 0.40, groundTop)
      ..quadraticBezierTo(w * 0.62, groundTop - h * 0.26, w * 0.84, groundTop)
      ..quadraticBezierTo(w * 0.94, groundTop - h * 0.10, w, groundTop)
      ..lineTo(w, groundTop + 2)
      ..lineTo(0, groundTop + 2)
      ..close();
    canvas.drawPath(farHill, Paint()..color = const Color(0xFFCDE8CF));

    // Near hill.
    final nearHill = Path()
      ..moveTo(0, groundTop)
      ..quadraticBezierTo(w * 0.28, groundTop - h * 0.13, w * 0.55, groundTop)
      ..quadraticBezierTo(w * 0.78, groundTop - h * 0.16, w, groundTop)
      ..lineTo(w, groundTop + 2)
      ..lineTo(0, groundTop + 2)
      ..close();
    canvas.drawPath(nearHill, Paint()..color = const Color(0xFFB7DDBA));

    // Grass verge between the hills and the road.
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop - 6, w, roadHeight + 6),
      Paint()..color = const Color(0xFFA5D6A7),
    );

    // Trees, sized relative to the scene.
    _tree(canvas, Offset(w * 0.10, groundTop - 4), h * 0.115);
    _tree(canvas, Offset(w * 0.19, groundTop - 2), h * 0.085);
    _tree(canvas, Offset(w * 0.72, groundTop - 3), h * 0.10);
    _tree(canvas, Offset(w * 0.90, groundTop - 5), h * 0.13);

    // Small bushes.
    for (final x in [0.30, 0.36, 0.60, 0.66]) {
      canvas.drawCircle(
        Offset(w * x, groundTop - 2),
        h * 0.018,
        Paint()..color = const Color(0xFF7FBF86),
      );
    }
  }

  void _cloud(
    Canvas canvas,
    double w,
    double h, {
    required double baseX,
    required double baseY,
    required double scale,
    required double speed,
  }) {
    final cloudW = w * 0.24 * scale;
    final travel = w + cloudW * 2;
    final x = ((baseX * w + progress * travel * speed) % travel) - cloudW;
    final y = h * baseY;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);

    canvas.drawCircle(Offset(x + cloudW * 0.25, y), cloudW * 0.16, paint);
    canvas.drawCircle(Offset(x + cloudW * 0.45, y - cloudW * 0.06), cloudW * 0.21, paint);
    canvas.drawCircle(Offset(x + cloudW * 0.68, y), cloudW * 0.15, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x + cloudW * 0.18, y, cloudW * 0.58, cloudW * 0.17),
        Radius.circular(cloudW * 0.09),
      ),
      paint,
    );
  }

  void _tree(Canvas canvas, Offset base, double height) {
    final trunkWidth = height * 0.14;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          base.dx - trunkWidth / 2,
          base.dy - height * 0.45,
          trunkWidth,
          height * 0.45,
        ),
        Radius.circular(trunkWidth / 2),
      ),
      Paint()..color = const Color(0xFF8D6E63),
    );
    final canopy = Paint()..color = const Color(0xFF4CAF50);
    canvas.drawCircle(Offset(base.dx, base.dy - height * 0.60), height * 0.30, canopy);
    canvas.drawCircle(
      Offset(base.dx - height * 0.18, base.dy - height * 0.45),
      height * 0.22,
      Paint()..color = const Color(0xFF43A047),
    );
    canvas.drawCircle(
      Offset(base.dx + height * 0.18, base.dy - height * 0.45),
      height * 0.22,
      Paint()..color = const Color(0xFF43A047),
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.progress != progress || old.roadHeight != roadHeight;
}

/// Asphalt band with scrolling lane markings.
class _RoadPainter extends CustomPainter {
  const _RoadPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF3E4A42),
    );

    // Kerb highlight.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.10),
      Paint()..color = const Color(0xFF566257),
    );

    const period = 54.0;
    final dash = Paint()
      ..color = const Color(0xFFF7FAF7).withValues(alpha: 0.85)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final shift = -(progress * period * 2) % period;
    final y = h * 0.58;
    for (var x = shift - period; x < w + period; x += period) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y - 1.5, 26, 3),
          const Radius.circular(2),
        ),
        dash,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) => old.progress != progress;
}

/// The truck itself: cargo body, cab, window, lights and two spinning wheels.
class _TruckPainter extends CustomPainter {
  const _TruckPainter({required this.wheelTurn, required this.scale});

  final double wheelTurn;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ground shadow.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.08, h * 0.86, w * 0.82, h * 0.10),
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );

    // Cargo body.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.20, w * 0.58, h * 0.47),
      Radius.circular(h * 0.09),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.primary);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.04, h * 0.20, w * 0.58, h * 0.13),
        Radius.circular(h * 0.09),
      ),
      Paint()..color = AppColors.secondary,
    );

    // Side stripe.
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.49, w * 0.56, h * 0.05),
      Paint()..color = AppColors.lightGreen.withValues(alpha: 0.85),
    );

    // Leaf mark on the body.
    final leafCenter = Offset(w * 0.24, h * 0.36);
    final leaf = Path()
      ..moveTo(leafCenter.dx, leafCenter.dy + h * 0.06)
      ..quadraticBezierTo(
        leafCenter.dx - h * 0.09,
        leafCenter.dy - h * 0.02,
        leafCenter.dx,
        leafCenter.dy - h * 0.07,
      )
      ..quadraticBezierTo(
        leafCenter.dx + h * 0.09,
        leafCenter.dy - h * 0.02,
        leafCenter.dx,
        leafCenter.dy + h * 0.06,
      )
      ..close();
    canvas.drawPath(leaf, Paint()..color = Colors.white.withValues(alpha: 0.92));

    // Cab.
    final cab = Path()
      ..moveTo(w * 0.62, h * 0.67)
      ..lineTo(w * 0.62, h * 0.33)
      ..quadraticBezierTo(w * 0.63, h * 0.26, w * 0.71, h * 0.26)
      ..lineTo(w * 0.84, h * 0.26)
      ..quadraticBezierTo(w * 0.92, h * 0.28, w * 0.95, h * 0.40)
      ..lineTo(w * 0.96, h * 0.67)
      ..close();
    canvas.drawPath(cab, Paint()..color = AppColors.darkGreen);

    // Window.
    final window = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.67, h * 0.33, w * 0.19, h * 0.17),
      Radius.circular(h * 0.035),
    );
    canvas.drawRRect(
      window,
      Paint()..color = const Color(0xFFCFE9D2),
    );

    // Headlight and bumper.
    canvas.drawCircle(
      Offset(w * 0.94, h * 0.58),
      h * 0.026,
      Paint()..color = const Color(0xFFFFE082),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.60, h * 0.66, w * 0.38, h * 0.06),
        Radius.circular(h * 0.03),
      ),
      Paint()..color = const Color(0xFF2B3A2E),
    );

    // Wheels.
    _wheel(canvas, Offset(w * 0.21, h * 0.74), h * 0.145);
    _wheel(canvas, Offset(w * 0.75, h * 0.74), h * 0.145);
  }

  void _wheel(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF1F2A20));
    canvas.drawCircle(
      center,
      radius * 0.62,
      Paint()..color = const Color(0xFFD7E3D8),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(wheelTurn * 2 * math.pi);
    final spoke = Paint()
      ..color = const Color(0xFF5F6F64)
      ..strokeWidth = math.max(1.6, radius * 0.18)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final angle = i * 2 * math.pi / 5;
      canvas.drawLine(
        Offset(
          math.cos(angle) * radius * 0.16,
          math.sin(angle) * radius * 0.16,
        ),
        Offset(
          math.cos(angle) * radius * 0.50,
          math.sin(angle) * radius * 0.50,
        ),
        spoke,
      );
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      radius * 0.16,
      Paint()..color = const Color(0xFF5F6F64),
    );
  }

  @override
  bool shouldRepaint(covariant _TruckPainter old) =>
      old.wheelTurn != wheelTurn || old.scale != scale;
}
