class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.role = 'member',
    this.organizationId,
    this.organizationName,
    this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? organizationId;
  final String? organizationName;
  final String? createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: (json['fullName'] ?? json['full_name'] ?? json['fullname']) as String? ?? '',
      role: json['role'] as String? ?? 'member',
      organizationId: (json['organizationId'] ?? json['organization_id']) as String?,
      organizationName: (json['organizationName'] ?? json['organization_name']) as String?,
      createdAt: (json['createdAt'] ?? json['created_at']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'role': role,
    'organizationId': organizationId,
    'organizationName': organizationName,
    'createdAt': createdAt,
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
