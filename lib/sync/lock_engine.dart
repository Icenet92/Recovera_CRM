import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'sync_models.dart';
import '../database/database_helper.dart';

const Map<String, int> kRolePriority = {
  'Super Administrator': 100,
  'Executive/Director': 80,
  'Manager': 70,
  'Case Manager': 50,
  'Finance Officer': 50,
  'Business Development Officer': 40,
  'Recovery Officer': 30,
  'Auditor': 10,
};

class LockEngine {
  final DatabaseHelper _dbHelper;
  final String deviceId;
  final String deviceName;
  final int rolePriority;

  LockEngine({
    required this._dbHelper,
    required this.deviceId,
    required this.deviceName,
    required this.rolePriority,
  });

  Future<LockResult> acquireLock({
    required String entityType,
    required String entityId,
    String lockMode = 'edit',
  }) async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toUtc().toIso8601String();

    // First run cleanup to make sure we aren't blocked by an expired lock
    await cleanupExpiredLocks();

    return await db.transaction((txn) async {
      final existing = await txn.query(
        'distributed_locks',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final existingLock = existing.first;
        if (existingLock['device_id'] == deviceId) {
          // We already hold it, renew it
          await _renewLockInTxn(txn, entityType, entityId);
          return LockResult.alreadyHeldBySelf;
        }

        final existingPriority = (existingLock['role_priority'] as int?) ?? 1;
        if (rolePriority > existingPriority) {
          // Break lower priority lock
          await txn.delete(
            'distributed_locks',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: [entityType, entityId],
          );
          await _insertLockInTxn(txn, entityType, entityId, lockMode);
          return LockResult.acquired;
        }

        return LockResult.denied;
      }

      await _insertLockInTxn(txn, entityType, entityId, lockMode);
      return LockResult.acquired;
    });
  }

  Future<void> _insertLockInTxn(
    Transaction txn,
    String entityType,
    String entityId,
    String lockMode,
  ) async {
    final now = DateTime.now().toUtc();
    final expires = now.add(const Duration(seconds: 30));
    await txn.insert('distributed_locks', {
      'id': const Uuid().v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'device_id': deviceId,
      'device_name': deviceName,
      'lock_mode': lockMode,
      'acquired_at': now.toIso8601String(),
      'expires_at': expires.toIso8601String(),
      'role_priority': rolePriority,
    });
  }

  Future<void> _renewLockInTxn(
    Transaction txn,
    String entityType,
    String entityId,
  ) async {
    final expires = _expiryTime().toIso8601String();
    await txn.update(
      'distributed_locks',
      {'expires_at': expires},
      where: 'entity_type = ? AND entity_id = ? AND device_id = ?',
      whereArgs: [entityType, entityId, deviceId],
    );
  }

  Future<void> releaseLock(String entityType, String entityId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'distributed_locks',
      where: 'entity_type = ? AND entity_id = ? AND device_id = ?',
      whereArgs: [entityType, entityId, deviceId],
    );
  }

  Future<List<Map<String, dynamic>>> getActiveLocks() async {
    final db = await _dbHelper.database;
    await cleanupExpiredLocks();
    return await db.query('distributed_locks');
  }

  Future<void> forceBreakLock(String lockId) async {
    final db = await _dbHelper.database;
    await db.delete('distributed_locks', where: 'id = ?', whereArgs: [lockId]);
  }

  Future<void> forceBreakAllLocks() async {
    final db = await _dbHelper.database;
    await db.delete('distributed_locks');
  }

  Future<void> cleanupExpiredLocks() async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toUtc().toIso8601String();
    await db.delete(
      'distributed_locks',
      where: 'expires_at < ?',
      whereArgs: [nowStr],
    );
  }

  Future<void> renewLock(String entityType, String entityId) async {
    final db = await _dbHelper.database;
    final expires = _expiryTime().toIso8601String();
    await db.update(
      'distributed_locks',
      {'expires_at': expires},
      where: 'entity_type = ? AND entity_id = ? AND device_id = ?',
      whereArgs: [entityType, entityId, deviceId],
    );
  }

  DateTime _expiryTime() =>
      DateTime.now().toUtc().add(const Duration(seconds: 30));
}
