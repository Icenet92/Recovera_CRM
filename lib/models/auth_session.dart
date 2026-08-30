class AuthSession {
  final String userId;
  final String username;
  final String roleId;
  final String roleName;
  final Set<String> permissions;
  final DateTime loginTime;
  /// If true, this user bypasses ALL permission checks — granted when role name is 'Super Administrator'.
  final bool isSuperAdmin;

  const AuthSession({
    required this.userId,
    required this.username,
    required this.roleId,
    required this.roleName,
    required this.permissions,
    required this.loginTime,
    this.isSuperAdmin = false,
  });

  /// Super Administrators always return true regardless of stored permissions.
  bool hasPermission(String code) => isSuperAdmin || permissions.contains(code);

  AuthSession copyWith({
    String? userId,
    String? username,
    String? roleId,
    String? roleName,
    Set<String>? permissions,
    DateTime? loginTime,
    bool? isSuperAdmin,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      permissions: permissions ?? this.permissions,
      loginTime: loginTime ?? this.loginTime,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
    );
  }

  @override
  String toString() => 'AuthSession(username: $username, role: $roleName, superAdmin: $isSuperAdmin)';
}
