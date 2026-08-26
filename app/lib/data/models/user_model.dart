class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = 'member',
    this.organizationId,
    this.organizationName,
    this.avatarUrl,
    this.mfaEnabled = false,
    this.cloudSyncEnabled = true,
    this.biometricsEnabled = false,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    fullName:
        (json['fullName'] ?? json['full_name'] ?? json['fullname'])
            as String? ??
        '',
    role: json['role'] as String? ?? 'member',
    organizationId:
        (json['organizationId'] ?? json['organization_id']) as String?,
    organizationName:
        (json['organizationName'] ?? json['organization_name']) as String?,
    avatarUrl: json['avatarUrl'] as String?,
    mfaEnabled: (json['mfaEnabled'] ?? json['mfa_enabled']) as bool? ?? false,
    cloudSyncEnabled:
        (json['cloudSyncEnabled'] ?? json['cloud_sync_enabled']) as bool? ??
        true,
    biometricsEnabled:
        (json['biometricsEnabled'] ?? json['biometrics_enabled']) as bool? ??
        false,
    createdAt: (json['createdAt'] ?? json['created_at']) as String?,
  );

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? organizationId;
  final String? organizationName;
  final String? avatarUrl;
  final bool mfaEnabled;
  final bool cloudSyncEnabled;
  final bool biometricsEnabled;
  final String? createdAt;

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? organizationId,
    String? organizationName,
    String? avatarUrl,
    bool? mfaEnabled,
    bool? cloudSyncEnabled,
    bool? biometricsEnabled,
    String? createdAt,
  }) => UserModel(
    id: id ?? this.id,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    role: role ?? this.role,
    organizationId: organizationId ?? this.organizationId,
    organizationName: organizationName ?? this.organizationName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    mfaEnabled: mfaEnabled ?? this.mfaEnabled,
    cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
    biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'role': role,
    'organizationId': organizationId,
    'organizationName': organizationName,
    'avatarUrl': avatarUrl,
    'mfaEnabled': mfaEnabled,
    'cloudSyncEnabled': cloudSyncEnabled,
    'biometricsEnabled': biometricsEnabled,
    'createdAt': createdAt,
  };
}

class UserSession {
  const UserSession({
    required this.id,
    required this.deviceName,
    required this.osInfo,
    required this.lastActive,
    this.isCurrent = false,
    this.ipAddress,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    id: json['id'] as String? ?? '',
    deviceName: (json['deviceName'] ?? json['device_name']) as String? ?? 'Device',
    osInfo: (json['osInfo'] ?? json['os_info']) as String? ?? 'Unknown OS',
    lastActive: (json['lastActive'] ?? json['last_sync_at'] ?? json['started_at']) as String? ?? 'Just now',
    isCurrent: json['isCurrent'] as bool? ?? false,
    ipAddress: json['ipAddress'] as String?,
  );

  final String id;
  final String deviceName;
  final String osInfo;
  final String lastActive;
  final bool isCurrent;
  final String? ipAddress;

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceName': deviceName,
    'osInfo': osInfo,
    'lastActive': lastActive,
    'isCurrent': isCurrent,
    'ipAddress': ipAddress,
  };
}

class AuthResponse {
  const AuthResponse({
    required this.success,
    this.token,
    this.user,
    this.errorMessage,
  });

  final bool success;
  final String? token;
  final UserModel? user;
  final String? errorMessage;
}
