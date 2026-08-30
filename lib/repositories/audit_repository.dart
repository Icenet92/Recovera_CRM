import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'base_repository.dart';

class AuditRepository extends BaseRepository {
  AuditRepository(super.dbHelper);

  Future<void> log({
    required String userId,
    required String action,
    String? entityType,
    String? entityId,
    String? oldValue,
    String? newValue,
  }) async {
    try {
      final db = await database;
      final id = const Uuid().v4();
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert('audit_logs', {
        'id': id,
        'user_id': userId,
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'old_value': oldValue,
        'new_value': newValue,
        'timestamp': now,
        'SyncCreatedAt': now,
        'SyncUpdatedAt': now,
        'IsDeleted': 0,
        'DeletedAt': null,
      });
    } catch (e) {
      debugPrint('AuditRepository.log error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLogs({
    String? userId,
    String? action,
    String? entityType,
    String? entityId,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    where.add('IsDeleted = 0');
    if (userId != null) { where.add('user_id = ?'); args.add(userId); }
    if (action != null) { where.add('action = ?'); args.add(action); }
    if (entityType != null) { where.add('entity_type = ?'); args.add(entityType); }
    if (entityId != null) { where.add('entity_id = ?'); args.add(entityId); }

    return db.query(
      'audit_logs',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
  }
}
