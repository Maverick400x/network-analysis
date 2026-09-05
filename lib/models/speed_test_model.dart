enum SpeedTestStatus {
  idle,
  testingPing,
  testingDownload,
  testingUpload,
  completed,
  failed,
}

extension SpeedTestStatusLabel on SpeedTestStatus {
  String get label {
    switch (this) {
      case SpeedTestStatus.idle:
        return 'Idle';
      case SpeedTestStatus.testingPing:
        return 'Testing Ping…';
      case SpeedTestStatus.testingDownload:
        return 'Testing Download…';
      case SpeedTestStatus.testingUpload:
        return 'Testing Upload…';
      case SpeedTestStatus.completed:
        return 'Completed';
      case SpeedTestStatus.failed:
        return 'Failed';
    }
  }

  bool get isRunning =>
      this == SpeedTestStatus.testingPing ||
      this == SpeedTestStatus.testingDownload ||
      this == SpeedTestStatus.testingUpload;
}

/// A single progressive throughput sample captured *while* a speed
/// test is running, used to draw the live speed graph.
class SpeedSample {
  final Duration elapsed;
  final double mbps;

  const SpeedSample({required this.elapsed, required this.mbps});
}

/// Final result of one completed speed test run.
class SpeedTestResult {
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;
  final DateTime timestamp;

  const SpeedTestResult({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.pingMs,
    required this.timestamp,
  });
}

/// Full state of the speed test flow, including in-progress samples
/// so the UI can render a live-updating graph during the test.
class SpeedTestState {
  final SpeedTestStatus status;
  final SpeedTestResult? lastResult;
  final List<SpeedSample> downloadSamples;
  final List<SpeedSample> uploadSamples;
  final String? errorMessage;

  const SpeedTestState({
    this.status = SpeedTestStatus.idle,
    this.lastResult,
    this.downloadSamples = const [],
    this.uploadSamples = const [],
    this.errorMessage,
  });

  SpeedTestState copyWith({
    SpeedTestStatus? status,
    SpeedTestResult? lastResult,
    List<SpeedSample>? downloadSamples,
    List<SpeedSample>? uploadSamples,
    String? errorMessage,
  }) {
    return SpeedTestState(
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
      downloadSamples: downloadSamples ?? this.downloadSamples,
      uploadSamples: uploadSamples ?? this.uploadSamples,
      errorMessage: errorMessage,
    );
  }
}
