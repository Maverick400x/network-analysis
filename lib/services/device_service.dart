import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import '../models/device_info_model.dart';

/// Device identity never changes during a session, so this is only
/// ever called once by the provider ("Static" in the metrics table).
///
/// Deliberately avoids `dart:io`'s `Platform.isAndroid`/`isIOS`,
/// which throw when running on web — `defaultTargetPlatform` and
/// `kIsWeb` are safe on every platform Flutter targets.
class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<DeviceInfoModel> getDeviceInfo() async {
    try {
      if (kIsWeb) {
        return await _getWebInfo();
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return await _getAndroidInfo();
        case TargetPlatform.iOS:
          return await _getIosInfo();
        default:
          return _getDesktopInfo();
      }
    } catch (_) {
      return DeviceInfoModel.unknown();
    }
  }

  Future<DeviceInfoModel> _getAndroidInfo() async {
    final info = await _deviceInfo.androidInfo;

    return DeviceInfoModel(
      system: 'Android',
      osVersion: info.version.release,
      deviceModel: info.model,
      manufacturer: info.manufacturer,
      isPhysicalDevice: info.isPhysicalDevice,
    );
  }

  Future<DeviceInfoModel> _getIosInfo() async {
    final info = await _deviceInfo.iosInfo;

    return DeviceInfoModel(
      system: 'iOS',
      osVersion: info.systemVersion,
      deviceModel: info.model,
      manufacturer: 'Apple',
      isPhysicalDevice: info.isPhysicalDevice,
    );
  }

  Future<DeviceInfoModel> _getWebInfo() async {
    final info = await _deviceInfo.webBrowserInfo;
    final userAgent = info.userAgent;

    return DeviceInfoModel(
      system: _formatBrowserName(info.browserName.name),
      osVersion: _extractOsVersion(userAgent) ?? (info.appVersion ?? 'Unknown'),
      deviceModel: info.platform ?? 'Web',
      manufacturer: _inferManufacturer(info.platform, userAgent),
      isPhysicalDevice: true,
    );
  }

  String _formatBrowserName(String raw) {
    if (raw.isEmpty) return 'Browser';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  /// Browsers don't expose a clean "OS version" field, so this pulls
  /// a human-readable one out of the user-agent string rather than
  /// showing the whole raw UA blob to the user.
  String? _extractOsVersion(String? userAgent) {
    if (userAgent == null) return null;

    final mac = RegExp(r'Mac OS X (\d+[_.]\d+(?:[_.]\d+)?)').firstMatch(userAgent);
    if (mac != null) {
      return 'macOS ${mac.group(1)!.replaceAll('_', '.')}';
    }

    final windows = RegExp(r'Windows NT (\d+\.\d+)').firstMatch(userAgent);
    if (windows != null) {
      const versionMap = {
        '10.0': '10 / 11',
        '6.3': '8.1',
        '6.2': '8',
        '6.1': '7',
      };
      final nt = windows.group(1)!;
      return 'Windows ${versionMap[nt] ?? nt}';
    }

    final ios = RegExp(r'OS (\d+_\d+(?:_\d+)?) like Mac OS X').firstMatch(userAgent);
    if (ios != null) {
      return 'iOS ${ios.group(1)!.replaceAll('_', '.')}';
    }

    final android = RegExp(r'Android (\d+(?:\.\d+)?)').firstMatch(userAgent);
    if (android != null) {
      return 'Android ${android.group(1)}';
    }

    if (userAgent.contains('Linux')) return 'Linux';

    return null;
  }

  String _inferManufacturer(String? platform, String? userAgent) {
    final p = (platform ?? '').toLowerCase();
    final ua = (userAgent ?? '').toLowerCase();

    if (p.contains('mac') || ua.contains('macintosh')) return 'Apple';
    if (p.contains('iphone') || p.contains('ipad')) return 'Apple';
    if (p.contains('win')) return 'Microsoft (PC)';
    if (p.contains('linux') && ua.contains('android')) return 'Android device';
    if (p.contains('linux')) return 'Linux (PC)';

    return 'Unknown';
  }

  DeviceInfoModel _getDesktopInfo() {
    final platformName = switch (defaultTargetPlatform) {
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      _ => 'Desktop',
    };

    return DeviceInfoModel(
      system: platformName,
      osVersion: 'Unknown',
      deviceModel: 'Unknown',
      manufacturer: 'Unknown',
    );
  }
}
