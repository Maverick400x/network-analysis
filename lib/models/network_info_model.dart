/// Static/coarse network identity information.
///
/// Values that change "on network change" (connectionType, localIp,
/// wifiName, wifiBssid) and values that change "periodically"
/// (publicIp, isp, signalStrengthDbm) are both modeled here; the
/// provider decides *when* each field gets refreshed.
class NetworkInfoModel {
  final String connectionType;
  final String? localIp;
  final String? wifiName;
  final String? wifiBssid;

  final String? publicIp;
  final String? isp;

  final int? signalStrengthDbm;

  const NetworkInfoModel({
    this.connectionType = 'Unknown',
    this.localIp,
    this.wifiName,
    this.wifiBssid,
    this.publicIp,
    this.isp,
    this.signalStrengthDbm,
  });

  bool get isConnected =>
      connectionType != 'No Connection' && connectionType != 'Unknown';

  /// Human readable signal quality bucket derived from dBm, since raw
  /// dBm is not very meaningful to most users.
  String get signalQualityLabel {
    final dbm = signalStrengthDbm;
    if (dbm == null) return 'N/A';
    if (dbm >= -50) return 'Excellent';
    if (dbm >= -60) return 'Good';
    if (dbm >= -70) return 'Fair';
    return 'Weak';
  }

  NetworkInfoModel copyWith({
    String? connectionType,
    String? localIp,
    String? wifiName,
    String? wifiBssid,
    String? publicIp,
    String? isp,
    int? signalStrengthDbm,
    bool clearSignalStrength = false,
  }) {
    return NetworkInfoModel(
      connectionType: connectionType ?? this.connectionType,
      localIp: localIp ?? this.localIp,
      wifiName: wifiName ?? this.wifiName,
      wifiBssid: wifiBssid ?? this.wifiBssid,
      publicIp: publicIp ?? this.publicIp,
      isp: isp ?? this.isp,
      signalStrengthDbm: clearSignalStrength
          ? null
          : (signalStrengthDbm ?? this.signalStrengthDbm),
    );
  }
}
