import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/network_monitor_provider.dart';
import '../../../theme/app_theme.dart';

/// Continuously-updating bar graph of packet loss percentage
/// ("Continuously" in the metrics table). [NetworkMetrics] only
/// exposes the *current* rolling packet-loss reading, so this widget
/// keeps its own short trend history of that value for the graph.
class PacketLossGraph extends ConsumerStatefulWidget {
  const PacketLossGraph({super.key});

  @override
  ConsumerState<PacketLossGraph> createState() => _PacketLossGraphState();
}

class _PacketLossGraphState extends ConsumerState<PacketLossGraph> {
  static const int _maxPoints = 30;
  final List<double> _history = [];

  @override
  Widget build(BuildContext context) {
    ref.listen(networkMonitorProvider, (previous, next) {
      final percent = next.value?.packetLossPercent;
      if (percent == null) return;

      setState(() {
        _history.add(percent);
        if (_history.length > _maxPoints) {
          _history.removeAt(0);
        }
      });
    });

    final current = ref.watch(networkMonitorProvider).value
        ?.packetLossPercent;
    final color = _colorFor(current);

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
                  'Packet Loss',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  current != null ? '${current.toStringAsFixed(1)}%' : '—%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              width: double.infinity,
              child: _history.length >= 2
                  ? CustomPaint(
                      painter: _BarPainter(values: _history, barColor: color),
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

  Color _colorFor(double? percent) {
    if (percent == null) return Colors.grey;
    if (percent <= 1) return AppTheme.success;
    if (percent <= 5) return AppTheme.warning;
    return AppTheme.danger;
  }
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final Color barColor;

  _BarPainter({required this.values, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final maxVal = values.reduce((a, b) => a > b ? a : b).clamp(5.0, 100.0);

    final barPaint = Paint()..color = barColor.withOpacity(0.85);
    final barWidth = size.width / (values.length * 1.5);
    final gap = barWidth * 0.5;

    for (var i = 0; i < values.length; i++) {
      final x = i * (barWidth + gap);
      final barHeight = (values[i] / maxVal) * size.height;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            size.height - barHeight,
            barWidth,
            barHeight.clamp(1.5, size.height),
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) {
    final oldLast = oldDelegate.values.isEmpty ? null : oldDelegate.values.last;
    final newLast = values.isEmpty ? null : values.last;
    return oldDelegate.values.length != values.length || oldLast != newLast;
  }
}
