import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bloc/app_state.dart';
import 'collect_screen.dart';
import 'settings_screen.dart';
import 'log_viewer_screen.dart';

/// ホーム画面
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final appStateNotifier = ref.read(appStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensing Collector'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogViewerScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 権限チェック
            _buildPermissionCard(context, appState, appStateNotifier),

            const SizedBox(height: 16),

            // ステータスカード
            _buildStatusCard(context, appState),

            const SizedBox(height: 24),

            // メインコントロール
            _buildMainControl(context, appState, appStateNotifier),

            const SizedBox(height: 24),

            // センサー状態
            _buildSensorStatus(context, appState),

            const SizedBox(height: 24),

            // データベース統計
            _buildDatabaseStats(context, appState),

            const SizedBox(height: 24),

            // エラーメッセージ
            if (appState.errorMessage != null)
              _buildErrorMessage(context, appState, appStateNotifier),
          ],
        ),
      ),
    );
  }

  /// 権限チェックカード
  Widget _buildPermissionCard(
    BuildContext context,
    AppState appState,
    AppStateNotifier notifier,
  ) {
    final missingPermissions = <String>[];

    if (!(appState.permissions['location'] ?? false)) {
      missingPermissions.add('Location');
    }
    if (!(appState.permissions['bluetooth'] ?? false) ||
        !(appState.permissions['bluetoothScan'] ?? false) ||
        !(appState.permissions['bluetoothConnect'] ?? false)) {
      missingPermissions.add('Bluetooth');
    }
    if (!(appState.permissions['wifi'] ?? false)) {
      missingPermissions.add('Wi-Fi');
    }
    if (!(appState.permissions['storage'] ?? false)) {
      missingPermissions.add('Storage');
    }
    if (!(appState.permissions['camera'] ?? false)) {
      missingPermissions.add('Camera');
    }

    if (missingPermissions.isEmpty) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'All permissions granted',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Missing Permissions',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Required: ${missingPermissions.join(', ')}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                await notifier.requestPermissions();
              },
              child: const Text('Request Permissions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ステータスカード
  Widget _buildStatusCard(BuildContext context, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  appState.isCollecting
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: appState.isCollecting ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text('Status', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              appState.isCollecting ? 'Collecting data...' : 'Ready to collect',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (appState.isCollecting) ...[
              const SizedBox(height: 8),
              Text(
                'Buffer: ${appState.bufferSize} rows',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// メインコントロール
  Widget _buildMainControl(
    BuildContext context,
    AppState appState,
    AppStateNotifier notifier,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Data Collection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      appState.isCollecting
                          ? null
                          : () async {
                            await notifier.startCollection();
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CollectScreen(),
                                ),
                              );
                            }
                          },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      appState.isCollecting
                          ? () async {
                            await notifier.stopCollection();
                          }
                          : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed:
                  appState.isUploading
                      ? null
                      : () async {
                        await notifier.manualUpload();
                      },
              icon:
                  appState.isUploading
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.cloud_upload),
              label: Text(appState.isUploading ? 'Uploading...' : 'Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// センサー状態
  Widget _buildSensorStatus(BuildContext context, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sensor Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildSensorStatusRow('BLE', appState.sensorStatus['ble'] ?? false),
            _buildSensorStatusRow(
              'Magnetic',
              appState.sensorStatus['magnetic'] ?? false,
            ),
            _buildSensorStatusRow(
              'Wi-Fi',
              appState.sensorStatus['wifi'] ?? false,
            ),
          ],
        ),
      ),
    );
  }

  /// センサー状態行
  Widget _buildSensorStatusRow(String name, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            color: isActive ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(name),
          const Spacer(),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              color: isActive ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// データベース統計
  Widget _buildDatabaseStats(BuildContext context, AppState appState) {
    final stats = appState.databaseStats;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Database Stats',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildStatRow('Total Rows', '${stats['total_rows'] ?? 0}'),
            _buildStatRow(
              'Duration',
              '${(stats['duration_hours'] ?? 0.0).toStringAsFixed(1)} hours',
            ),
            if (stats['last_timestamp'] != null)
              _buildStatRow(
                'Last Update',
                _formatTimestamp(stats['last_timestamp']),
              ),
          ],
        ),
      ),
    );
  }

  /// 統計行
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text('$label: '),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// タイムスタンプをフォーマット
  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// エラーメッセージ
  Widget _buildErrorMessage(
    BuildContext context,
    AppState appState,
    AppStateNotifier notifier,
  ) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Error',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.red.shade700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => notifier.clearError(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              appState.errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
