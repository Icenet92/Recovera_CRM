import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'sync_adapter.dart';
import 'sync_constants.dart';
import 'sync_models.dart';
import 'sync_discovery.dart';
import 'sync_server.dart';
import 'sync_client.dart';
import 'lock_engine.dart';
import '../database/database_helper.dart';

class LanSyncAdapter implements SyncAdapter {
  final DatabaseHelper _dbHelper;
  String _deviceId = '';
  String _deviceName = '';
  NetworkRole _role = NetworkRole.unassigned;
  SyncStatus _status = SyncStatus.discovering;
  String _officeKey = '';
  String? _masterIP;

  late final SyncDiscovery _discovery;
  late final SyncServer _server;
  late final SyncClient _client;
  late final LockEngine _lockEngine;

  Timer? _heartbeatTimer;
  Timer? _syncTimer;
  Timer? _lockCleanupTimer;
  int _missedHeartbeats = 0;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get currentStatus => _status;
  NetworkRole get currentRole => _role;
  String? get masterIP => _masterIP;

  LanSyncAdapter(this._dbHelper) {
    _discovery = SyncDiscovery();
    _client = SyncClient(_dbHelper);
  }

  @override
  Future<void> pushChanges() async {
    if (_role == NetworkRole.worker && _status == SyncStatus.connected) {
      await _client.executeDeltaSyncExchange(kSyncedTables);
    }
  }

  @override
  Future<void> pullChanges({required DateTime since}) async {
    await pushChanges();
  }

  @override
  Future<SyncStatus> getConnectionStatus() async => _status;

  Future<void> initialize({
    required String deviceId,
    required String deviceName,
  }) async {
    _deviceId = deviceId;
    _deviceName = deviceName;
    _server = SyncServer(deviceId: deviceId);

    // Priority just an example, a real app would load it from current user role
    _lockEngine = LockEngine(
      dbHelper: _dbHelper,
      deviceId: deviceId,
      deviceName: deviceName,
      rolePriority: 50,
    );

    final config = await _loadConfig();
    if (config == null) {
      await _bootstrap();
    } else {
      _officeKey = config['office_key'] as String;
      _masterIP = config['master_ip'] as String?;
      final rStr = config['network_role'] as String;

      if (rStr == kRoleMaster) {
        await _becomeMaster(_officeKey);
      } else {
        if (_masterIP != null) {
          await _becomeWorker(masterIP: _masterIP!, officeKey: _officeKey);
        } else {
          await _bootstrap();
        }
      }
    }
  }

  Future<void> _bootstrap() async {
    _setStatus(SyncStatus.discovering);
    await _discovery.startDiscovering();
    final ip = await _discovery.waitForMaster();
    await _discovery.stopDiscovery();

    if (ip != null) {
      // For a real app we might prompt the user for the key, but we need it here
      // We will leave _officeKey empty and let it fail to keyMismatch
      _officeKey = '';
      await _becomeWorker(masterIP: ip, officeKey: _officeKey);
    } else {
      final newKey = _generateOfficeKey();
      await _becomeMaster(newKey);
    }
  }

