import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

class SyncConflictResolver {
  Future<void> resolveAndUpsert({
    required DatabaseExecutor db,
    required String tableName,
    required Map<String, dynamic> incomingRecord,
    required String sourceDeviceId,
    required String currentDeviceId,
  }) async {
    try {
      final recordId = incomingRecord['id'] as String?;
      if (recordId == null) {
        debugPrint('SyncConflictResolver: incoming record missing id');
        return;
      }

      final existingRows = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [recordId],
        limit: 1,
      );

      if (existingRows.isEmpty) {
        await db.insert(
          tableName,
          incomingRecord,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return;
      }

      final existingRecord = existingRows.first;
      final incomingUpdatedStr = incomingRecord['SyncUpdatedAt'] as String?;
      final existingUpdatedStr = existingRecord['SyncUpdatedAt'] as String?;

      final incomingUpdated = _parseTimestamp(incomingUpdatedStr);
      final existingUpdated = _parseTimestamp(existingUpdatedStr);

      if (incomingUpdated == null || existingUpdated == null) {
        // Fail open
        await db.update(
          tableName,
          incomingRecord,
          where: 'id = ?',
          whereArgs: [recordId],
        );
        return;
      }

      if (incomingUpdated.isAfter(existingUpdated)) {
        await db.update(
          tableName,
          incomingRecord,
          where: 'id = ?',
          whereArgs: [recordId],
        );
      } else if (incomingUpdated.isBefore(existingUpdated)) {
        await _writeSyncConflict(
          db: db,
          tableName: tableName,
          recordId: recordId,
          winnerDeviceId: currentDeviceId,
          loserDeviceId: sourceDeviceId,
          winnerUpdatedAt: existingUpdatedStr!,
          loserUpdatedAt: incomingUpdatedStr!,
        );
      }
      // if exactly equal, do nothing
    } catch (e) {
      debugPrint('SyncConflictResolver error resolving record: $e');
    }
  }

  Future<void> _writeSyncConflict({
    required DatabaseExecutor db,
    required String tableName,
    required String recordId,
    required String winnerDeviceId,
    required String loserDeviceId,
    required String winnerUpdatedAt,
    required String loserUpdatedAt,
  }) async {
    try {
      await db.insert('sync_conflicts', {
        'id': const Uuid().v4(),
        'table_name': tableName,
        'record_id': recordId,
        'winner_device_id': winnerDeviceId,
        'loser_device_id': loserDeviceId,
        'winner_updated_at': winnerUpdatedAt,
        'loser_updated_at': loserUpdatedAt,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SyncConflictResolver error writing conflict log: $e');
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null || value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
