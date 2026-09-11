import 'dart:ui';
import 'package:flutter/material.dart';
import '../../app/constants/theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final double? width;
  final double borderRadius;
  final Color? borderColor;
  final List<Color>? gradientColors;

  const GlassCard({
    Key? key,
    required this.child,
    this.padding,
    this.height,
    this.width,
    this.borderRadius = AppBorderRadius.md,
    this.borderColor,
    this.gradientColors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultBorderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xFFE2E8F0);

    final defaultGradients = isDark
        ? [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ]
        : [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.85),
          ];

    final shadowColor = isDark
        ? Colors.black.withOpacity(0.25)
        : const Color(0xFF64748B).withOpacity(0.12);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? defaultBorderColor,
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors ?? defaultGradients,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
