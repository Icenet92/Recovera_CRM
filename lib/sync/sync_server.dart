import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'sync_constants.dart';
import 'sync_models.dart';
import 'sync_conflict_resolver.dart';

class SyncServer {
  HttpServer? _server;
  String _officeKey = '';
  Database? _db;
  final SyncConflictResolver _resolver = SyncConflictResolver();
  final String deviceId;

  SyncServer({required this.deviceId});

  bool get isRunning => _server != null;

  Future<void> start({
    required String officeKey,
    required Database db,
    int port = kServerPort,
  }) async {
    _officeKey = officeKey;
    _db = db;

    final router = _buildRouter();
    final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    debugPrint('SyncServer listening on port ${_server!.port}');

    await _openFirewallPort(port);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _db = null;
  }

  Router _buildRouter() {
    final router = Router();
    router.get(kEndpointHealth, _handleHealth);
    router.get(kEndpointRole, _handleRole);
    router.post(kEndpointKeyCheck, _handleKeyCheck);
    router.get(kEndpointSyncPull, _handleSyncPull);
    router.post(kEndpointSyncPush, _handleSyncPush);
    return router;
  }

  Future<Response> _handleHealth(Request request) async {
    final keyBytes = utf8.encode(_officeKey);
    final keyHash = sha256.convert(keyBytes).toString().substring(0, 8);
    return _jsonResponse({
      'status': 'ok',
      'role': kRoleMaster,
      'keyHash': keyHash,
    });
  }

  Future<Response> _handleRole(Request request) async {
    return _jsonResponse({'role': kRoleMaster, 'port': kServerPort});
  }

  Future<Response> _handleKeyCheck(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final candidateKey = data['key'] as String?;
      return _jsonResponse({'valid': candidateKey == _officeKey});
    } catch (e) {
      return Response(400, body: 'Bad request');
    }
  }

  Future<Response> _handleSyncPull(Request request) async {
    final authErr = _validateKey(request);
    if (authErr != null) return authErr;

    final table = request.url.queryParameters['table'];
    final since = request.url.queryParameters['since'];

    if (table == null || since == null) {
      return Response(400, body: 'Missing table or since param');
    }

    if (_db == null) return Response(500, body: 'DB not ready');

    try {
      // Check if table has SyncUpdatedAt column to prevent 500
      final tableInfo = await _db!.rawQuery('PRAGMA table_info($table)');
      final hasCol = tableInfo.any((c) => c['name'] == 'SyncUpdatedAt');
      if (!hasCol) return _jsonResponse([]);

      final rows = await _db!.query(
        table,
        where: 'SyncUpdatedAt > ?',
        whereArgs: [since],
      );
      
      return _jsonResponse({
        'tableName': table,
        'records': rows,
        'pulledAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('SyncServer pull error: $e');
      return _jsonResponse([]); // fail gracefully as required
    }
  }

  Future<Response> _handleSyncPush(Request request) async {
    final authErr = _validateKey(request);
    if (authErr != null) return authErr;

    if (_db == null) return Response(500, body: 'DB not ready');

    try {
      final bodyStr = await request.readAsString();
      final bodyJson = jsonDecode(bodyStr) as Map<String, dynamic>;
      final payload = SyncPushPayload.fromJson(bodyJson);

      int processed = 0;
      await _db!.transaction((txn) async {
        for (final record in payload.records) {
          await _resolver.resolveAndUpsert(
            db: txn,
            tableName: payload.tableName,
            incomingRecord: record,
            sourceDeviceId: payload.deviceId,
            currentDeviceId: deviceId,
          );
          processed++;
        }
      });

      return _jsonResponse({'processed': processed});
    } catch (e) {
      debugPrint('SyncServer push error: $e');
      return Response(500, body: 'Error processing push');
    }
  }

  Response? _validateKey(Request request) {
    final key = request.headers[kOfficeKeyHeader];
    if (key == null || key != _officeKey) {
      return Response(401, body: jsonEncode({'error': 'Invalid office key'}),
          headers: {'content-type': 'application/json'});
    }
    return null;
  }

  Future<void> _openFirewallPort(int port) async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('netsh', [
        'advfirewall', 'firewall', 'add', 'rule',
        'name=RecoveraCRM', 'dir=in', 'action=allow',
        'protocol=TCP', 'localport=$port'
      ]);
    } catch (e) {
      debugPrint('Could not open firewall port automatically: $e');
    }
  }

  Response _jsonResponse(Object data, {int status = 200}) {
    return Response(status,
        body: jsonEncode(data),
        headers: {'content-type': 'application/json'});
  }
}
