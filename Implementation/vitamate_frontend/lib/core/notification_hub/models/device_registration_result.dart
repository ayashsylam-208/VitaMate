class DeviceRegistrationResult {
  const DeviceRegistrationResult({
    required this.deviceId,
    required this.isPrimary,
    required this.channelsVersion,
    required this.capabilities,
    this.isActive = true,
    this.assignmentVersion = 1,
    this.deliveryEnabled = false,
  });

  final int deviceId;
  final bool isPrimary;
  final int channelsVersion;
  final Map<String, dynamic> capabilities;
  final bool isActive;
  final int assignmentVersion;
  final bool deliveryEnabled;

  factory DeviceRegistrationResult.fromJson(Map<String, dynamic> json) {
    return DeviceRegistrationResult(
      deviceId: int.tryParse((json['device_id'] ?? '0').toString()) ?? 0,
      isPrimary: json['is_primary'] == true,
      channelsVersion:
          int.tryParse((json['channels_version'] ?? '1').toString()) ?? 1,
      capabilities: Map<String, dynamic>.from(
        (json['capabilities'] as Map?) ?? const {},
      ),
      isActive: json['is_active'] != false,
      assignmentVersion:
          int.tryParse((json['assignment_version'] ?? '1').toString()) ?? 1,
      deliveryEnabled: json['delivery_enabled'] == true,
    );
  }
}
