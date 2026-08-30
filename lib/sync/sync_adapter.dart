import 'sync_models.dart';

abstract class SyncAdapter {
  Future<void> pushChanges();
  Future<void> pullChanges({required DateTime since});
  Future<SyncStatus> getConnectionStatus();
  Future<void> dispose();
}
