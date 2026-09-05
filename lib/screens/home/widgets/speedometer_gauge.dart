import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A classic 270°-sweep speedometer: colored arc, an animated needle
/// that eases toward the latest value, and a pulsing outer ring while
/// [isActive] (a test is currently measuring this value).
class SpeedometerGauge extends StatefulWidget {
  final double value;
  final double maxValue;
  final String label;
  final String unit;
  final Color color;
  final bool isActive;

  const SpeedometerGauge({
    super.key,
    required this.value,
    required this.maxValue,
    required this.label,
    required this.color,
    this.unit = 'Mbps',
    this.isActive = false,
  });

  @override
  State<SpeedometerGauge> createState() => _SpeedometerGaugeState();
}

class _SpeedometerGaugeState extends State<SpeedometerGauge>
    with TickerProviderStateMixin {
  late final AnimationController _needleController;
  late Animation<double> _needleAnimation;

  late final AnimationController _pulseController;

  double _displayedValue = 0;

  @override
  void initState() {
    super.initState();

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _needleAnimation = _buildNeedleTween(0, widget.value)
        .animate(CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic))
      ..addListener(() {
        setState(() => _displayedValue = _needleAnimation.value);
      });
    _needleController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isActive) _pulseController.repeat(reverse: true);
  }

  Tween<double> _buildNeedleTween(double begin, double end) {
    return Tween<double>(begin: begin, end: end);
  }

  @override
  void didUpdateWidget(covariant SpeedometerGauge oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value) {
      _needleAnimation = _buildNeedleTween(_displayedValue, widget.value)
          .animate(CurvedAnimation(
              parent: _needleController, curve: Curves.easeOutCubic))
        ..addListener(() {
          setState(() => _displayedValue = _needleAnimation.value);
        });
      _needleController
        ..reset()
        ..forward();
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _needleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(150, 100),
              painter: _GaugePainter(
                value: _displayedValue,
                maxValue: widget.maxValue,
                color: widget.color,
                pulse: widget.isActive ? _pulseController.value : 0,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          '${_displayedValue.toStringAsFixed(1)} ${widget.unit}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: widget.color,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isActive) ...[
              SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: widget.color,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  static const double _startAngle = math.pi * 0.75; // 135°
  static const double _sweepAngle = math.pi * 1.5; // 270°

  final double value;
  final double maxValue;
  final Color color;
  final double pulse; // 0..1, animates while a test is running

  _GaugePainter({
    required this.value,
    required this.maxValue,
    required this.color,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height) - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track background.
    final trackPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, trackPaint);

    // Colored progress arc (green -> amber -> red across the sweep).
    final fraction = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepAngle,
        colors: [color.withOpacity(0.55), color],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle * fraction, false, progressPaint);

    // Pulsing glow at the tip of the arc while a test is running.
    if (pulse > 0) {
      final tipAngle = _startAngle + _sweepAngle * fraction;
      final tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      final glowPaint = Paint()
        ..color = color.withOpacity(0.35 * (1 - pulse))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tip, 4 + pulse * 8, glowPaint);
    }

    // Needle.
    final needleAngle = _startAngle + _sweepAngle * fraction;
    final needleLength = radius - 14;
    final needleEnd = Offset(
      center.dx + needleLength * math.cos(needleAngle),
      center.dy + needleLength * math.sin(needleAngle),
    );
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    final hubPaint = Paint()..color = color;
    canvas.drawCircle(center, 5, hubPaint);
    canvas.drawCircle(center, 5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.pulse != pulse;
  }
}
