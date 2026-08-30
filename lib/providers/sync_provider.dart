import 'dart:async';
import 'package:flutter/foundation.dart';
import '../sync/lan_sync_adapter.dart';
import '../sync/sync_models.dart';

class SyncProvider extends ChangeNotifier {
  final LanSyncAdapter _adapter;
  StreamSubscription<SyncStatus>? _statusSub;

  SyncProvider(this._adapter) {
    _statusSub = _adapter.statusStream.listen((status) {
      notifyListeners();
    });
  }

  NetworkRole get role => _adapter.currentRole;
  SyncStatus get status => _adapter.currentStatus;
  String? get masterIP => _adapter.masterIP;
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  bool get isMaster => role == NetworkRole.master;
  bool get isWorker => role == NetworkRole.worker;
  bool get isConnected => status == SyncStatus.connected;
  bool get isOffline => status == SyncStatus.offline;
  bool get hasKeyMismatch => status == SyncStatus.keyMismatch;

  String get statusLabel {
    switch (status) {
      case SyncStatus.connected: return isMaster ? 'Broadcasting' : 'Synced';
      case SyncStatus.syncing: return 'Syncing...';
      case SyncStatus.offline: return 'Offline';
      case SyncStatus.discovering: return 'Discovering...';
      case SyncStatus.keyMismatch: return 'Key Mismatch';
    }
  }

  Future<void> scanForMasterNetwork() async {
    await _adapter.attemptRediscovery();
    notifyListeners();
  }

  Future<bool> connectToMasterIP(String ip, String officeKey) async {
    final result = await _adapter.connectToMasterIP(ip, officeKey);
    notifyListeners();
    return result;
  }

  Future<void> rotateOfficeKey(String newKey) async {
    await _adapter.applyNewOfficeKey(newKey);
    notifyListeners();
  }

  Future<void> forceSyncFlush() async {
    await _adapter.lockEngine.forceBreakAllLocks();
    notifyListeners();
  }

  Future<void> syncNow() async {
    await _adapter.pushChanges();
    _lastSyncTime = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }
}
