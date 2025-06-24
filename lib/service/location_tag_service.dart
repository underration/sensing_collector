import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../model/data_row.dart';

/// 位置ラベル付与サービス
class LocationTagService {
  StreamSubscription<Position>? _locationSubscription;
  bool _isLocationTracking = false;

  /// 手動入力による位置ラベル付与
  DataRow addManualLocationLabel(DataRow dataRow, double x, double y) {
    return DataRow(
      timestamp: dataRow.timestamp,
      bleData: dataRow.bleData,
      magX: dataRow.magX,
      magY: dataRow.magY,
      magZ: dataRow.magZ,
      wifiData: dataRow.wifiData,
      labelX: x,
      labelY: y,
    );
  }

  /// QRコード読み取りによる位置ラベル付与
  Future<DataRow?> addQrLocationLabel(DataRow dataRow, String qrData) async {
    try {
      // QRコードから座標を解析
      final coordinates = _parseQrCoordinates(qrData);
      if (coordinates != null) {
        return DataRow(
          timestamp: dataRow.timestamp,
          bleData: dataRow.bleData,
          magX: dataRow.magX,
          magY: dataRow.magY,
          magZ: dataRow.magZ,
          wifiData: dataRow.wifiData,
          labelX: coordinates['x'],
          labelY: coordinates['y'],
        );
      }
    } catch (e) {
      debugPrint('QR parsing error: $e');
    }
    return null;
  }

  /// GNSS/NTRIPによる位置ラベル付与開始
  Future<void> startGnssLocationTracking() async {
    if (_isLocationTracking) return;

    // 位置情報の権限をチェック
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    _isLocationTracking = true;

    // 高精度位置情報の取得
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // 1メートル移動で更新
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // 位置情報が更新された時の処理
      _onLocationUpdate(position);
    });
  }

  /// GNSS位置追跡停止
  Future<void> stopGnssLocationTracking() async {
    if (!_isLocationTracking) return;

    _isLocationTracking = false;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// 現在の位置情報を取得
  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Failed to get current location: $e');
      return null;
    }
  }

  /// 位置情報更新時のコールバック
  Function(Position)? onLocationUpdate;

  /// 位置情報更新時の処理
  void _onLocationUpdate(Position position) {
    onLocationUpdate?.call(position);
  }

  /// QRコードから座標を解析
  Map<String, double>? _parseQrCoordinates(String qrData) {
    try {
      // QRコードの形式を想定: "x:123.456,y:789.012" または "123.456,789.012"
      if (qrData.contains('x:') && qrData.contains('y:')) {
        // 形式: "x:123.456,y:789.012"
        final xMatch = RegExp(r'x:([\d.-]+)').firstMatch(qrData);
        final yMatch = RegExp(r'y:([\d.-]+)').firstMatch(qrData);

        if (xMatch != null && yMatch != null) {
          return {
            'x': double.parse(xMatch.group(1)!),
            'y': double.parse(yMatch.group(1)!),
          };
        }
      } else {
        // 形式: "123.456,789.012"
        final parts = qrData.split(',');
        if (parts.length == 2) {
          return {
            'x': double.parse(parts[0].trim()),
            'y': double.parse(parts[1].trim()),
          };
        }
      }
    } catch (e) {
      debugPrint('Failed to parse QR coordinates: $e');
    }
    return null;
  }

  /// 位置情報の精度を取得
  Future<LocationAccuracy> getLocationAccuracy() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      // Map the accuracy value (double) to LocationAccuracy enum
      return _mapAccuracyValueToEnum(position.accuracy);
    } catch (e) {
      return LocationAccuracy.low;
    }
  }

  /// double値からLocationAccuracyへのマッピング
  LocationAccuracy _mapAccuracyValueToEnum(double accuracyValue) {
    if (accuracyValue <= 5) {
      return LocationAccuracy.bestForNavigation;
    } else if (accuracyValue <= 10) {
      return LocationAccuracy.best;
    } else if (accuracyValue <= 50) {
      return LocationAccuracy.high;
    } else if (accuracyValue <= 100) {
      return LocationAccuracy.medium;
    } else if (accuracyValue <= 500) {
      return LocationAccuracy.low;
    } else {
      return LocationAccuracy.lowest;
    }
  }

  /// 位置追跡状態を取得
  bool get isLocationTracking => _isLocationTracking;

  /// リソースを解放
  void dispose() {
    stopGnssLocationTracking();
  }
}
