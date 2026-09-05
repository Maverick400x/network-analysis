import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/network_provider.dart';

class DeviceInfoCard extends ConsumerWidget {
  const DeviceInfoCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(networkProvider).value?.device;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'System',
              value: device?.system ?? '—',
            ),
            _InfoRow(
              label: 'OS Version',
              value: device?.osVersion ?? '—',
            ),
            _InfoRow(
              label: 'Device Model',
              value: device?.deviceModel ?? '—',
            ),
            _InfoRow(
              label: 'Manufacturer',
              value: device?.manufacturer ?? '—',
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

  const _InfoRow({
    required this.label,
    required this.value,
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
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
