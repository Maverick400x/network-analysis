import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/network_metric_model.dart';

/// Continuously probes the network to keep ping, jitter and packet
/// loss "live" ("Continuously" in the metrics table), and polls
/// signal strength on a slower cadence ("Periodically").
///
/// On native platforms, ping is measured as a TCP-connect round trip
/// to a well-known, highly available host rather than raw ICMP,
/// since ICMP sockets require elevated privileges/native code on
/// mobile platforms. Raw sockets don't exist in a browser sandbox at
/// all, so the web build instead times a tiny HTTP request against a
/// CORS-friendly endpoint as its ping proxy.
class NetworkMonitorService {
  static const Duration _signalStrengthInterval = Duration(seconds: 10);
  static const Duration _probeTimeout = Duration(seconds: 2);
  static const String _probeHost = '8.8.8.8';
  static const int _probePort = 53;

  /// How often to probe. Configurable from the settings sheet;
  /// defaults to once a second.
  final Duration probeInterval;

  NetworkMonitorService({this.probeInterval = const Duration(seconds: 1)});

  // Cloudflare's speed-test endpoint sends permissive CORS headers,
  // so it doubles as a lightweight, browser-safe ping target.
  static final Uri _webProbeUri =
      Uri.parse('https://speed.cloudflare.com/__down?bytes=1');

  static const MethodChannel _platformChannel =
      MethodChannel('network_analyzer/signal');

  Timer? _probeTimer;
  Timer? _signalTimer;
  final List<PingSample> _history = [];

  final StreamController<NetworkMetrics> _controller =
      StreamController<NetworkMetrics>.broadcast();

  NetworkMetrics _current = NetworkMetrics.initial();

  Stream<NetworkMetrics> get metricsStream => _controller.stream;
  NetworkMetrics get current => _current;

  void start() {
    if (_probeTimer != null) return; // already running

    _probeTimer = Timer.periodic(probeInterval, (_) => _probeOnce());
    _signalTimer = Timer.periodic(
      _signalStrengthInterval,
      (_) => _pollSignalStrength(),
    );

    // Kick off an immediate probe rather than waiting a full interval.
    _probeOnce();
    _pollSignalStrength();
  }

  void stop() {
    _probeTimer?.cancel();
    _signalTimer?.cancel();
    _probeTimer = null;
    _signalTimer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  Future<void> _probeOnce() async {
    final sample = kIsWeb ? await _webProbe() : await _nativeProbe();

    _history.add(sample);
    if (_history.length > NetworkMetrics.maxHistory) {
      _history.removeAt(0);
    }

    _emitMetrics();
  }

  Future<PingSample> _nativeProbe() async {
    final stopwatch = Stopwatch()..start();

    try {
      final socket = await Socket.connect(
        _probeHost,
        _probePort,
        timeout: _probeTimeout,
      );
      stopwatch.stop();
      socket.destroy();

      return PingSample(
        timestamp: DateTime.now(),
        success: true,
        latencyMs: stopwatch.elapsedMicroseconds / 1000.0,
      );
    } catch (_) {
      stopwatch.stop();
      return PingSample(timestamp: DateTime.now(), success: false);
    }
  }

  Future<PingSample> _webProbe() async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await http
          .get(_webProbeUri)
          .timeout(_probeTimeout);
      stopwatch.stop();

      return PingSample(
        timestamp: DateTime.now(),
        success: response.statusCode >= 200 && response.statusCode < 400,
        latencyMs: stopwatch.elapsedMicroseconds / 1000.0,
      );
    } catch (_) {
      stopwatch.stop();
      return PingSample(timestamp: DateTime.now(), success: false);
    }
  }

  Future<void> _pollSignalStrength() async {
    int? dbm;

    try {
      final result = await _platformChannel.invokeMethod<int>(
        'getSignalStrengthDbm',
      );
      dbm = result;
    } on MissingPluginException {
      // No native implementation registered for this platform build.
      // Signal strength simply reports as unavailable ("N/A") in the
      // UI rather than crashing the app.
      dbm = null;
    } catch (_) {
      dbm = null;
    }

    _current = _current.copyWith(
      signalStrengthDbm: dbm,
      clearSignalStrength: dbm == null,
    );
    _controller.add(_current);
  }

  void _emitMetrics() {
    final successful = _history
        .where((s) => s.success && s.latencyMs != null)
        .toList();

    final latestPing = successful.isNotEmpty ? successful.last.latencyMs : null;

    double? jitter;
    if (successful.length >= 2) {
      var diffSum = 0.0;
      for (var i = 1; i < successful.length; i++) {
        diffSum += (successful[i].latencyMs! - successful[i - 1].latencyMs!)
            .abs();
      }
      jitter = diffSum / (successful.length - 1);
    }

    double? packetLoss;
    if (_history.isNotEmpty) {
      final failures = _history.where((s) => !s.success).length;
      packetLoss = (failures / _history.length) * 100.0;
    }

    _current = _current.copyWith(
      pingMs: latestPing,
      jitterMs: jitter,
      packetLossPercent: packetLoss,
      pingHistory: List.unmodifiable(_history),
    );

    _controller.add(_current);
  }
}
