import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bloc/app_state.dart';
import '../model/settings.dart';

/// 設定画面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _bleScanIntervalController;
  late TextEditingController _bleScanWindowController;
  late TextEditingController _magneticSamplingRateController;
  late TextEditingController _wifiScanIntervalController;
  late TextEditingController _s3BucketController;
  late TextEditingController _s3RegionController;
  late TextEditingController _accessKeyController;
  late TextEditingController _secretKeyController;

  String _outputFormat = 'sqlite';
  bool _enableEncryption = false;
  List<String> _beaconFilters = [];

  @override
  void initState() {
    super.initState();
    final currentSettings = ref.read(appStateProvider).settings;

    _bleScanIntervalController = TextEditingController(
      text: currentSettings.bleScanInterval.toString(),
    );
    _bleScanWindowController = TextEditingController(
      text: currentSettings.bleScanWindow.toString(),
    );
    _magneticSamplingRateController = TextEditingController(
      text: currentSettings.magneticSamplingRate.toString(),
    );
    _wifiScanIntervalController = TextEditingController(
      text: currentSettings.wifiScanInterval.toString(),
    );
    _s3BucketController = TextEditingController(
      text: currentSettings.s3Bucket ?? '',
    );
    _s3RegionController = TextEditingController(
      text: currentSettings.s3Region ?? '',
    );
    _accessKeyController = TextEditingController();
    _secretKeyController = TextEditingController();

    _outputFormat = currentSettings.outputFormat;
    _enableEncryption = currentSettings.enableEncryption;
    _beaconFilters = List.from(currentSettings.beaconFilters);
  }

  @override
  void dispose() {
    _bleScanIntervalController.dispose();
    _bleScanWindowController.dispose();
    _magneticSamplingRateController.dispose();
    _wifiScanIntervalController.dispose();
    _s3BucketController.dispose();
    _s3RegionController.dispose();
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(onPressed: _saveSettings, child: const Text('Save')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // センサー設定
            _buildSensorSettings(),

            const SizedBox(height: 24),

            // 出力設定
            _buildOutputSettings(),

            const SizedBox(height: 24),

            // BLEフィルタ設定
            _buildBleFilterSettings(),

            const SizedBox(height: 24),

            // S3設定
            _buildS3Settings(),
          ],
        ),
      ),
    );
  }

  /// センサー設定
  Widget _buildSensorSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sensor Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // BLE設定
            TextField(
              controller: _bleScanIntervalController,
              decoration: const InputDecoration(
                labelText: 'BLE Scan Interval (ms)',
                border: OutlineInputBorder(),
                helperText: 'Recommended: 200ms',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _bleScanWindowController,
              decoration: const InputDecoration(
                labelText: 'BLE Scan Window (ms)',
                border: OutlineInputBorder(),
                helperText: 'Recommended: 100ms',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // 地磁気設定
            TextField(
              controller: _magneticSamplingRateController,
              decoration: const InputDecoration(
                labelText: 'Magnetic Sampling Rate (Hz)',
                border: OutlineInputBorder(),
                helperText: 'Recommended: 50Hz',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Wi-Fi設定
            TextField(
              controller: _wifiScanIntervalController,
              decoration: const InputDecoration(
                labelText: 'Wi-Fi Scan Interval (ms)',
                border: OutlineInputBorder(),
                helperText: 'Recommended: 4000ms',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  /// 出力設定
  Widget _buildOutputSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Output Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // 出力形式
            DropdownButtonFormField<String>(
              value: _outputFormat,
              decoration: const InputDecoration(
                labelText: 'Output Format',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'sqlite', child: Text('SQLite')),
                DropdownMenuItem(value: 'csv', child: Text('CSV')),
              ],
              onChanged: (value) {
                setState(() {
                  _outputFormat = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // 暗号化設定
            SwitchListTile(
              title: const Text('Enable Encryption'),
              subtitle: const Text('Encrypt stored data with AES-256'),
              value: _enableEncryption,
              onChanged: (value) {
                setState(() {
                  _enableEncryption = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// BLEフィルタ設定
  Widget _buildBleFilterSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'BLE Beacon Filters',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addBeaconFilter,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_beaconFilters.isEmpty)
              const Text(
                'No filters configured. All BLE devices will be scanned.',
                style: TextStyle(fontStyle: FontStyle.italic),
              )
            else
              ..._beaconFilters.asMap().entries.map((entry) {
                final index = entry.key;
                final filter = entry.value;
                return ListTile(
                  title: Text(filter),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeBeaconFilter(index),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// S3設定
  Widget _buildS3Settings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'S3 Upload Settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _s3BucketController,
              decoration: const InputDecoration(
                labelText: 'S3 Bucket Name',
                border: OutlineInputBorder(),
                helperText: 'e.g., omu-data-raw',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _s3RegionController,
              decoration: const InputDecoration(
                labelText: 'S3 Region',
                border: OutlineInputBorder(),
                helperText: 'e.g., ap-northeast-1',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _accessKeyController,
              decoration: const InputDecoration(
                labelText: 'Access Key ID',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _secretKeyController,
              decoration: const InputDecoration(
                labelText: 'Secret Access Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
      ),
    );
  }

  /// BLEフィルタを追加
  void _addBeaconFilter() {
    final TextEditingController filterController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add BLE Filter'),
            content: TextField(
              controller: filterController,
              decoration: const InputDecoration(
                labelText: 'UUID or Device ID',
                hintText: 'Enter UUID or device identifier',
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _beaconFilters.add(value);
                  });
                  Navigator.pop(context);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final value = filterController.text;
                  if (value.isNotEmpty) {
                    setState(() {
                      _beaconFilters.add(value);
                    });
                  }
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  /// BLEフィルタを削除
  void _removeBeaconFilter(int index) {
    setState(() {
      _beaconFilters.removeAt(index);
    });
  }

  /// 設定を保存
  void _saveSettings() {
    try {
      final newSettings = Settings(
        bleScanInterval: int.parse(_bleScanIntervalController.text),
        bleScanWindow: int.parse(_bleScanWindowController.text),
        magneticSamplingRate: int.parse(_magneticSamplingRateController.text),
        wifiScanInterval: int.parse(_wifiScanIntervalController.text),
        outputFormat: _outputFormat,
        beaconFilters: _beaconFilters,
        enableEncryption: _enableEncryption,
        s3Bucket:
            _s3BucketController.text.isNotEmpty
                ? _s3BucketController.text
                : null,
        s3Region:
            _s3RegionController.text.isNotEmpty
                ? _s3RegionController.text
                : null,
      );

      ref.read(appStateProvider.notifier).updateSettings(newSettings);

      // S3設定を更新
      if (_s3BucketController.text.isNotEmpty &&
          _s3RegionController.text.isNotEmpty &&
          _accessKeyController.text.isNotEmpty &&
          _secretKeyController.text.isNotEmpty) {
        ref
            .read(uploadServiceProvider)
            .updateS3Settings(
              bucket: _s3BucketController.text,
              region: _s3RegionController.text,
              accessKey: _accessKeyController.text,
              secretKey: _secretKeyController.text,
            );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
    }
  }
}
