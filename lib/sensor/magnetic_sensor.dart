import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 地磁気センサー
class MagneticSensor {
  StreamSubscription<MagnetometerEvent>? _subscription;
  bool _isListening = false;
  double? _lastMagX;
  double? _lastMagY;
  double? _lastMagZ;

  /// 地磁気センサー開始
  Future<void> startListening({int samplingRate = 50}) async {
    if (_isListening) {
      debugPrint('Magnetic Sensor: Already listening, skipping start');
      return;
    }

    debugPrint('Magnetic Sensor: Starting listening...');

    // センサーが利用可能かチェック
    final isAvailable = await this.isAvailable();
    if (!isAvailable) {
      debugPrint('Magnetic Sensor: Magnetometer is not available');
      throw Exception('Magnetometer is not available on this device');
    }

    _isListening = true;
    debugPrint('Magnetic Sensor: Listening started successfully');

    _subscription = magnetometerEventStream().listen(
      (MagnetometerEvent event) {
        _lastMagX = event.x;
        _lastMagY = event.y;
        _lastMagZ = event.z;
        debugPrint('Magnetic Sensor: x=${event.x.toStringAsFixed(2)}, y=${event.y.toStringAsFixed(2)}, z=${event.z.toStringAsFixed(2)}');
      },
      onError: (error) {
        debugPrint('Magnetic Sensor: Error: $error');
      },
    );
  }

  /// 地磁気センサー停止
  Future<void> stopListening() async {
    if (!_isListening) {
      debugPrint('Magnetic Sensor: Not listening, skipping stop');
      return;
    }

    debugPrint('Magnetic Sensor: Stopping listening...');
    _isListening = false;
    await _subscription?.cancel();
    _subscription = null;
    debugPrint('Magnetic Sensor: Listening stopped successfully');
  }

  /// 最新の地磁気データを取得
  Map<String, double?> getCurrentMagneticData() {
    return {
      'magX': _lastMagX,
      'magY': _lastMagY,
      'magZ': _lastMagZ,
    };
  }

  /// 地磁気データのストリーム
  Stream<MagnetometerEvent> get magneticStream => magnetometerEventStream();

  /// センサーが利用可能かチェック
  Future<bool> isAvailable() async {
    try {
      // センサーが利用可能かテスト
      await magnetometerEventStream().first.timeout(Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 現在のサンプリングレートを取得
  int getCurrentSamplingRate() {
    // 実際のサンプリングレートを計算するロジックを実装
    // 現在は概算値
    return 50; // Hz
  }

  /// センサー状態を取得
  bool get isListening => _isListening;

  /// リソースを解放
  void dispose() {
    stopListening();
  }
} 