import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../app/constants/theme.dart';

class AnimatedLoader extends StatefulWidget {
  const AnimatedLoader({Key? key}) : super(key: key);

  @override
  State<AnimatedLoader> createState() => _AnimatedLoaderState();
}

class _AnimatedLoaderState extends State<AnimatedLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(100, 100),
          painter: _LoaderPainter(_controller.value),
        );
      },
    );
  }
}

class _LoaderPainter extends CustomPainter {
  final double progress;

  _LoaderPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Glowing background fill
    final bgPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, bgPaint);

    // Expanding concentric ripples
    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i / 3.0)) % 1.0;
      final radius = maxRadius * waveProgress;
      final opacity = 1.0 - waveProgress;

      final wavePaint = Paint()
        ..color = AppColors.secondary.withOpacity(opacity * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawCircle(center, radius, wavePaint);
    }

    // Satellite orb orbiting the center core
    final orbitRadius = maxRadius * 0.65;
    final angle = progress * 2 * pi;
    final orbOffset = Offset(
      center.dx + orbitRadius * cos(angle),
      center.dy + orbitRadius * sin(angle),
    );

    // Orb shadow
    final shadowPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(orbOffset, 8, shadowPaint);

    // Solid orb
    final orbPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(orbOffset, 6, orbPaint);

    // Neon glowing core
    final corePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 14, corePaint);

    final coreSolidPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, coreSolidPaint);
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter oldDelegate) => true;
}
