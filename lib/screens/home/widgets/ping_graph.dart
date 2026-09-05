import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/network_metric_model.dart';
import '../../../providers/network_monitor_provider.dart';
import '../../../theme/app_theme.dart';

/// Continuously-updating line graph of ping (RTT), with jitter shown
/// as a supporting stat ("Continuously" in the metrics table).
class PingGraph extends ConsumerWidget {
  const PingGraph({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(networkMonitorProvider);
    final metrics = metricsAsync.value ?? NetworkMetrics.initial();
    final samples = metrics.successfulSamples;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Ping',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  metrics.pingMs != null
                      ? '${metrics.pingMs!.toStringAsFixed(0)} ms'
                      : '— ms',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                Text(
                  metrics.jitterMs != null
                      ? 'Jitter ${metrics.jitterMs!.toStringAsFixed(1)} ms'
                      : 'Jitter — ms',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: samples.length >= 2
                  ? CustomPaint(
                      painter: _LinePainter(
                        samples: samples,
                        color: AppTheme.download,
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Collecting samples…',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<PingSample> samples;
  final Color color;

  _LinePainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final values = samples.map((s) => s.latencyMs!).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b) * 1.2;
    final minVal = values.reduce((a, b) => a < b ? a : b) * 0.8;
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

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

    for (var i = 0; i < values.length; i++) {
      final x = samples.length == 1
          ? 0.0
          : (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minVal) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.samples.length != samples.length;
  }
}
