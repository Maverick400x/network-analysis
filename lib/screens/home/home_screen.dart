import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/speed_test_model.dart';
import '../../providers/network_provider.dart';
import 'widgets/connection_card.dart';
import 'widgets/speed_card.dart';
import 'widgets/network_info_card.dart';
import 'widgets/device_info_card.dart';
import 'widgets/speed_graph.dart';
import 'widgets/ping_graph.dart';
import 'widgets/packet_loss_graph.dart';
import 'widgets/settings_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasAutoRun = false;

  @override
  void initState() {
    super.initState();
    // Deferred to the next frame so the first build (and the
    // provider tree it depends on) is fully up before we kick off a
    // test — and so build() itself stays side-effect free.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoRun());
  }

  void _maybeAutoRun() {
    if (_hasAutoRun) return;
    if (!ref.read(autoRunSpeedTestOnLaunchProvider)) return;

    _hasAutoRun = true;
    ref.read(speedTestProvider.notifier).runTest();
  }

  @override
  Widget build(BuildContext context) {
    final speedState = ref.watch(speedTestProvider);
    final isTesting = speedState.status.isRunning;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Network Analyzer',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => showSettingsSheet(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(networkProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ConnectionCard(),
                const SizedBox(height: 16),
                const SpeedCard(),
                const SizedBox(height: 16),
                const SpeedGraph(),
                const SizedBox(height: 16),
                const PingGraph(),
                const SizedBox(height: 16),
                const PacketLossGraph(),
                const SizedBox(height: 16),
                const NetworkInfoCard(),
                const SizedBox(height: 16),
                const DeviceInfoCard(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: isTesting
                        ? null
                        : () => ref.read(speedTestProvider.notifier).runTest(),
                    icon: isTesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.speed_rounded),
                    label: Text(
                      isTesting
                          ? speedState.status.label.toUpperCase()
                          : 'RUN NETWORK TEST',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (speedState.status == SpeedTestStatus.failed &&
                    speedState.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Test failed: ${speedState.errorMessage}',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
