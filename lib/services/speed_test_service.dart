import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/speed_test_model.dart';

typedef SpeedSampleCallback = void Function(SpeedSample sample);

/// Runs an actual network speed test (download / upload / ping),
/// reporting progressive [SpeedSample]s while each phase is running
/// so the UI can draw a live graph ("During speed test" in the
/// metrics table). Uses Cloudflare's public speed-test endpoints,
/// which require no API key.
class SpeedTestService {
  static const String _downloadUrl =
      'https://speed.cloudflare.com/__down?bytes=26214400'; // 25 MB
  static const String _uploadUrl = 'https://speed.cloudflare.com/__up';
  static const String _pingHost = 'speed.cloudflare.com';

  /// TCP-connect latency, used both as the speed test's ping figure
  /// and reused by the continuous monitor for a "quick" reading.
  Future<double?> testPing({int samples = 4}) async {
    final latencies = <double>[];

    for (var i = 0; i < samples; i++) {
      final stopwatch = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          _pingHost,
          443,
          timeout: const Duration(seconds: 2),
        );
        stopwatch.stop();
        socket.destroy();
        latencies.add(stopwatch.elapsedMicroseconds / 1000.0);
      } catch (_) {
        stopwatch.stop();
      }

      if (i != samples - 1) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    if (latencies.isEmpty) return null;
    return latencies.reduce((a, b) => a + b) / latencies.length;
  }

  Future<double> testDownloadSpeed({SpeedSampleCallback? onSample}) async {
    final client = http.Client();
    final stopwatch = Stopwatch()..start();
    var totalBytes = 0;
    var lastSampleBytes = 0;
    var lastSampleTime = Duration.zero;

    try {
      final request = http.Request('GET', Uri.parse(_downloadUrl));
      final response = await client.send(request).timeout(
            const Duration(seconds: 15),
          );

      await for (final chunk in response.stream) {
        totalBytes += chunk.length;
        final elapsed = stopwatch.elapsed;

        // Emit a sample roughly every 200ms based on bytes received
        // since the last sample, converted to an instantaneous Mbps.
        if (elapsed - lastSampleTime >= const Duration(milliseconds: 200)) {
          final intervalSeconds =
              (elapsed - lastSampleTime).inMilliseconds / 1000.0;
          final intervalBytes = totalBytes - lastSampleBytes;

          if (intervalSeconds > 0) {
            final mbps = (intervalBytes * 8) / intervalSeconds / 1000000.0;
            onSample?.call(SpeedSample(elapsed: elapsed, mbps: mbps));
          }

          lastSampleBytes = totalBytes;
          lastSampleTime = elapsed;
        }

        // Cap the test once we have enough data for a stable reading.
        if (stopwatch.elapsed > const Duration(seconds: 12)) break;
      }
    } catch (_) {
      // Fall through and compute whatever we managed to gather.
    } finally {
      stopwatch.stop();
      client.close();
    }

    final seconds = stopwatch.elapsedMilliseconds / 1000.0;
    if (seconds <= 0 || totalBytes <= 0) return 0;

    return (totalBytes * 8) / seconds / 1000000.0; // Mbps
  }

  Future<double> testUploadSpeed({SpeedSampleCallback? onSample}) async {
    final random = Random();
    const chunkSize = 65536; // 64 KB per chunk
    const totalChunks = 60; // ~3.75 MB uploaded
    final chunk = Uint8List.fromList(
      List<int>.generate(chunkSize, (_) => random.nextInt(256)),
    );

    final client = http.Client();
    final stopwatch = Stopwatch()..start();
    var bytesSent = 0;
    var lastSampleBytes = 0;
    var lastSampleTime = Duration.zero;

    final controller = StreamController<List<int>>();
    final request = http.StreamedRequest('POST', Uri.parse(_uploadUrl));
    request.headers['Content-Type'] = 'application/octet-stream';
    request.sink.addStream(controller.stream);

    unawaited(() async {
      for (var i = 0; i < totalChunks; i++) {
        if (controller.isClosed) break;
        controller.add(chunk);
        bytesSent += chunk.length;

        final elapsed = stopwatch.elapsed;
        if (elapsed - lastSampleTime >= const Duration(milliseconds: 200)) {
          final intervalSeconds =
              (elapsed - lastSampleTime).inMilliseconds / 1000.0;
          final intervalBytes = bytesSent - lastSampleBytes;

          if (intervalSeconds > 0) {
            final mbps = (intervalBytes * 8) / intervalSeconds / 1000000.0;
            onSample?.call(SpeedSample(elapsed: elapsed, mbps: mbps));
          }

          lastSampleBytes = bytesSent;
          lastSampleTime = elapsed;
        }
      }
      await controller.close();
    }());

    try {
      final response = await client.send(request).timeout(
            const Duration(seconds: 15),
          );
      await response.stream.drain().timeout(const Duration(seconds: 15));
    } catch (_) {
      // Ignore transport errors; we still measured how fast we could
      // hand bytes to the socket, which is a reasonable proxy.
    } finally {
      stopwatch.stop();
      client.close();
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    final seconds = stopwatch.elapsedMilliseconds / 1000.0;
    if (seconds <= 0 || bytesSent <= 0) return 0;

    return (bytesSent * 8) / seconds / 1000000.0; // Mbps
  }
}
