import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/user.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_wordmark.dart';
import '../../core/widgets/hex_leaf_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// Drives the copy fade/rise when the screen opens.
  late final AnimationController _intro;

  /// Drives the collection truck across the hills. Loops so the scene never
  /// goes empty if the app lingers on this screen.
  late final AnimationController _drive;

  /// Spins the wheels independently so their speed reads as rolling.
  late final AnimationController _wheels;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _drive = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _wheels = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();

    _timer = Timer(const Duration(milliseconds: 2200), _next);
  }

  void _next() {
    if (!mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }
    switch (user.role) {
      case UserRole.admin:
        context.go('/admin-dashboard');
      case UserRole.driver:
        context.go('/driver');
      case UserRole.user:
        context.go('/user');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    _drive.dispose();
    _wheels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _intro, curve: Curves.easeOut);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.09),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              SlideTransition(
                position: rise,
                child: FadeTransition(
                  opacity: fade,
                  child: const Column(
                    children: [
                      BrandLockup(fontSize: 34),
                      SizedBox(height: 18),
                      Text(
                        'Know When, Know Where!',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.forest,
                        ),
                      ),
                      SizedBox(height: 10),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 56),
                        child: Text(
                          'Real-time garbage truck tracking and timely '
                          'notifications, making waste disposal easier and '
                          'more convenient.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8.5,
                            height: 1.55,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 4),
              _TruckScene(drive: _drive, wheels: _wheels),
              const SizedBox(height: 16),
              const SizedBox(
                height: 3,
                width: 96,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0x33FFFFFF),
                  color: AppColors.forest,
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Loading',
                style: TextStyle(fontSize: 9, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// Layered hills, a scrolling road and a collection truck that drives across
/// them. Everything is drawn from gradients and vectors so the app still ships
/// without bitmap assets.
class _TruckScene extends StatelessWidget {
  const _TruckScene({required this.drive, required this.wheels});

  final Animation<double> drive;
  final Animation<double> wheels;

  static const double _truckWidth = 112;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return ClipRect(
            child: Stack(
              children: [
                Positioned(
                  bottom: -70,
                  left: -40,
                  child: _blob(240, 170, const Color(0xFFCDE8B4)),
                ),
                Positioned(
                  bottom: -80,
                  right: -50,
                  child: _blob(220, 150, const Color(0xFFB9DDA0)),
                ),
                Positioned(
                  bottom: -60,
                  left: width / 2 - 95,
                  child: _blob(190, 120, const Color(0xFFA8D48D)),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 34,
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
                  bottom: 22,
                  height: 58,
                  child: AnimatedBuilder(
                    animation: drive,
                    builder: (context, child) {
                      final x = -_truckWidth +
                          drive.value * (width + _truckWidth * 1.6);
                      final bob = math.sin(drive.value * math.pi * 16) * 1.1;
                      return Transform.translate(
                        offset: Offset(x, bob),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: child,
                        ),
                      );
                    },
                    child: Transform.scale(
                      scale: 1.15,
                      alignment: Alignment.bottomCenter,
                      child: _Truck(wheels: wheels),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _blob(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.all(
          Radius.elliptical(width / 2, height / 2),
        ),
      ),
    );
  }
}

/// Road surface plus the centre dashes, which scroll left as the truck moves
/// right so the scene reads as motion rather than a sliding sticker.
class _RoadPainter extends CustomPainter {
  const _RoadPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final surface = Paint()..color = const Color(0xFFF2F8E7);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, size.height - 22, size.width, 22),
        topLeft: const Radius.circular(11),
        topRight: const Radius.circular(11),
      ),
      surface,
    );

    const period = 30.0;
    final dash = Paint()
      ..color = const Color(0xFFC6D5B3)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    const inset = 14.0;
    final shift = -(progress * period) % period;
    final y = size.height - 11;
    for (var x = shift - period + inset; x < size.width - inset; x += period) {
      canvas.drawLine(Offset(x, y), Offset(x + 14, y), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) => old.progress != progress;
}

class _Truck extends StatelessWidget {
  const _Truck({required this.wheels});

  final Animation<double> wheels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 58,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 2,
            width: 70,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.all(Radius.circular(9)),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            top: 11,
            child: HexLeafLogo(
              size: 18,
              color: Colors.white,
              strokeWidth: 1.6,
            ),
          ),
          const Positioned(
            left: 68,
            top: 14,
            width: 38,
            height: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.forestDeep,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 78,
            top: 19,
            width: 18,
            height: 11,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFCFE9B6),
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ),
          ),
          const Positioned(
            left: 2,
            top: 36,
            width: 104,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.forestDeep,
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ),
          ),
          Positioned(left: 8, top: 36, child: _Wheel(turns: wheels, size: 22)),
          Positioned(left: 72, top: 36, child: _Wheel(turns: wheels, size: 22)),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({required this.turns, required this.size});

  final Animation<double> turns;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: turns,
      builder: (context, _) => CustomPaint(
        size: Size.square(size),
        painter: _WheelPainter(turns.value),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter(this.turns);

  final double turns;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);

    canvas.drawCircle(center, r, Paint()..color = const Color(0xFF1F2A20));
    canvas.drawCircle(center, r * 0.62, Paint()..color = const Color(0xFFCBD8BE));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(turns * 2 * math.pi);

    final spoke = Paint()
      ..color = const Color(0xFF6F7F69)
      ..strokeWidth = math.max(1.2, r * 0.16)
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      canvas.drawLine(
        Offset(math.cos(angle) * r * 0.18, math.sin(angle) * r * 0.18),
        Offset(math.cos(angle) * r * 0.52, math.sin(angle) * r * 0.52),
        spoke,
      );
    }
    canvas.restore();

    canvas.drawCircle(center, r * 0.2, Paint()..color = const Color(0xFF6F7F69));
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.turns != turns;
}
