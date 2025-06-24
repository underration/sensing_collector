import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../model/data_row.dart';

/// BLEスキャナー
class BleScanner {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  final List<String> _beaconFilters;
  bool _isScanning = false;

  BleScanner({List<String> beaconFilters = const []})
    : _beaconFilters = beaconFilters;

  /// スキャン開始
  Future<void> startScan({
    Duration scanDuration = const Duration(seconds: 5), // ← 0 ではなく 3〜10秒程度
  }) async {
    if (_isScanning) {
      debugPrint('BLE Scanner: Already scanning, skipping start');
      return;
    }

    debugPrint('BLE Scanner: Starting scan...');

    // ★　Android 12+ は BLUETOOTH_SCAN の実行時パーミッションが必須
    if (await Permission.bluetoothScan.request().isDenied) {
      debugPrint('BLE Scanner: Bluetooth-SCAN permission denied');
      throw Exception('Bluetooth-SCAN permission denied');
    }

    // BLEが有効かチェック
    if (await FlutterBluePlus.isSupported == false) {
      debugPrint('BLE Scanner: BLE is not supported on this device');
      throw Exception('BLE is not supported on this device');
    }

    // BLEがONかチェック
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      debugPrint('BLE Scanner: Bluetooth is not enabled (state: $adapterState)');
      throw Exception('Please turn on Bluetooth');
    }

    _isScanning = true;
    debugPrint('BLE Scanner: Scan started successfully');

    await FlutterBluePlus.startScan(
      timeout: scanDuration,
      continuousUpdates: true,
      androidScanMode: AndroidScanMode.lowLatency,
      // allowDuplicates: true,
      androidUsesFineLocation: true,
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      // ここで結果をハンドリング or コールバック
      for (final r in results) {
        debugPrint('BLE Scanner: device ${r.device.remoteId} rssi=${r.rssi}');
      }
    });
  }

  /// スキャン停止
  Future<void> stopScan() async {
    if (!_isScanning) {
      debugPrint('BLE Scanner: Not scanning, skipping stop');
      return;
    }

    debugPrint('BLE Scanner: Stopping scan...');
    _isScanning = false;
    await _scanSubscription?.cancel();
    await FlutterBluePlus.stopScan();
    debugPrint('BLE Scanner: Scan stopped successfully');
  }

  /// 現在のスキャン結果を取得
  List<BleData> getCurrentBleData() {
    final results = FlutterBluePlus.lastScanResults;
    final bleDataList = <BleData>[];

    for (final result in results) {
      final device = result.device;
      final advertisementData = result.advertisementData;

      // フィルタリング
      if (_beaconFilters.isNotEmpty) {
        final manufacturerData = advertisementData.manufacturerData;
        bool shouldInclude = false;

        for (final filter in _beaconFilters) {
          if (manufacturerData.isNotEmpty &&
              manufacturerData.keys.any(
                (key) => key.toString().contains(filter),
              )) {
            shouldInclude = true;
            break;
          }
        }

        if (!shouldInclude) continue;
      }

      // RSSIとTxPowerを取得
      final rssi = result.rssi;
      int? txPower;

      // TxPowerを取得（利用可能な場合）
      if (advertisementData.txPowerLevel != null) {
        txPower = advertisementData.txPowerLevel;
      }

      // デバイスIDを生成（MACアドレスまたはUUID）
      final deviceId = device.remoteId.toString();

      bleDataList.add(BleData(id: deviceId, rssi: rssi, txPower: txPower));
    }

    return bleDataList;
  }

  /// スキャン状態を取得
  bool get isScanning => _isScanning;

  /// スキャン結果のストリーム
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  /// フィルタを更新
  void updateFilters(List<String> filters) {
    _beaconFilters.clear();
    _beaconFilters.addAll(filters);
  }

  /// リソースを解放
  void dispose() {
    stopScan();
    _scanSubscription?.cancel();
  }
}
