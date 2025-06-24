import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wifi_iot/wifi_iot.dart';
import '../model/data_row.dart';

/// Wi-Fiスキャナー
class WifiScanner {
  Timer? _scanTimer;
  bool _isScanning = false;
  List<WifiData> _lastScanResults = [];
  int _scanInterval = 4000; // 4秒間隔（設計書通り）

  /// Wi-Fiスキャン開始
  Future<void> startScan({int scanInterval = 4000}) async {
    if (_isScanning) {
      debugPrint('Wi-Fi Scanner: Already scanning, skipping start');
      return;
    }

    debugPrint('Wi-Fi Scanner: Starting scan...');

    _scanInterval = scanInterval;
    _isScanning = true;
    debugPrint('Wi-Fi Scanner: Scan started successfully');

    // 初回スキャン
    await _performScan();

    // 定期的なスキャン
    _scanTimer = Timer.periodic(Duration(milliseconds: _scanInterval), (timer) {
      _performScan();
    });
  }

  /// Wi-Fiスキャン停止
  Future<void> stopScan() async {
    if (!_isScanning) {
      debugPrint('Wi-Fi Scanner: Not scanning, skipping stop');
      return;
    }

    debugPrint('Wi-Fi Scanner: Stopping scan...');
    _isScanning = false;
    _scanTimer?.cancel();
    _scanTimer = null;
    debugPrint('Wi-Fi Scanner: Scan stopped successfully');
  }

  /// スキャン実行
  Future<void> _performScan() async {
    try {
      debugPrint('Wi-Fi Scanner: Checking WiFi status...');
      // Wi-Fiが有効かチェック
      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      debugPrint('Wi-Fi Scanner: WiFi enabled: $isEnabled');

      if (isEnabled != true) {
        debugPrint('Wi-Fi Scanner: WiFi is not enabled');
        return;
      }

      debugPrint('Wi-Fi Scanner: Performing scan...');

      // スキャン実行
      final List<WifiNetwork> networks = await WiFiForIoTPlugin.loadWifiList();

      debugPrint('Wi-Fi Scanner: Raw networks found: ${networks.length}');

      _lastScanResults =
          networks.map((network) {
            final wifiData = WifiData(
              bssid: network.bssid ?? '',
              ssid: network.ssid ?? '',
              rssi: network.level ?? -100,
              frequency: network.frequency ?? 0,
            );
            debugPrint(
              'Wi-Fi Scanner: Network - SSID: ${wifiData.ssid}, BSSID: ${wifiData.bssid}, RSSI: ${wifiData.rssi}',
            );
            return wifiData;
          }).toList();
      debugPrint('Wi-Fi Scanner: Found ${_lastScanResults.length} networks');
    } catch (e) {
      debugPrint('Wi-Fi Scanner: Scan error: $e');
    }
  }

  /// 最新のWi-Fiデータを取得
  List<WifiData> getCurrentWifiData() {
    return List.from(_lastScanResults);
  }

  /// スキャン間隔を更新
  void updateScanInterval(int interval) {
    _scanInterval = interval;

    if (_isScanning) {
      // 現在のタイマーを停止して新しい間隔で再開
      _scanTimer?.cancel();
      _scanTimer = Timer.periodic(Duration(milliseconds: _scanInterval), (
        timer,
      ) {
        _performScan();
      });
    }
  }

  /// 手動でスキャン実行
  Future<void> performManualScan() async {
    await _performScan();
  }

  /// スキャン状態を取得
  bool get isScanning => _isScanning;

  /// 最新のスキャン結果数
  int get scanResultCount => _lastScanResults.length;

  /// リソースを解放
  Future<void> dispose() async {
    await stopScan();
  }
}
