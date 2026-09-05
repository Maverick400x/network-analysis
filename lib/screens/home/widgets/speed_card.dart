import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/speed_test_model.dart';
import '../../../providers/network_provider.dart';
import '../../../theme/app_theme.dart';
import 'speedometer_gauge.dart';

class SpeedCard extends ConsumerWidget {
  const SpeedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speedState = ref.watch(speedTestProvider);
    final result = speedState.lastResult;

    final download = _liveOrFinalValue(
      status: speedState.status,
      phase: SpeedTestStatus.testingDownload,
      samples: speedState.downloadSamples,
      finalValue: result?.downloadMbps,
    ) ?? 0;

    final upload = _liveOrFinalValue(
      status: speedState.status,
      phase: SpeedTestStatus.testingUpload,
      samples: speedState.uploadSamples,
      finalValue: result?.uploadMbps,
    ) ?? 0;

    // Scale each gauge to whatever's largest recently seen, so the
    // needle doesn't peg at max on typical home connections.
    final downloadMax = _niceMax(download);
    final uploadMax = _niceMax(upload);

    final isPinging = speedState.status == SpeedTestStatus.testingPing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Network Speed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (speedState.status.isRunning)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        speedState.status.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (isPinging)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: _PulsingPing(),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SpeedometerGauge(
                    value: download,
                    maxValue: downloadMax,
                    label: 'Download',
                    color: AppTheme.download,
                    isActive: speedState.status == SpeedTestStatus.testingDownload,
                  ),
                  SpeedometerGauge(
                    value: upload,
                    maxValue: uploadMax,
                    label: 'Upload',
                    color: AppTheme.upload,
                    isActive: speedState.status == SpeedTestStatus.testingUpload,
                  ),
                ],
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.timer_outlined,
                    value: result != null
                        ? '${result.pingMs.toStringAsFixed(0)} ms'
                        : '— ms',
                    label: 'Ping',
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.grey.shade300),
                Expanded(
                  child: _StatItem(
                    icon: Icons.access_time_rounded,
                    value: result != null
                        ? _formatTimestamp(result.timestamp)
                        : '—',
                    label: 'Last tested',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _niceMax(double value) {
    if (value <= 20) return 25;
    if (value <= 50) return 60;
    if (value <= 100) return 120;
    if (value <= 250) return 300;
    if (value <= 500) return 600;
    return (value * 1.25).ceilToDouble();
  }

  String _formatTimestamp(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// While a phase is actively running, prefer the latest live sample
  /// so the number ticks in step with the graph; once finished, fall
  /// back to the settled final result.
  double? _liveOrFinalValue({
    required SpeedTestStatus status,
    required SpeedTestStatus phase,
    required List<SpeedSample> samples,
    required double? finalValue,
  }) {
    if (status == phase && samples.isNotEmpty) {
      return samples.last.mbps;
    }
    return finalValue;
  }
}

/// Shown while the ping phase runs, before there's any throughput
/// data yet for the gauges to display.
class _PulsingPing extends StatefulWidget {
  const _PulsingPing();

  @override
  State<_PulsingPing> createState() => _PulsingPingState();
}

class _PulsingPingState extends State<_PulsingPing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

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
        final scale = 0.9 + (_controller.value * 0.25);
        return Opacity(
          opacity: 0.5 + (_controller.value * 0.5),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Icon(Icons.wifi_tethering_rounded, size: 36, color: AppTheme.download),
          const SizedBox(height: 8),
          const Text(
            'Measuring latency…',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}
