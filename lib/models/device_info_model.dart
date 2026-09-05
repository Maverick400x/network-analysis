class DeviceInfoModel {
  final String system;
  final String osVersion;
  final String deviceModel;
  final String manufacturer;
  final bool isPhysicalDevice;

  const DeviceInfoModel({
    required this.system,
    required this.osVersion,
    required this.deviceModel,
    required this.manufacturer,
    this.isPhysicalDevice = true,
  });

  factory DeviceInfoModel.fromMap(Map<String, dynamic> map) {
    return DeviceInfoModel(
      system: (map['system'] as String?) ?? 'Unknown',
      osVersion: (map['version'] as String?) ?? 'Unknown',
      deviceModel: (map['model'] as String?) ?? 'Unknown',
      manufacturer: (map['manufacturer'] as String?) ?? 'Unknown',
      isPhysicalDevice: (map['isPhysicalDevice'] as bool?) ?? true,
    );
  }

  factory DeviceInfoModel.unknown() {
    return const DeviceInfoModel(
      system: 'Unknown',
      osVersion: 'Unknown',
      deviceModel: 'Unknown',
      manufacturer: 'Unknown',
    );
  }
}
