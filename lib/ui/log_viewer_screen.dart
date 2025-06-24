import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bloc/app_state.dart';
import '../db/database_helper.dart';
import '../model/data_row.dart' as model;
import 'package:share_plus/share_plus.dart';

/// ログビューアー画面
class LogViewerScreen extends ConsumerStatefulWidget {
  const LogViewerScreen({super.key});

  @override
  ConsumerState<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends ConsumerState<LogViewerScreen> {
  List<model.DataRow> _dataRows = [];
  bool _isLoading = false;
  String? _errorMessage;
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Viewer'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// ボディを構築
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Error', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_dataRows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('No Data', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'No sensor data has been collected yet.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 統計情報
          _buildStatsCard(),

          const SizedBox(height: 16),

          // データリスト
          Expanded(child: _buildDataList()),
        ],
      ),
    );
  }

  /// 統計情報カード
  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                'Total Records',
                '${_dataRows.length}',
                Icons.list,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                'Time Range',
                _getTimeRange(),
                Icons.access_time,
              ),
            ),
            Expanded(
              child: _buildStatItem(
                'With Position',
                '${_dataRows.where((row) => row.labelX != null && row.labelY != null).length}',
                Icons.my_location,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 統計アイテム
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// データリスト
  Widget _buildDataList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _dataRows.length,
      itemBuilder: (context, index) {
        final dataRow = _dataRows[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              _formatTimestamp(dataRow.timestamp),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDataSummary(dataRow),
                if (dataRow.labelX != null && dataRow.labelY != null)
                  Row(
                    children: [
                      Icon(
                        Icons.my_location,
                        size: 14,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Position: (${dataRow.labelX!.toStringAsFixed(3)}, ${dataRow.labelY!.toStringAsFixed(3)})',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info),
              onPressed: () => _showDataDetails(dataRow),
            ),
            onTap: () => _showDataDetails(dataRow),
          ),
        );
      },
    );
  }

  /// データサマリー
  Widget _buildDataSummary(model.DataRow dataRow) {
    final summaries = <String>[];

    if (dataRow.bleData != null && dataRow.bleData!.isNotEmpty) {
      summaries.add('BLE: ${dataRow.bleData!.length}');
    }

    if (dataRow.magX != null || dataRow.magY != null || dataRow.magZ != null) {
      summaries.add('Mag: ✓');
    }

    if (dataRow.wifiData != null && dataRow.wifiData!.isNotEmpty) {
      summaries.add('WiFi: ${dataRow.wifiData!.length}');
    }

    return Text(summaries.join(' | '));
  }

  /// データ詳細を表示
  void _showDataDetails(model.DataRow dataRow) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Data Details - ${_formatTimestamp(dataRow.timestamp)}',
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailSection(
                    'Timestamp',
                    dataRow.timestamp.toString(),
                  ),

                  if (dataRow.bleData != null &&
                      dataRow.bleData!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('BLE Devices', ''),
                    ...dataRow.bleData!.map(
                      (device) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text('${device.id}: ${device.rssi} dBm'),
                      ),
                    ),
                  ],

                  if (dataRow.magX != null ||
                      dataRow.magY != null ||
                      dataRow.magZ != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Magnetic Field (μT)', ''),
                    if (dataRow.magX != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('X: ${dataRow.magX!.toStringAsFixed(2)}'),
                      ),
                    if (dataRow.magY != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('Y: ${dataRow.magY!.toStringAsFixed(2)}'),
                      ),
                    if (dataRow.magZ != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('Z: ${dataRow.magZ!.toStringAsFixed(2)}'),
                      ),
                  ],

                  if (dataRow.wifiData != null &&
                      dataRow.wifiData!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Wi-Fi Networks', ''),
                    ...dataRow.wifiData!
                        .take(5)
                        .map(
                          (network) => Padding(
                            padding: const EdgeInsets.only(left: 16, top: 4),
                            child: Text('${network.ssid}: ${network.rssi} dBm'),
                          ),
                        ),
                    if (dataRow.wifiData!.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                          '... and ${dataRow.wifiData!.length - 5} more',
                        ),
                      ),
                  ],
                  if (dataRow.labelX != null && dataRow.labelY != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Position Coordinates', ''),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.my_location,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'X: ${dataRow.labelX!.toStringAsFixed(3)}, Y: ${dataRow.labelY!.toStringAsFixed(3)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  /// 詳細セクション
  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (content.isNotEmpty) ...[const SizedBox(height: 4), Text(content)],
      ],
    );
  }

  /// データを読み込み
  Future<void> _loadData() async {
    debugPrint('LogViewerScreen: Starting data load...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dataRows = await _databaseHelper.getDataRows(limit: 1000);
      debugPrint('LogViewerScreen: Loaded ${dataRows.length} data rows');
      setState(() {
        _dataRows = dataRows;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('LogViewerScreen: Error loading data: $e');
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  /// データをエクスポート
  Future<void> _exportData() async {
    try {
      final file = await _databaseHelper.exportToCsv();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported to: ${file.path}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                // ファイル共有機能を実装

                Share.shareXFiles([
                  XFile(file.path),
                ], text: 'Exported sensor log data');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export data: $e')));
      }
    }
  }

  /// タイムスタンプをフォーマット
  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  /// 時間範囲を取得
  String _getTimeRange() {
    if (_dataRows.isEmpty) return 'N/A';

    final first = DateTime.fromMillisecondsSinceEpoch(_dataRows.last.timestamp);
    final last = DateTime.fromMillisecondsSinceEpoch(_dataRows.first.timestamp);

    if (first.day == last.day) {
      return '${first.hour.toString().padLeft(2, '0')}:${first.minute.toString().padLeft(2, '0')} - '
          '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    } else {
      return '${first.month}/${first.day} - ${last.month}/${last.day}';
    }
  }
}
