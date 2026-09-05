import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/network_provider.dart';
import '../../../theme/app_theme.dart';

class ConnectionCard extends ConsumerWidget {
  const ConnectionCard({super.key});

  IconData _iconFor(String connectionType) {
    switch (connectionType) {
      case 'Wi-Fi':
        return Icons.wifi_rounded;
      case 'Mobile Data':
        return Icons.signal_cellular_alt_rounded;
      case 'Ethernet':
        return Icons.settings_ethernet_rounded;
      case 'VPN':
        return Icons.vpn_lock_rounded;
      case 'No Connection':
        return Icons.wifi_off_rounded;
      case 'Online':
        return Icons.public_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkAsync = ref.watch(networkProvider);

    return networkAsync.when(
      loading: () => const _ConnectionCardShell(
        isConnected: false,
        connectionType: 'Checking…',
        icon: Icons.hourglass_top_rounded,
      ),
      error: (err, st) => const _ConnectionCardShell(
        isConnected: false,
        connectionType: 'Unknown',
        icon: Icons.error_outline_rounded,
      ),
      data: (network) => _ConnectionCardShell(
        isConnected: network.isConnected,
        connectionType: network.connectionType,
        icon: _iconFor(network.connectionType),
      ),
    );
  }
}

class _ConnectionCardShell extends StatelessWidget {
  final bool isConnected;
  final String connectionType;
  final IconData icon;

  const _ConnectionCardShell({
    required this.isConnected,
    required this.connectionType,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isConnected ? AppTheme.success : AppTheme.danger;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(icon, size: 26),
              ],
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Connection Type',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                connectionType,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
