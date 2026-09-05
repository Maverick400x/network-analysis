import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/network_provider.dart';

/// Opens the app's settings as a modal bottom sheet. Call this from
/// the gear icon instead of leaving it wired to a no-op.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoRun = ref.watch(autoRunSpeedTestOnLaunchProvider);
    final pingInterval = ref.watch(pingIntervalSecondsProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-run speed test on launch'),
              subtitle: const Text(
                'Start a download/upload test automatically each time the app opens',
              ),
              value: autoRun,
              onChanged: (value) => ref
                  .read(autoRunSpeedTestOnLaunchProvider.notifier)
                  .set(value),
            ),
            const Divider(height: 24),
            const Text(
              'Ping probe interval',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'How often ping, jitter and packet loss are re-measured',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 2, 3, 5].map((seconds) {
                final selected = pingInterval == seconds;
                return ChoiceChip(
                  label: Text('${seconds}s'),
                  selected: selected,
                  onSelected: (_) => ref
                      .read(pingIntervalSecondsProvider.notifier)
                      .set(seconds),
                );
              }).toList(),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.refresh_rounded),
              title: const Text('Refresh network info now'),
              subtitle: const Text(
                'Re-check connection, public IP and ISP immediately',
              ),
              onTap: () {
                ref.read(networkProvider.notifier).refresh();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
