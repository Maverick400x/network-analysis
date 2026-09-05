import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/network_metric_model.dart';
import '../services/network_monitor_service.dart';
import 'network_provider.dart' show pingIntervalSecondsProvider;

final networkMonitorServiceProvider = Provider<NetworkMonitorService>((ref) {
  final intervalSeconds = ref.watch(pingIntervalSecondsProvider);

  final service = NetworkMonitorService(
    probeInterval: Duration(seconds: intervalSeconds),
  );
  service.start();

  ref.onDispose(service.dispose);

  return service;
});

/// Live ping / jitter / packet loss / signal strength, used by the
/// ping graph, packet loss graph and the network info card. Backed
/// by a broadcast stream so every listener sees the same rolling
/// history without re-triggering probes.
final networkMonitorProvider = StreamProvider<NetworkMetrics>((ref) {
  final service = ref.watch(networkMonitorServiceProvider);
  return service.metricsStream.map((_) => service.current);
});
