import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bloc/app_state.dart';
import '../model/data_row.dart' as model;
import 'tag_position_screen.dart';

/// データ収集画面
class CollectScreen extends ConsumerWidget {
  const CollectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final appStateNotifier = ref.read(appStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Collection'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TagPositionScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // リアルタイムデータ表示
            _buildRealTimeData(context, appState),

            const SizedBox(height: 16),

            // センサーデータ詳細
            Expanded(child: _buildSensorDataDetails(context, appState)),

            // 位置ラベル表示
            _buildLocationLabel(context, appState),
          ],
        ),
      ),
    );
  }

  /// リアルタイムデータ表示
  Widget _buildRealTimeData(BuildContext context, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sensors,
                  color: appState.isCollecting ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Real-time Data',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (appState.isCollecting)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (appState.latestDataRow != null)
              _buildDataRowDisplay(context, appState.latestDataRow!)
            else
              const Text('No data available'),
          ],
        ),
      ),
    );
  }

  /// データ行表示
  Widget _buildDataRowDisplay(BuildContext context, model.DataRow dataRow) {
    return Column(
      children: [
        // タイムスタンプ
        Row(
          children: [
            const Icon(Icons.access_time, size: 16),
            const SizedBox(width: 4),
            Text(
              'Timestamp: ${_formatTimestamp(dataRow.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 地磁気データ
        if (dataRow.magX != null ||
            dataRow.magY != null ||
            dataRow.magZ != null)
          _buildMagneticData(context, dataRow),

        const SizedBox(height: 8),

        // BLEデータ
        if (dataRow.bleData != null && dataRow.bleData!.isNotEmpty)
          _buildBleData(context, dataRow.bleData!),

        const SizedBox(height: 8),

        // Wi-Fiデータ
        if (dataRow.wifiData != null && dataRow.wifiData!.isNotEmpty)
          _buildWifiData(context, dataRow.wifiData!),
      ],
    );
  }

  /// 地磁気データ表示
  Widget _buildMagneticData(BuildContext context, model.DataRow dataRow) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.explore, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Text(
                  'Magnetic Field (μT)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAxisData('X', dataRow.magX),
                _buildAxisData('Y', dataRow.magY),
                _buildAxisData('Z', dataRow.magZ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 軸データ表示
  Widget _buildAxisData(String axis, double? value) {
    return Column(
      children: [
        Text(
          axis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          value?.toStringAsFixed(2) ?? 'N/A',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  /// BLEデータ表示
  Widget _buildBleData(BuildContext context, List<model.BleData> bleData) {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth, size: 16, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'BLE Devices (${bleData.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...bleData
                .take(3)
                .map(
                  (device) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Text(
                          device.id.substring(0, 8),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          '${device.rssi} dBm',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (bleData.length > 3)
              Text(
                '... and ${bleData.length - 3} more',
                style: const TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Wi-Fiデータ表示
  Widget _buildWifiData(BuildContext context, List<model.WifiData> wifiData) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  'Wi-Fi Networks (${wifiData.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...wifiData
                .take(3)
                .map(
                  (network) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            network.ssid.isNotEmpty ? network.ssid : 'Hidden',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${network.rssi} dBm',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (wifiData.length > 3)
              Text(
                '... and ${wifiData.length - 3} more',
                style: const TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// センサーデータ詳細
  Widget _buildSensorDataDetails(BuildContext context, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sensor Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildSensorDetailRow(
                    'BLE Scan',
                    appState.sensorStatus['ble'] ?? false,
                  ),
                  _buildSensorDetailRow(
                    'Magnetic Sensor',
                    appState.sensorStatus['magnetic'] ?? false,
                  ),
                  _buildSensorDetailRow(
                    'Wi-Fi Scan',
                    appState.sensorStatus['wifi'] ?? false,
                  ),
                  const Divider(),
                  _buildDetailRow('Buffer Size', '${appState.bufferSize} rows'),
                  _buildDetailRow(
                    'Collection Status',
                    appState.isCollecting ? 'Active' : 'Inactive',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// センサー詳細行
  Widget _buildSensorDetailRow(String name, bool isActive) {
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

  /// 詳細行
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: '),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// 位置ラベル表示
  Widget _buildLocationLabel(BuildContext context, AppState appState) {
    final dataRow = appState.latestDataRow;
    if (dataRow?.labelX == null || dataRow?.labelY == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  'Location Label',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCoordinateDisplay('X', dataRow!.labelX!),
                _buildCoordinateDisplay('Y', dataRow.labelY!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 座標表示
  Widget _buildCoordinateDisplay(String axis, double value) {
    return Column(
      children: [
        Text(
          axis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          value.toStringAsFixed(3),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// タイムスタンプをフォーマット
  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }
}
