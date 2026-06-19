import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/brand_config.dart';
import '../../theme/gold_tokens.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    this.brand = const BrandConfig(),
    required this.onContinue,
  });

  final BrandConfig brand;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 520;
    final topHeight = (size.height * (compact ? .43 : .46)).clamp(300.0, 430.0);

    return Scaffold(
      backgroundColor: GoldTokens.blackBase,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: _ExecutiveBackdrop(compact: compact),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topHeight,
            child: const ClipPath(
              clipper: _GoldDiagonalClipper(),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: GoldTokens.goldGradient),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            compact ? GoldTokens.space20 : GoldTokens.space32,
                        vertical:
                            compact ? GoldTokens.space20 : GoldTokens.space32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HeroCopy(compact: compact),
                          SizedBox(height: compact ? 42 : 58),
                          Center(
                              child: _LogoMark(brandName: brand.displayName)),
                          SizedBox(height: compact ? 72 : 108),
                          _FooterAction(
                            compact: compact,
                            brandName: brand.displayName,
                            onContinue: onContinue,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 320 : 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome',
            style: GoldTokens.displayLarge.copyWith(
              color: GoldTokens.blackBase,
              fontSize: compact ? 42 : 56,
            ),
          ),
          const SizedBox(height: GoldTokens.space8),
          Text(
            'To the world of executive mobility',
            style: GoldTokens.body.copyWith(
              color: Colors.black.withValues(alpha: .62),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.brandName});

  final String brandName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$brandName logo',
      child: Container(
        width: 138,
        height: 138,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: GoldTokens.blackElevated,
          border: Border.all(
            color: GoldTokens.goldPrimary.withValues(alpha: .38),
          ),
          boxShadow: [
            BoxShadow(
              color: GoldTokens.goldPrimary.withValues(alpha: .22),
              blurRadius: 42,
              spreadRadius: 3,
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: GoldTokens.goldGradient,
          ),
          child: Center(
            child: Text(
              'G',
              style: GoldTokens.displayLarge.copyWith(
                color: GoldTokens.blackBase,
                fontSize: 62,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.compact,
    required this.brandName,
    required this.onContinue,
  });

  final bool compact;
  final String brandName;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding:
          EdgeInsets.all(compact ? GoldTokens.space16 : GoldTokens.space20),
      decoration: BoxDecoration(
        color: GoldTokens.blackElevated.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(GoldTokens.radiusCard),
        border: Border.all(color: GoldTokens.lineSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'We are here to make your trip memorable.',
              style: GoldTokens.body.copyWith(color: GoldTokens.textPrimary),
            ),
          ),
          const SizedBox(width: GoldTokens.space16),
          Tooltip(
            message: 'Continue to $brandName',
            child: SizedBox.square(
              dimension: compact ? 54 : 60,
              child: FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  backgroundColor: GoldTokens.goldPrimary,
                  foregroundColor: GoldTokens.blackBase,
                ),
                child: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExecutiveBackdrop extends StatefulWidget {
  const _ExecutiveBackdrop({required this.compact});

  final bool compact;

  @override
  State<_ExecutiveBackdrop> createState() => _ExecutiveBackdropState();
}

class _ExecutiveBackdropState extends State<_ExecutiveBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
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
      builder: (context, _) {
        return CustomPaint(
          painter: _ExecutiveBackdropPainter(
            progress: _controller.value,
            compact: widget.compact,
          ),
        );
      },
    );
  }
}

class _ExecutiveBackdropPainter extends CustomPainter {
  const _ExecutiveBackdropPainter({
    required this.progress,
    required this.compact,
  });

  final double progress;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final skylineTop = size.height * (compact ? .62 : .58);

    paint.shader = GoldTokens.blackGradient.createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    _drawNetwork(canvas, size, progress);
    _drawCity(canvas, size, skylineTop);
  }

  void _drawNetwork(Canvas canvas, Size size, double progress) {
    final nodePaint = Paint()
      ..color = GoldTokens.goldPrimary.withValues(alpha: .22)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = GoldTokens.goldPrimary.withValues(alpha: .10)
      ..strokeWidth = 1;

    final points = List<Offset>.generate(12, (index) {
      final x = size.width * ((index % 4) + .55) / 4.8;
      final baseY = size.height * (.50 + (index ~/ 4) * .07);
      final wave = math.sin(progress * math.pi * 2 + index) * 6;
      return Offset(x, baseY + wave);
    });

    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }
    for (final point in points) {
      canvas.drawCircle(point, 2.2, nodePaint);
    }
  }

  void _drawCity(Canvas canvas, Size size, double skylineTop) {
    final paint = Paint()..color = GoldTokens.blackBase.withValues(alpha: .96);
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, skylineTop + 70);

    final widths = [34.0, 46.0, 28.0, 58.0, 42.0, 72.0, 38.0, 50.0];
    var x = 0.0;
    var index = 0;
    while (x < size.width + 80) {
      final width = widths[index % widths.length];
      final height = 68 + (index % 5) * 26.0;
      path
        ..lineTo(x, skylineTop + 70 - height)
        ..lineTo(x + width, skylineTop + 70 - height)
        ..lineTo(x + width, skylineTop + 70);
      x += width;
      index++;
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ExecutiveBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.compact != compact;
  }
}

class _GoldDiagonalClipper extends CustomClipper<Path> {
  const _GoldDiagonalClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * .74)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
