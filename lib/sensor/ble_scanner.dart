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
  List<ScanResult> _latestScanResults = []; // 最新のスキャン結果を保存

  BleScanner({List<String> beaconFilters = const []})
    : _beaconFilters = List<String>.from(beaconFilters);

  /// スキャン開始
  Future<void> startScan({
    Duration scanDuration = const Duration(seconds: 5), // ← 0 ではなく 3〜10秒程度
  }) async {
    if (_isScanning) {
      debugPrint('BLE Scanner: Already scanning, skipping start');
      return;
    }

    debugPrint('BLE Scanner: Starting scan...');

    // 既存のサブスクリプションをキャンセル
    await _scanSubscription?.cancel();
    _scanSubscription = null;

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
      debugPrint(
        'BLE Scanner: Bluetooth is not enabled (state: $adapterState)',
      );
      throw Exception('Please turn on Bluetooth');
    }

    // 進行中のスキャンを停止
    if (await FlutterBluePlus.isScanning.first) {
      await FlutterBluePlus.stopScan();
      // スキャンが完全に停止するまで少し待機
      await Future.delayed(Duration(milliseconds: 100));
    }

    _isScanning = true;
    debugPrint('BLE Scanner: Scan started successfully');
    try {
      await FlutterBluePlus.startScan(
        // timeoutを設定しない（null）で継続スキャン
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.lowLatency,
        androidUsesFineLocation: true,
      );
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          // 最新のスキャン結果を保存
          _latestScanResults = results;

          // ここで結果をハンドリング or コールバック
          for (final r in results) {
            debugPrint(
              'BLE Scanner: device ${r.device.remoteId} rssi=${r.rssi}',
            );
          }
        },
        onError: (error) {
          debugPrint('BLE Scanner: Scan error: $error');
          _isScanning = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isScanning = false;
      debugPrint('BLE Scanner: Failed to start scan: $e');
      rethrow;
    }
  }

  /// スキャン停止
  Future<void> stopScan() async {
    if (!_isScanning) {
      debugPrint('BLE Scanner: Not scanning, skipping stop');
      return;
    }
    debugPrint('BLE Scanner: Stopping scan...');
    _isScanning = false;

    // サブスクリプションを先にキャンセル
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    // ローカル保存もクリア
    _latestScanResults.clear();

    // その後でスキャンを停止
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('BLE Scanner: Error stopping scan: $e');
    }

    debugPrint('BLE Scanner: Scan stopped successfully');
  }

  /// 現在のスキャン結果を取得
  List<BleData> getCurrentBleData() {
    // lastScanResultsとローカル保存の両方を試す
    final lastResults = FlutterBluePlus.lastScanResults;
    final results = lastResults.isNotEmpty ? lastResults : _latestScanResults;
    final bleDataList = <BleData>[];

    debugPrint(
      'BLE Scanner: getCurrentBleData() - lastScanResults: ${lastResults.length}, latestScanResults: ${_latestScanResults.length}',
    );
    debugPrint(
      'BLE Scanner: Using ${results.length} scan results for processing',
    );

    for (final result in results) {
      final device = result.device;
      final advertisementData = result.advertisementData;

      debugPrint(
        'BLE Scanner: Processing device ${device.remoteId}, RSSI: ${result.rssi}',
      ); // フィルタリング（フィルタが空の場合は全てのデバイスを含める）
      if (_beaconFilters.isNotEmpty) {
        final manufacturerData = advertisementData.manufacturerData;
        bool shouldInclude = false;

        debugPrint(
          'BLE Scanner: Applying filters ${_beaconFilters}, manufacturerData keys: ${manufacturerData.keys.toList()}',
        );

        for (final filter in _beaconFilters) {
          if (manufacturerData.isNotEmpty &&
              manufacturerData.keys.any(
                (key) => key.toString().contains(filter),
              )) {
            shouldInclude = true;
            break;
          }
        }

        if (!shouldInclude) {
          debugPrint('BLE Scanner: Device ${device.remoteId} filtered out');
          continue;
        }
      } else {
        debugPrint('BLE Scanner: No filters applied, including all devices');
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
      debugPrint('BLE Scanner: Added device ${deviceId} to results');
    }

    debugPrint(
      'BLE Scanner: getCurrentBleData() - Returning ${bleDataList.length} devices',
    );
    return bleDataList;
  }

  /// スキャン状態を取得
  bool get isScanning => _isScanning;

  /// スキャン結果のストリーム
  Stream<List<ScanResult>> get scanResults {
    // 新しいStreamControllerを使用して、複数のリスナーをサポート
    return FlutterBluePlus.scanResults.asBroadcastStream();
  }

  /// フィルタを更新
  void updateFilters(List<String> filters) {
    // _beaconFiltersはfinalなので再代入不可。もし再代入したい場合はList<String> _beaconFilters;に変更する必要あり。
    // ここでは既存のリストの内容を更新
    _beaconFilters.clear();
    _beaconFilters.addAll(filters);
  }

  /// リソースを解放
  Future<void> dispose() async {
    await stopScan();
    _scanSubscription = null;
  }
}
