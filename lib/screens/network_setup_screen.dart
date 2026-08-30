import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sync_provider.dart';

class NetworkSetupScreen extends StatefulWidget {
  const NetworkSetupScreen({super.key});

  @override
  State<NetworkSetupScreen> createState() => _NetworkSetupScreenState();
}

class _NetworkSetupScreenState extends State<NetworkSetupScreen> {
  final _ipController = TextEditingController();
  final _keyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncProvider>();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Network Setup',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role: ${sync.isMaster
                        ? "Master"
                        : sync.isWorker
                        ? "Worker"
                        : "Unassigned"}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Status: ${sync.statusLabel}'),
                  if (sync.isWorker) ...[
                    const SizedBox(height: 8),
                    Text('Master IP: ${sync.masterIP ?? "Unknown"}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (sync.isMaster) ...[
            ElevatedButton(
              onPressed: () {
                // Change key
              },
              child: const Text('Change Office Key'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => sync.scanForMasterNetwork(),
              child: const Text('Scan for Master'),
            ),
            const SizedBox(height: 16),
            const Text('Manual Connection:'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Master IP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: 'Office Key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_ipController.text.isNotEmpty &&
                        _keyController.text.isNotEmpty) {
                      sync.connectToMasterIP(
                        _ipController.text,
                        _keyController.text,
                      );
                    }
                  },
                  child: const Text('Connect'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Force Sync Flush?'),
                  content: const Text(
                    'This will break all active locks on this device.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await sync.forceSyncFlush();
              }
            },
            child: const Text(
              'Force Sync Flush (Break All Locks)',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
