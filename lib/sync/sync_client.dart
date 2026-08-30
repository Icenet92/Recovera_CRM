import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'sync_constants.dart';
import 'sync_models.dart';
import 'sync_conflict_resolver.dart';
import '../database/database_helper.dart';

class SyncClient {
  String _masterIP = '';
  String _officeKey = '';
  String _deviceId = '';
  final SyncConflictResolver _resolver = SyncConflictResolver();
  final DatabaseHelper _dbHelper;

  SyncClient(this._dbHelper);

  void configure({
    required String masterIP,
    required String officeKey,
    required String deviceId,
  }) {
    _masterIP = masterIP;
    _officeKey = officeKey;
    _deviceId = deviceId;
  }

  String get _baseUrl => 'http://$_masterIP:$kServerPort';

  Future<PingResult> pingMasterWithResult() async {
    try {
      final url = Uri.parse('$_baseUrl$kEndpointKeyCheck');
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'key': _officeKey}),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['valid'] == true) {
          return PingResult.online;
        } else {
          return PingResult.keyMismatch;
        }
      }
      return PingResult.offline;
    } catch (e) {
      return PingResult.offline;
    }
  }

  Future<List<Map<String, dynamic>>?> pullDeltaTable(
    String tableName,
    String sinceTimestamp,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl$kEndpointSyncPull?table=$tableName&since=$sinceTimestamp',
      );
      final res = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // Might be just an array or a SyncPullResponse
        if (data is Map && data.containsKey('records')) {
          final pullResp = SyncPullResponse.fromJson(
            data as Map<String, dynamic>,
          );
          return pullResp.records;
        } else if (data is List) {
          return data.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      }
      return null;
    } catch (e) {
      debugPrint('SyncClient pull error: $e');
      return null;
    }
  }

  Future<bool> pushDeltaRecords({
    required String tableName,
    required List<Map<String, dynamic>> records,
  }) async {
    if (records.isEmpty) return true;
    try {
      final payload = SyncPushPayload(
        deviceId: _deviceId,
        officeKey: _officeKey,
        tableName: tableName,
        records: records,
        pushedAt: DateTime.now().toUtc(),
      );

      final url = Uri.parse('$_baseUrl$kEndpointSyncPush');
      final res = await http
          .post(url, headers: _headers, body: jsonEncode(payload.toJson()))
          .timeout(const Duration(seconds: 30));

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('SyncClient push error: $e');
      return false;
    }
  }

  Future<void> executeDeltaSyncExchange(List<String> tableNames) async {
    final db = await _dbHelper.database;
    for (final table in tableNames) {
      try {
        final watermark = await _getWatermark(db, table);
        final exchangeStartTime = DateTime.now().toUtc().toIso8601String();

        // Pull
        final incoming = await pullDeltaTable(table, watermark);
        if (incoming != null && incoming.isNotEmpty) {
          await db.transaction((txn) async {
            for (final record in incoming) {
              await _resolver.resolveAndUpsert(
                db: txn,
                tableName: table,
                incomingRecord: record,
                sourceDeviceId:
                    'master', // Master device id isn't strictly needed for loser if we are client, but it's ok
                currentDeviceId: _deviceId,
              );
            }
          });
        }

        // Push
        final localChanges = await db.query(
          table,
          where: 'SyncUpdatedAt > ?',
          whereArgs: [watermark],
        );

        if (localChanges.isNotEmpty) {
          final success = await pushDeltaRecords(
            tableName: table,
            records: localChanges,
          );
          if (!success) {
            continue; // don't update watermark if push failed
          }
        }

        await _updateWatermark(db, table, exchangeStartTime);
      } catch (e) {
        debugPrint('SyncClient sync exchange error for table $table: $e');
      }
    }
  }

  Future<String> _getWatermark(Database db, String tableName) async {
    final rows = await db.query(
      'sync_state',
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );
    if (rows.isEmpty) return '1970-01-01 00:00:00';
    return rows.first['last_synced_updated_at'] as String? ??
        '1970-01-01 00:00:00';
  }

  Future<void> _updateWatermark(
    Database db,
    String tableName,
    String timestamp,
  ) async {
    final existing = await db.query(
      'sync_state',
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('sync_state', {
        'id': const Uuid().v4(),
        'table_name': tableName,
        'last_synced_updated_at': timestamp,
      });
    } else {
      await db.update(
        'sync_state',
        {'last_synced_updated_at': timestamp},
        where: 'table_name = ?',
        whereArgs: [tableName],
      );
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    kOfficeKeyHeader: _officeKey,
    'X-Device-ID': _deviceId,
  };
}
