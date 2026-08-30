import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'sync_constants.dart';

class SyncDiscovery {
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  String? _latestMasterIP;
  final _masterIPController = StreamController<String?>.broadcast();
  bool _isDiscovering = false;

  String? get latestMasterIP => _latestMasterIP;
  Stream<String?> get masterIPStream => _masterIPController.stream;

  Future<void> startBroadcasting({required int port}) async {
    final service = BonsoirService(
      name: kMdnsServiceName,
      type: kMdnsServiceType,
      port: port,
    );
    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize();
    await _broadcast!.start();
  }

  Future<void> stopBroadcasting() async {
    await _broadcast?.stop();
    _broadcast = null;
  }

  Future<void> startDiscovering() async {
    if (_isDiscovering) return;
    _isDiscovering = true;

    _discovery = BonsoirDiscovery(type: kMdnsServiceType);
    await _discovery!.initialize();

    _discovery!.eventStream!.listen((event) {
      if (event is BonsoirDiscoveryServiceResolvedEvent) {
        final service = event.service;
        final ip = service.hostAddress;
        if (ip != null) {
          _latestMasterIP = ip;
          _masterIPController.add(ip);
        }
      }
    });

    await _discovery!.start();
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    await _discovery?.stop();
    _discovery = null;
  }

  Future<String?> waitForMaster({Duration timeout = const Duration(seconds: kMasterDiscoveryTimeoutSeconds)}) async {
    if (_latestMasterIP != null) {
      return _latestMasterIP;
    }

    try {
      return await masterIPStream.first.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    stopBroadcasting();
    stopDiscovery();
    _masterIPController.close();
  }
}
