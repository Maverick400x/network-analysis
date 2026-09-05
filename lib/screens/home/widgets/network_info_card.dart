import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/network_monitor_provider.dart';
import '../../../providers/network_provider.dart';

class NetworkInfoCard extends ConsumerWidget {
  const NetworkInfoCard({super.key});

  // Browsers never expose these to page scripts, on any platform —
  // no plugin can fill this in on web, so we explain rather than
  // showing a bare, unexplained dash.
  static const String _webUnavailable = 'Not available in browser';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkAsync = ref.watch(networkProvider);
    final metricsAsync = ref.watch(networkMonitorProvider);

    final network = networkAsync.value;
    final signalDbm = metricsAsync.value?.signalStrengthDbm;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Network Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Local IP',
              value: network?.localIp ?? (kIsWeb ? _webUnavailable : '—'),
              isPlaceholder: network?.localIp == null,
            ),
            _InfoRow(
              label: 'Public IP',
              value: network?.publicIp ?? '—',
              isPlaceholder: network?.publicIp == null,
            ),
            _InfoRow(
              label: 'Wi-Fi Name',
              value: network?.wifiName ?? (kIsWeb ? _webUnavailable : '—'),
              isPlaceholder: network?.wifiName == null,
            ),
            _InfoRow(
              label: 'ISP',
              value: network?.isp ?? '—',
              isPlaceholder: network?.isp == null,
            ),
            _InfoRow(
              label: 'Signal Strength',
              value: signalDbm != null
                  ? '$signalDbm dBm'
                  : (kIsWeb ? _webUnavailable : 'N/A'),
              isPlaceholder: signalDbm == null,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPlaceholder;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isPlaceholder ? FontWeight.w400 : FontWeight.w600,
                fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                color: isPlaceholder ? Colors.grey : null,
                fontSize: isPlaceholder ? 12.5 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
