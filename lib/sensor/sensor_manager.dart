import 'dart:async';
import 'dart:isolate';
import '../model/data_row.dart';
import '../model/settings.dart';
import '../db/database_helper.dart';
import 'ble_scanner.dart';
import 'magnetic_sensor.dart';
import 'wifi_scanner.dart';
import 'package:flutter/foundation.dart';

/// センサー管理クラス
class SensorManager {
  final BleScanner _bleScanner;
  final MagneticSensor _magneticSensor;
  final WifiScanner _wifiScanner;
  final DatabaseHelper _databaseHelper;

  Isolate? _sensorIsolate;
  SendPort? _isolateSendPort;
  ReceivePort? _isolateReceivePort;

  bool _isCollecting = false;
  Timer? _dataCollectionTimer;
  final List<DataRow> _dataBuffer = [];
  static const int _bufferFlushInterval = 10000; // 10秒ごとにフラッシュ

  // コールバック
  Function(DataRow)? onDataCollected;
  Function(String)? onError;

  SensorManager({
    required Settings settings,
    required DatabaseHelper databaseHelper,
  }) : _bleScanner = BleScanner(beaconFilters: settings.beaconFilters),
       _magneticSensor = MagneticSensor(),
       _wifiScanner = WifiScanner(),
       _databaseHelper = databaseHelper;

  /// データ収集開始
  Future<void> startCollection({required Settings settings}) async {
    if (_isCollecting) {
      debugPrint('SensorManager: Already collecting, skipping start');
      return;
    }

    debugPrint('SensorManager: Starting collection...');

    try {
      _isCollecting = true;

      // 各センサーを開始
      debugPrint('SensorManager: Starting BLE scanner...');
      await _bleScanner.startScan(
        scanDuration: Duration(milliseconds: settings.bleScanInterval),
      );

      debugPrint('SensorManager: Starting magnetic sensor...');
      await _magneticSensor.startListening(
        samplingRate: settings.magneticSamplingRate,
      );

      debugPrint('SensorManager: Starting Wi-Fi scanner...');
      await _wifiScanner.startScan(scanInterval: settings.wifiScanInterval);

      // Isolateを開始（高速センサー収集用）
      debugPrint('SensorManager: Starting sensor isolate...');
      await _startSensorIsolate();

      // データ収集タイマー開始
      debugPrint('SensorManager: Starting data collection timer...');
      _dataCollectionTimer = Timer.periodic(
        Duration(milliseconds: 100), // 100ms間隔でデータ収集
        (timer) => _collectSensorData(),
      );

      // バッファフラッシュタイマー開始
      Timer.periodic(
        Duration(milliseconds: _bufferFlushInterval),
        (timer) => _flushDataBuffer(),
      );

      debugPrint('SensorManager: Collection started successfully');
      debugPrint('SensorManager: Sensor status - ${sensorStatus}');
    } catch (e) {
      _isCollecting = false;
      debugPrint('SensorManager: Failed to start collection: $e');
      onError?.call('Failed to start collection: $e');
      rethrow;
    }
  }

  /// データ収集停止
  Future<void> stopCollection() async {
    if (!_isCollecting) {
      debugPrint('SensorManager: Not collecting, skipping stop');
      return;
    }

    debugPrint('SensorManager: Stopping collection...');

    _isCollecting = false;

    // タイマー停止
    _dataCollectionTimer?.cancel();
    _dataCollectionTimer = null;

    // バッファをフラッシュ
    await _flushDataBuffer();

    // 各センサー停止
    debugPrint('SensorManager: Stopping BLE scanner...');
    await _bleScanner.stopScan();
    
    debugPrint('SensorManager: Stopping magnetic sensor...');
    await _magneticSensor.stopListening();
    
    debugPrint('SensorManager: Stopping Wi-Fi scanner...');
    await _wifiScanner.stopScan();

    // Isolate停止
    debugPrint('SensorManager: Stopping sensor isolate...');
    await _stopSensorIsolate();

    debugPrint('SensorManager: Collection stopped successfully');
  }

  /// センサーデータを収集
  void _collectSensorData() {
    if (!_isCollecting) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 各センサーからデータを取得
    final bleData = _bleScanner.getCurrentBleData();
    final magneticData = _magneticSensor.getCurrentMagneticData();
    final wifiData = _wifiScanner.getCurrentWifiData();

    // DataRowを作成
    final dataRow = DataRow(
      timestamp: timestamp,
      bleData: bleData.isNotEmpty ? bleData : null,
      magX: magneticData['magX'],
      magY: magneticData['magY'],
      magZ: magneticData['magZ'],
      wifiData: wifiData.isNotEmpty ? wifiData : null,
    );

    // バッファに追加
    _dataBuffer.add(dataRow);

    // コールバック呼び出し
    onDataCollected?.call(dataRow);
  }

  /// データバッファをフラッシュ
  Future<void> _flushDataBuffer() async {
    if (_dataBuffer.isEmpty) return;

    try {
      final dataToFlush = List<DataRow>.from(_dataBuffer);
      _dataBuffer.clear();

      // Isolateにデータを送信
      if (_isolateSendPort != null) {
        _isolateSendPort!.send(dataToFlush);
      } else {
        // Isolateが利用できない場合は直接DBに保存
        await _databaseHelper.batchInsertDataRows(dataToFlush);
      }
    } catch (e) {
      onError?.call('Failed to flush data buffer: $e');
    }
  }

  /// センサーIsolate開始
  Future<void> _startSensorIsolate() async {
    _isolateReceivePort = ReceivePort();

    _sensorIsolate = await Isolate.spawn(
      _sensorIsolateFunction,
      _isolateReceivePort!.sendPort,
    );

    _isolateSendPort = await _isolateReceivePort!.first as SendPort;

    // Isolateからのメッセージを監視
    _isolateReceivePort!.listen((message) {
      if (message is String && message.startsWith('ERROR:')) {
        onError?.call(message.substring(6));
      }
    });
  }

  /// センサーIsolate停止
  Future<void> _stopSensorIsolate() async {
    _sensorIsolate?.kill();
    _sensorIsolate = null;
    _isolateReceivePort?.close();
    _isolateReceivePort = null;
    _isolateSendPort = null;
  }

  /// Isolate内で実行される関数
  static void _sensorIsolateFunction(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) async {
      if (message is List<DataRow>) {
        try {
          // データベースに保存
          final dbHelper = DatabaseHelper();
          await dbHelper.batchInsertDataRows(message);
        } catch (e) {
          sendPort.send('ERROR:Failed to save data: $e');
        }
      }
    });
  }

  /// 設定を更新
  void updateSettings(Settings settings) {
    _bleScanner.updateFilters(settings.beaconFilters);
    _wifiScanner.updateScanInterval(settings.wifiScanInterval);

    // 地磁気センサーのサンプリングレートは再起動が必要
    if (_magneticSensor.isListening) {
      _magneticSensor.stopListening().then((_) {
        _magneticSensor.startListening(
          samplingRate: settings.magneticSamplingRate,
        );
      });
    }
  }

  /// 現在の収集状態を取得
  bool get isCollecting => _isCollecting;

  /// 各センサーの状態を取得
  Map<String, bool> get sensorStatus => {
    'ble': _bleScanner.isScanning,
    'magnetic': _magneticSensor.isListening,
    'wifi': _wifiScanner.isScanning,
  };

  /// バッファサイズを取得
  int get bufferSize => _dataBuffer.length;

  /// リソースを解放
  void dispose() {
    stopCollection();
    _bleScanner.dispose();
    _magneticSensor.dispose();
    _wifiScanner.dispose();
  }
}
