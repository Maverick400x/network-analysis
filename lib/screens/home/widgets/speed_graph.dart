import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/speed_test_model.dart';
import '../../../providers/network_provider.dart';
import '../../../theme/app_theme.dart';

/// Live line graph of download/upload throughput, populated only
/// while a speed test is actively running ("During speed test").
class SpeedGraph extends ConsumerWidget {
  const SpeedGraph({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speedState = ref.watch(speedTestProvider);
    final hasData = speedState.downloadSamples.isNotEmpty ||
        speedState.uploadSamples.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Speed Over Time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _Legend(color: AppTheme.download, label: 'Download'),
                const SizedBox(width: 12),
                _Legend(color: AppTheme.upload, label: 'Upload'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              width: double.infinity,
              child: hasData
                  ? CustomPaint(
                      painter: _DualLinePainter(
                        primary: speedState.downloadSamples,
                        secondary: speedState.uploadSamples,
                        primaryColor: AppTheme.download,
                        secondaryColor: AppTheme.upload,
                      ),
                    )
                  : const _EmptyState(
                      message: 'Run a network test to see the live graph',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }
}

class _DualLinePainter extends CustomPainter {
  final List<SpeedSample> primary;
  final List<SpeedSample> secondary;
  final Color primaryColor;
  final Color secondaryColor;

  _DualLinePainter({
    required this.primary,
    required this.secondary,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxMbps = _maxValue();
    if (maxMbps <= 0) return;

    final maxElapsedMs = _maxElapsedMs();
    if (maxElapsedMs <= 0) return;

    _drawSeries(canvas, size, primary, maxMbps, maxElapsedMs, primaryColor);
    _drawSeries(canvas, size, secondary, maxMbps, maxElapsedMs, secondaryColor);
  }

  double _maxValue() {
    final all = [...primary, ...secondary].map((s) => s.mbps);
    if (all.isEmpty) return 0;
    return all.reduce((a, b) => a > b ? a : b) * 1.15;
  }

  double _maxElapsedMs() {
    final all = [...primary, ...secondary].map(
      (s) => s.elapsed.inMilliseconds.toDouble(),
    );
    if (all.isEmpty) return 0;
    return all.reduce((a, b) => a > b ? a : b);
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<SpeedSample> samples,
    double maxMbps,
    double maxElapsedMs,
    Color color,
  ) {
    if (samples.length < 2) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < samples.length; i++) {
      final x =
          (samples[i].elapsed.inMilliseconds / maxElapsedMs) * size.width;
      final y = size.height - (samples[i].mbps / maxMbps) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(
      (samples.last.elapsed.inMilliseconds / maxElapsedMs) * size.width,
      size.height,
    );
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _DualLinePainter oldDelegate) {
    return oldDelegate.primary.length != primary.length ||
        oldDelegate.secondary.length != secondary.length;
  }
}