  Future<void> _becomeMaster(String officeKey) async {
    _officeKey = officeKey;
    await _saveConfig(role: kRoleMaster, officeKey: officeKey);

    final db = await _dbHelper.database;
    await _server.start(officeKey: officeKey, db: db);
    await _discovery.startBroadcasting(port: kServerPort);

    _lockCleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _lockEngine.cleanupExpiredLocks();
    });

    _role = NetworkRole.master;
    _setStatus(SyncStatus.connected);
  }

  Future<void> _becomeWorker({
    required String masterIP,
    required String officeKey,
  }) async {
    _masterIP = masterIP;
    _officeKey = officeKey;
    await _saveConfig(
      role: kRoleWorker,
      officeKey: officeKey,
      masterIP: masterIP,
    );

    _client.configure(
      masterIP: masterIP,
      officeKey: officeKey,
      deviceId: _deviceId,
    );

    _role = NetworkRole.worker;
    _setStatus(SyncStatus.connected);

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: kHeartbeatIntervalSeconds),
      (_) {
        _heartbeatTick();
      },
    );

    _syncTimer = Timer.periodic(const Duration(seconds: kSyncIntervalSeconds), (
      _,
    ) {
      _syncTick();
    });

    _lockCleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _lockEngine.cleanupExpiredLocks();
    });

    // Immediate heartbeat
    await _heartbeatTick();
  }

  Future<void> _heartbeatTick() async {
    if (_role != NetworkRole.worker) return;

    final res = await _client.pingMasterWithResult();
    if (res == PingResult.keyMismatch) {
      _heartbeatTimer?.cancel();
      _syncTimer?.cancel();
      _setStatus(SyncStatus.keyMismatch);
    } else if (res == PingResult.offline) {
      _missedHeartbeats++;
      if (_missedHeartbeats >= kMissedHeartbeatsBeforeOffline) {
        _setStatus(SyncStatus.offline);
        _attemptRediscovery();
      }
    } else {
      _missedHeartbeats = 0;
      if (_status != SyncStatus.connected) {
        _setStatus(SyncStatus.connected);
      }
    }
  }

  Future<void> _syncTick() async {
    if (_role != NetworkRole.worker || _status != SyncStatus.connected) return;
    await pushChanges();
  }

  Future<void> attemptRediscovery() async {
    await _attemptRediscovery();
  }

  Future<void> _attemptRediscovery() async {
    if (_status == SyncStatus.discovering) return;
    _setStatus(SyncStatus.discovering);

    await _discovery.startDiscovering();
    final ip = await _discovery.waitForMaster();
    await _discovery.stopDiscovery();

    if (ip != null) {
      _client.configure(
        masterIP: ip,
        officeKey: _officeKey,
        deviceId: _deviceId,
      );
      _masterIP = ip;
      await _saveConfig(role: kRoleWorker, officeKey: _officeKey, masterIP: ip);
      _setStatus(SyncStatus.connected);
      _missedHeartbeats = 0;
    } else {
      _setStatus(SyncStatus.offline);
    }
  }

  Future<bool> connectToMasterIP(String ip, String officeKey) async {
    _client.configure(masterIP: ip, officeKey: officeKey, deviceId: _deviceId);
    final res = await _client.pingMasterWithResult();
    if (res == PingResult.online) {
      await _becomeWorker(masterIP: ip, officeKey: officeKey);
      return true;
    }
    return false;
  }

  Future<void> applyNewOfficeKey(String newKey) async {
    if (_role == NetworkRole.master) {
      await _server.stop();
      await _discovery.stopBroadcasting();
      await _becomeMaster(newKey);
    } else if (_role == NetworkRole.worker) {
      _heartbeatTimer?.cancel();
      _syncTimer?.cancel();
      _officeKey = newKey;
      await _saveConfig(
        role: kRoleWorker,
        officeKey: newKey,
        masterIP: _masterIP,
      );
      await _attemptRediscovery();
    }
  }

  Future<Map<String, dynamic>?> _loadConfig() async {
    final db = await _dbHelper.database;
    final rows = await db.query('network_config', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> _saveConfig({
    required String role,
    required String officeKey,
    String? masterIP,
  }) async {
    final db = await _dbHelper.database;
    await db.delete('network_config');
    await db.insert('network_config', {
      'id': const Uuid().v4(),
      'device_id': _deviceId,
      'network_role': role,
      'office_key': officeKey,
      'office_name': 'Recovera Office',
      'master_ip': masterIP,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  String _generateOfficeKey() {
    final rand = Random.secure();
    return List.generate(
      16,
      (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }

  @override
  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    _syncTimer?.cancel();
    _lockCleanupTimer?.cancel();
    await _server.stop();
    await _discovery.stopBroadcasting();
    await _discovery.stopDiscovery();
    await _statusController.close();
  }

  LockEngine get lockEngine => _lockEngine;
}
