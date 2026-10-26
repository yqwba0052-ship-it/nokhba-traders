import 'dart:ui';

import 'package:flutter/material.dart';

/// Colors of the glass screens (متداولين اليوم / السنة).
abstract final class GlassColors {
  static const violet = Color(0xFFE6DEFF);
  static const lavender = Color(0xFFD5CCF2);
  static const blueGrey = Color(0xFFBFC9DE);
  static const glowPurple = Color(0xFFA78BFA);
  static const glowBlue = Color(0xFF60A5FA);
  static const ink = Color(0xFF27224A);
  static const inkSoft = Color(0xFF5B5680);
  static const green = Color(0xFF0F9D58);
}

/// Light violet → lavender → blue-grey gradient with two soft color blobs.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            GlassColors.violet,
            GlassColors.lavender,
            GlassColors.blueGrey,
          ],
        ),
      ),
      child: Stack(
        children: [
          const _Blob(
            alignment: Alignment(-1.2, -0.7),
            color: GlassColors.glowPurple,
            size: 260,
          ),
          const _Blob(
            alignment: Alignment(1.3, 0.8),
            color: GlassColors.glowBlue,
            size: 300,
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.alignment,
    required this.color,
    required this.size,
  });

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass with a glowing purple/blue edge.
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = EdgeInsets.zero,
    this.fill = 0.28,
    this.glow = true,
    this.shape = BoxShape.rectangle,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double fill;
  final bool glow;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final circle = shape == BoxShape.circle;
    final outer = circle ? null : BorderRadius.circular(radius);
    final inner = circle ? null : BorderRadius.circular(radius - 1.4);
    return Container(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: outer,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            GlassColors.glowPurple.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.85),
            GlassColors.glowBlue.withValues(alpha: 0.95),
          ],
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: GlassColors.glowPurple.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(-3, -2),
                ),
                BoxShadow(
                  color: GlassColors.glowBlue.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(3, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(1.4),
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: circle
              ? const CircleBorder()
              : RoundedRectangleBorder(borderRadius: inner!),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: inner,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: fill + 0.12),
                  Colors.white.withValues(alpha: fill - 0.08),
                ],
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Round glass button (refresh, page arrows, row arrow).
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.size = 48,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: SizedBox.square(
        dimension: size,
        child: GlassBox(
          shape: BoxShape.circle,
          fill: 0.4,
          glow: size >= 40,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// An icon that never flips with RTL (arrows must point where the owner asked).
class FixedIcon extends StatelessWidget {
  const FixedIcon(this.icon, {super.key, this.size = 22, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Icon(icon, size: size, color: color ?? GlassColors.ink),
  );
}
