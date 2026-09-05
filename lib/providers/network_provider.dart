import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_info_model.dart';
import '../models/speed_test_model.dart';
import '../services/device_service.dart';
import '../services/network_service.dart';
import '../services/public_ip_service.dart';
import '../services/speed_test_service.dart';

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final networkServiceProvider = Provider<NetworkService>((ref) {
  return NetworkService();
});

final publicIpServiceProvider = Provider<PublicIpService>((ref) {
  return PublicIpService();
});

final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService();
});

final speedTestServiceProvider = Provider<SpeedTestService>((ref) {
  return SpeedTestService();
});

// ---------------------------------------------------------------------------
// User-adjustable settings (surfaced from the settings sheet)
// ---------------------------------------------------------------------------

/// Whether a speed test should kick off automatically the first time
/// the home screen is shown, instead of waiting for a manual tap.
final autoRunSpeedTestOnLaunchProvider =
    NotifierProvider<AutoRunSpeedTestNotifier, bool>(
        AutoRunSpeedTestNotifier.new);

class AutoRunSpeedTestNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// How often the continuous ping/jitter/packet-loss monitor probes,
/// in seconds.
final pingIntervalSecondsProvider =
    NotifierProvider<PingIntervalNotifier, int>(PingIntervalNotifier.new);

class PingIntervalNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void set(int value) => state = value;
}

// ---------------------------------------------------------------------------
// Connection / network info (mix of on-change and periodic fields)
// ---------------------------------------------------------------------------

/// How often the "Periodically" fields (public IP, ISP) are
/// refreshed when the network hasn't otherwise changed.
const Duration _periodicRefreshInterval = Duration(seconds: 30);

class NetworkState {
  final String connectionType;
  final String? localIp;
  final String? publicIp;
  final String? wifiName;
  final String? wifiBssid;
  final String? isp;

  final DeviceInfoModel? device;

  const NetworkState({
    this.connectionType = 'Unknown',
    this.localIp,
    this.publicIp,
    this.wifiName,
    this.wifiBssid,
    this.isp,
    this.device,
  });

  bool get isConnected =>
      connectionType != 'No Connection' && connectionType != 'Unknown';

  NetworkState copyWith({
    String? connectionType,
    String? localIp,
    String? publicIp,
    String? wifiName,
    String? wifiBssid,
    String? isp,
    DeviceInfoModel? device,
  }) {
    return NetworkState(
      connectionType: connectionType ?? this.connectionType,
      localIp: localIp ?? this.localIp,
      publicIp: publicIp ?? this.publicIp,
      wifiName: wifiName ?? this.wifiName,
      wifiBssid: wifiBssid ?? this.wifiBssid,
      isp: isp ?? this.isp,
      device: device ?? this.device,
    );
  }
}

final networkProvider =
    AsyncNotifierProvider<NetworkNotifier, NetworkState>(NetworkNotifier.new);

class NetworkNotifier extends AsyncNotifier<NetworkState> {
  late final NetworkService _networkService;
  late final PublicIpService _publicIpService;
  late final DeviceService _deviceService;

  StreamSubscription<String>? _connectivitySub;
  Timer? _periodicTimer;

  @override
  Future<NetworkState> build() async {
    _networkService = ref.read(networkServiceProvider);
    _publicIpService = ref.read(publicIpServiceProvider);
    _deviceService = ref.read(deviceServiceProvider);

    // Every field-loading helper below already catches its own
    // platform-specific errors (e.g. plugins unsupported on web), but
    // this outer guard makes sure one unexpected failure degrades a
    // handful of fields instead of nulling the whole screen.
    NetworkState result = const NetworkState();

    try {
      // Device info is static: fetch once and keep for the session.
      final device = await _deviceService.getDeviceInfo();
      result = await _loadOnChangeFields(
        const NetworkState(),
      ).then((s) => s.copyWith(device: device));
    } catch (_) {
      // Leave `result` at its defaults.
    }

    try {
      result = await _loadPeriodicFields(result);
    } catch (_) {
      // Leave public IP / ISP unset.
    }

    _startListeners();
    ref.onDispose(_stopListeners);

    return result;
  }

  void _startListeners() {
    // "On network change": react immediately instead of waiting for
    // the next periodic tick.
    _connectivitySub = _networkService.connectionTypeStream.listen((_) {
      _refreshOnChangeFields();
    });

    // "Periodically": public IP / ISP don't need a network-change
    // event to justify a refresh (the IP or ISP-reported route can
    // change without connectivity_plus noticing).
    _periodicTimer = Timer.periodic(_periodicRefreshInterval, (_) {
      _refreshPeriodicFields();
    });
  }

  void _stopListeners() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
  }

  Future<NetworkState> _loadOnChangeFields(NetworkState base) async {
    final results = await Future.wait([
      _networkService.getConnectionType(),
      _networkService.getLocalIp(),
      _networkService.getWifiName(),
      _networkService.getWifiBssid(),
    ]);

    return base.copyWith(
      connectionType: results[0] as String,
      localIp: results[1] as String?,
      wifiName: results[2] as String?,
      wifiBssid: results[3] as String?,
    );
  }

  Future<NetworkState> _loadPeriodicFields(NetworkState base) async {
    final ipInfo = await _publicIpService.getPublicIpInfo();

    return base.copyWith(
      publicIp: ipInfo.ip,
      isp: ipInfo.isp,
    );
  }

  Future<void> _refreshOnChangeFields() async {
    final previous = state.value;
    if (previous == null) return;

    final updated = await _loadOnChangeFields(previous);
    state = AsyncData(updated);
  }

  Future<void> _refreshPeriodicFields() async {
    final previous = state.value;
    if (previous == null) return;

    final updated = await _loadPeriodicFields(previous);
    state = AsyncData(updated);
  }

  /// Manual full refresh, e.g. from a pull-to-refresh gesture.
  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final device = await _deviceService.getDeviceInfo();
      final onChange = await _loadOnChangeFields(
        const NetworkState(),
      ).then((s) => s.copyWith(device: device));
      return _loadPeriodicFields(onChange);
    });
  }
}

// ---------------------------------------------------------------------------
// Speed test (download / upload update "During speed test")
// ---------------------------------------------------------------------------

final speedTestProvider =
    NotifierProvider<SpeedTestNotifier, SpeedTestState>(SpeedTestNotifier.new);

class SpeedTestNotifier extends Notifier<SpeedTestState> {
  late final SpeedTestService _service;

  @override
  SpeedTestState build() {
    _service = ref.read(speedTestServiceProvider);
    return const SpeedTestState();
  }

  Future<void> runTest() async {
    if (state.status.isRunning) return;

    state = const SpeedTestState(status: SpeedTestStatus.testingPing);

    try {
      final ping = await _service.testPing() ?? 0;

      state = state.copyWith(
        status: SpeedTestStatus.testingDownload,
        downloadSamples: const [],
      );

      final download = await _service.testDownloadSpeed(
        onSample: (sample) {
          state = state.copyWith(
            downloadSamples: [...state.downloadSamples, sample],
          );
        },
      );

      state = state.copyWith(
        status: SpeedTestStatus.testingUpload,
        uploadSamples: const [],
      );

      final upload = await _service.testUploadSpeed(
        onSample: (sample) {
          state = state.copyWith(
            uploadSamples: [...state.uploadSamples, sample],
          );
        },
      );

      state = state.copyWith(
        status: SpeedTestStatus.completed,
        lastResult: SpeedTestResult(
          downloadMbps: download,
          uploadMbps: upload,
          pingMs: ping,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      state = state.copyWith(
        status: SpeedTestStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }
}
