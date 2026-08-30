class UserModel {
  final String id;
  final String username;
  final String passwordHash;
  final String passwordSalt;
  final String? employeeId;
  final String roleId;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime syncCreatedAt;
  final DateTime syncUpdatedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.passwordSalt,
    this.employeeId,
    required this.roleId,
    required this.isActive,
    this.lastLogin,
    required this.syncCreatedAt,
    required this.syncUpdatedAt,
    required this.isDeleted,
    this.deletedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      passwordSalt: map['password_salt'] as String,
      employeeId: map['employee_id'] as String?,
      roleId: map['role_id'] as String,
      isActive: (map['is_active'] as int) == 1,
      lastLogin: map['last_login'] != null ? DateTime.parse(map['last_login'] as String) : null,
      syncCreatedAt: DateTime.parse(map['SyncCreatedAt'] as String),
      syncUpdatedAt: DateTime.parse(map['SyncUpdatedAt'] as String),
      isDeleted: (map['IsDeleted'] as int) == 1,
      deletedAt: map['DeletedAt'] != null ? DateTime.parse(map['DeletedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'password_salt': passwordSalt,
      'employee_id': employeeId,
      'role_id': roleId,
      'is_active': isActive ? 1 : 0,
      'last_login': lastLogin?.toIso8601String(),
      'SyncCreatedAt': syncCreatedAt.toIso8601String(),
      'SyncUpdatedAt': syncUpdatedAt.toIso8601String(),
      'IsDeleted': isDeleted ? 1 : 0,
      'DeletedAt': deletedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? passwordHash,
    String? passwordSalt,
    String? employeeId,
    String? roleId,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? syncCreatedAt,
    DateTime? syncUpdatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      employeeId: employeeId ?? this.employeeId,
      roleId: roleId ?? this.roleId,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      syncCreatedAt: syncCreatedAt ?? this.syncCreatedAt,
      syncUpdatedAt: syncUpdatedAt ?? this.syncUpdatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
