enum NetworkRole { master, worker, unassigned }
enum SyncStatus { connected, syncing, offline, discovering, keyMismatch }
enum PingResult { online, offline, keyMismatch }
enum LockResult { acquired, denied, alreadyHeldBySelf }

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final NetworkRole role;
  final String ipAddress;
  final DateTime lastSeenAt;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.role,
    required this.ipAddress,
    required this.lastSeenAt,
  });

  bool get isOnline => DateTime.now().difference(lastSeenAt).inSeconds < 15;

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      role: NetworkRole.values.firstWhere(
        (e) => e.toString() == 'NetworkRole.${json['role']}',
        orElse: () => NetworkRole.unassigned,
      ),
      ipAddress: json['ipAddress'] as String,
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'role': role.toString().split('.').last,
      'ipAddress': ipAddress,
      'lastSeenAt': lastSeenAt.toIso8601String(),
    };
  }

  DeviceInfo copyWith({
    String? deviceId,
    String? deviceName,
    NetworkRole? role,
    String? ipAddress,
    DateTime? lastSeenAt,
  }) {
    return DeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      role: role ?? this.role,
      ipAddress: ipAddress ?? this.ipAddress,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class SyncPushPayload {
  final String deviceId;
  final String officeKey;
  final String tableName;
  final List<Map<String, dynamic>> records;
  final DateTime pushedAt;

  SyncPushPayload({
    required this.deviceId,
    required this.officeKey,
    required this.tableName,
    required this.records,
    required this.pushedAt,
  });

  factory SyncPushPayload.fromJson(Map<String, dynamic> json) {
    return SyncPushPayload(
      deviceId: json['deviceId'] as String,
      officeKey: json['officeKey'] as String,
      tableName: json['tableName'] as String,
      records: List<Map<String, dynamic>>.from(json['records'] as List),
      pushedAt: DateTime.parse(json['pushedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'officeKey': officeKey,
      'tableName': tableName,
      'records': records,
      'pushedAt': pushedAt.toIso8601String(),
    };
  }
}

class SyncPullResponse {
  final List<Map<String, dynamic>> records;
  final String tableName;
  final DateTime pulledAt;

  int get recordCount => records.length;

  SyncPullResponse({
    required this.records,
    required this.tableName,
    required this.pulledAt,
  });

  factory SyncPullResponse.fromJson(Map<String, dynamic> json) {
    return SyncPullResponse(
      records: List<Map<String, dynamic>>.from(json['records'] as List),
      tableName: json['tableName'] as String,
      pulledAt: DateTime.parse(json['pulledAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'records': records,
      'tableName': tableName,
      'pulledAt': pulledAt.toIso8601String(),
    };
  }
}
