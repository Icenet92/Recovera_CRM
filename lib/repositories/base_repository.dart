import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/database_helper.dart';
import '../models/auth_session.dart';

class PermissionException implements Exception {
  final String message;
  final String requiredPermission;
  const PermissionException(this.message, {required this.requiredPermission});
  @override
  String toString() => 'PermissionException: $message (requires: $requiredPermission)';
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException(this.message);
  @override
  String toString() => 'NotFoundException: $message';
}

abstract class BaseRepository {
  final DatabaseHelper _dbHelper;
  AuthSession? _currentSession;

  BaseRepository(this._dbHelper);

  void setSession(AuthSession? session) {
    _currentSession = session;
  }

  AuthSession get currentSession {
    if (_currentSession == null) throw Exception('No active session');
    return _currentSession!;
  }

  AuthSession? get currentSessionOrNull => _currentSession;

  void requirePermission(String permissionCode) {
    if (_currentSession == null) {
      throw PermissionException(
        'Action requires authentication',
        requiredPermission: permissionCode,
      );
    }
    if (!_currentSession!.hasPermission(permissionCode)) {
      throw PermissionException(
        'User "${_currentSession!.username}" lacks permission "$permissionCode"',
        requiredPermission: permissionCode,
      );
    }
  }

  Future<Database> get database => _dbHelper.database;
}
