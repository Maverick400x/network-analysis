/// A single continuous ping probe result.
class PingSample {
  final DateTime timestamp;
  final double? latencyMs;
  final bool success;

  const PingSample({
    required this.timestamp,
    required this.success,
    this.latencyMs,
  });
}

/// Rolling window of continuously-collected network health metrics:
/// ping, jitter and packet loss update on every probe; signal
/// strength is refreshed on a slower, periodic cadence.
class NetworkMetrics {
  static const int maxHistory = 60;

  final double? pingMs;
  final double? jitterMs;
  final double? packetLossPercent;
  final int? signalStrengthDbm;
  final List<PingSample> pingHistory;

  const NetworkMetrics({
    this.pingMs,
    this.jitterMs,
    this.packetLossPercent,
    this.signalStrengthDbm,
    this.pingHistory = const [],
  });

  factory NetworkMetrics.initial() => const NetworkMetrics();

  NetworkMetrics copyWith({
    double? pingMs,
    double? jitterMs,
    double? packetLossPercent,
    int? signalStrengthDbm,
    List<PingSample>? pingHistory,
    bool clearSignalStrength = false,
  }) {
    return NetworkMetrics(
      pingMs: pingMs ?? this.pingMs,
      jitterMs: jitterMs ?? this.jitterMs,
      packetLossPercent: packetLossPercent ?? this.packetLossPercent,
      signalStrengthDbm: clearSignalStrength
          ? null
          : (signalStrengthDbm ?? this.signalStrengthDbm),
      pingHistory: pingHistory ?? this.pingHistory,
    );
  }

  /// Successful latency samples only, oldest first, for graphing.
  List<PingSample> get successfulSamples =>
      pingHistory.where((s) => s.success && s.latencyMs != null).toList();
}
