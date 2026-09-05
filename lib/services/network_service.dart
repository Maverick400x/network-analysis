import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

/// Handles everything that should update "on network change":
/// connection type, local IP, Wi-Fi name and BSSID.
///
/// Note: local IP / Wi-Fi name / BSSID are fundamentally unavailable
/// in a browser sandbox (Flutter web) regardless of plugin — browsers
/// don't expose that information to page scripts. Each getter below
/// simply returns null there instead of throwing, so it degrades
/// gracefully rather than taking down the whole provider.
class NetworkService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final Connectivity _connectivity = Connectivity();

  // Same permissive-CORS endpoint the monitor uses for its web ping,
  // reused here purely as a reachability probe.
  static final Uri _reachabilityProbeUri =
      Uri.parse('https://speed.cloudflare.com/__down?bytes=1');

  Future<String?> getLocalIp() async {
    try {
      return await _networkInfo.getWifiIP();
    } catch (_) {
      return null;
    }
  }

  Future<String?> getWifiName() async {
    try {
      final name = await _networkInfo.getWifiName();
      if (name == null) return null;
      // Some platforms wrap the SSID in quotes, e.g. "MyNetwork".
      return name.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  Future<String?> getWifiBssid() async {
    try {
      return await _networkInfo.getWifiBSSID();
    } catch (_) {
      return null;
    }
  }

  Future<String> getConnectionType() async {
    String label;

    try {
      final result = await _connectivity.checkConnectivity();
      label = _labelFor(result);
    } catch (_) {
      label = 'Unknown';
    }

    // Browsers largely don't implement the Network Information API,
    // so connectivity_plus's web build often reports "none"/"unknown"
    // even while genuinely online. Confirm with an actual reachability
    // probe before telling the user they're disconnected.
    if (kIsWeb && (label == 'No Connection' || label == 'Unknown')) {
      final reachable = await _isReachable();
      if (reachable) return 'Online';
    }

    return label;
  }

  Future<bool> _isReachable() async {
    try {
      final response = await http
          .get(_reachabilityProbeUri)
          .timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  String _labelFor(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    }

    if (result.contains(ConnectivityResult.wifi)) {
      return 'Wi-Fi';
    }

    if (result.contains(ConnectivityResult.mobile)) {
      return 'Mobile Data';
    }

    if (result.contains(ConnectivityResult.vpn)) {
      return 'VPN';
    }

    if (result.contains(ConnectivityResult.bluetooth)) {
      return 'Bluetooth';
    }

    if (result.contains(ConnectivityResult.none)) {
      return 'No Connection';
    }

    return 'Unknown';
  }

  /// Fires every time the OS reports a connectivity change, so the
  /// provider can refresh connection type / local IP / Wi-Fi name
  /// (and trigger a periodic-field refresh too) without polling.
  Stream<String> get connectionTypeStream {
    return _connectivity.onConnectivityChanged
        .map(_labelFor)
        .handleError((_) {});
  }
}
