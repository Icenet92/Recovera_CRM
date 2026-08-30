import 'package:uuid/uuid.dart';
import 'base_repository.dart';
import 'audit_repository.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserRepository extends BaseRepository {
  final AuditRepository _auditRepo;
  
  UserRepository(super.dbHelper, this._auditRepo);

  Future<UserModel> createUser({
    required String username,
    required String plainPassword,
    required String roleId,
    String? employeeId,
  }) async {
    requirePermission('user.create');
    final db = await database;

    final existing = await db.query('users', where: 'username = ?', whereArgs: [username], limit: 1);
    if (existing.isNotEmpty) {
      throw Exception('Username already taken');
    }

    final salt = AuthService.generateSalt();
    final hash = AuthService.hashPassword(plainPassword, salt);
    
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final nowStr = now.toIso8601String();

    final user = UserModel(
      id: id,
      username: username,
      passwordHash: hash,
      passwordSalt: salt,
      employeeId: employeeId,
      roleId: roleId,
      isActive: true,
      syncCreatedAt: now,
      syncUpdatedAt: now,
      isDeleted: false,
    );

    await db.insert('users', user.toMap());

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'user.create',
      entityType: 'user',
      entityId: id,
    );

    return user;
  }

  Future<UserModel?> getUserById(String id) async {
    requirePermission('user.view');
    final db = await database;
    final rows = await db.query('users', where: 'id = ? AND IsDeleted = 0', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<UserModel?> getUserByUsernameInternal(String username) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND IsDeleted = 0',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<List<UserModel>> getAllUsers() async {
    requirePermission('user.view');
    final db = await database;
    final rows = await db.query('users', where: 'IsDeleted = 0', orderBy: 'username ASC');
    return rows.map(UserModel.fromMap).toList();
  }

  Future<void> updateUser(UserModel user) async {
    requirePermission('user.edit');
    final db = await database;
    
    final updatedUser = user.copyWith(syncUpdatedAt: DateTime.now().toUtc());
    await db.update('users', updatedUser.toMap(), where: 'id = ?', whereArgs: [user.id]);

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'user.update',
      entityType: 'user',
      entityId: user.id,
    );
  }

  Future<void> setUserActive(String userId, bool active) async {
    requirePermission('user.edit');
    final db = await database;
    
    await db.update(
      'users',
      {'is_active': active ? 1 : 0, 'SyncUpdatedAt': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [userId],
    );

    await _auditRepo.log(
      userId: currentSession.userId,
      action: active ? 'user.activate' : 'user.deactivate',
      entityType: 'user',
      entityId: userId,
    );
  }

  Future<void> softDeleteUser(String userId) async {
    requirePermission('user.delete');
    final db = await database;
    final nowStr = DateTime.now().toUtc().toIso8601String();
    
    await db.update(
      'users',
      {'IsDeleted': 1, 'DeletedAt': nowStr, 'SyncUpdatedAt': nowStr},
      where: 'id = ?',
      whereArgs: [userId],
    );

    await _auditRepo.log(
      userId: currentSession.userId,
      action: 'user.delete',
      entityType: 'user',
      entityId: userId,
    );
  }

  Future<void> changePassword(String userId, String newPlainPassword) async {
    final isSelf = currentSessionOrNull?.userId == userId;
    if (!isSelf) requirePermission('user.edit');

    final db = await database;
    final salt = AuthService.generateSalt();
    final hash = AuthService.hashPassword(newPlainPassword, salt);
    final nowStr = DateTime.now().toUtc().toIso8601String();

    await db.update(
      'users',
      {'password_hash': hash, 'password_salt': salt, 'SyncUpdatedAt': nowStr},
      where: 'id = ?',
      whereArgs: [userId],
    );

    await _auditRepo.log(
      userId: currentSessionOrNull?.userId ?? userId,
      action: 'user.change_password',
      entityType: 'user',
      entityId: userId,
    );
  }

  Future<String?> getRoleNameForUser(String roleId) async {
    final db = await database;
    final rows = await db.query('roles', where: 'id = ? AND IsDeleted = 0', whereArgs: [roleId], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['name'] as String?;
  }

  Future<Set<String>> getPermissionsForRole(String roleId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.code FROM permissions p
      INNER JOIN role_permissions rp ON p.id = rp.permission_id
      WHERE rp.role_id = ? AND p.IsDeleted = 0 AND rp.IsDeleted = 0
    ''', [roleId]);
    return rows.map((r) => r['code'] as String).toSet();
  }

  /// Returns all non-deleted roles for use in dropdowns.
  Future<List<Map<String, dynamic>>> getAllRoles() async {
    final db = await database;
    final rows = await db.query('roles', where: 'IsDeleted = 0', orderBy: 'name ASC');
    return rows.map((r) => {'id': r['id'] as String, 'name': r['name'] as String}).toList();
  }

  /// Creates an employee record and a linked user account in one atomic transaction.
  Future<void> createEmployeeAndUser({
    required String firstName,
    required String lastName,
    required String? email,
    required String? phone,
    required String? jobTitle,
    required String username,
    required String plainPassword,
    required String roleId,
  }) async {
    requirePermission('user.create');
    final db = await database;

    final existing = await db.query('users', where: 'username = ?', whereArgs: [username], limit: 1);
    if (existing.isNotEmpty) throw Exception('Username "$username" is already taken.');

    final salt = AuthService.generateSalt();
    final hash = AuthService.hashPassword(plainPassword, salt);

    final empId = const Uuid().v4();
    final userId = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // 1. Create employee record
      await txn.insert('employees', {
        'id': empId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'job_title': jobTitle,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });

      // 2. Create linked user account
      await txn.insert('users', {
        'id': userId,
        'username': username,
        'password_hash': hash,
        'password_salt': salt,
        'employee_id': empId,
        'role_id': roleId,
        'is_active': 1,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });

      // 3. Audit log
      await txn.insert('audit_logs', {
        'id': const Uuid().v4(),
        'user_id': currentSession.userId,
        'action': 'user.create',
        'entity_type': 'users',
        'entity_id': userId,
        'new_value': username,
        'timestamp': now,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    });
  }

  /// Returns all available permissions grouped by category
  Future<List<Map<String, dynamic>>> getAllPermissions() async {
    requirePermission('role.view');
    final db = await database;
    final rows = await db.query(
      'permissions', 
      where: 'IsDeleted = 0', 
      orderBy: 'category ASC, name ASC'
    );
    return rows;
  }

  /// Replaces the entire permission set for a role
  Future<void> updateRolePermissions(String roleId, List<String> newPermissionCodes) async {
    requirePermission('role.assign');
    final db = await database;
    final nowStr = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      // Soft delete existing role permissions
      await txn.update(
        'role_permissions',
        {'IsDeleted': 1, 'DeletedAt': nowStr, 'SyncUpdatedAt': nowStr},
        where: 'role_id = ?',
        whereArgs: [roleId],
      );

      // Get all permission IDs for the new codes
      for (var code in newPermissionCodes) {
        final permRows = await txn.query('permissions', where: 'code = ? AND IsDeleted = 0', whereArgs: [code], limit: 1);
        if (permRows.isEmpty) continue;
        final permId = permRows.first['id'] as String;

        await txn.insert('role_permissions', {
          'id': const Uuid().v4(),
          'role_id': roleId,
          'permission_id': permId,
          'SyncCreatedAt': nowStr,
          'SyncUpdatedAt': nowStr,
          'IsDeleted': 0,
          'DeletedAt': null,
        });
      }

      await _auditRepo.log(
        userId: currentSession.userId,
        action: 'role.update_permissions',
        entityType: 'roles',
        entityId: roleId,
      );
    });
  }
}
