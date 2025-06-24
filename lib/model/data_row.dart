import 'dart:convert';

/// 1行分のセンサー値とオプションのラベルを保持するエンティティ
class DataRow {
  final int timestamp;
  final List<BleData>? bleData;
  final double? magX;
  final double? magY;
  final double? magZ;
  final List<WifiData>? wifiData;
  final double? labelX;
  final double? labelY;

  DataRow({
    required this.timestamp,
    this.bleData,
    this.magX,
    this.magY,
    this.magZ,
    this.wifiData,
    this.labelX,
    this.labelY,
  });

  /// SQLiteテーブル用のMapに変換
  Map<String, dynamic> toMap() {
    return {
      'ts': timestamp,
      'ble': bleData != null ? jsonEncode(bleData!.map((e) => e.toMap()).toList()) : null,
      'magx': magX,
      'magy': magY,
      'magz': magZ,
      'wifi': wifiData != null ? jsonEncode(wifiData!.map((e) => e.toMap()).toList()) : null,
      'label_x': labelX,
      'label_y': labelY,
    };
  }

  /// MapからDataRowを作成
  factory DataRow.fromMap(Map<String, dynamic> map) {
    return DataRow(
      timestamp: map['ts'] as int,
      bleData: map['ble'] != null 
          ? (jsonDecode(map['ble'] as String) as List)
              .map((e) => BleData.fromMap(e as Map<String, dynamic>))
              .toList()
          : null,
      magX: map['magx'] as double?,
      magY: map['magy'] as double?,
      magZ: map['magz'] as double?,
      wifiData: map['wifi'] != null 
          ? (jsonDecode(map['wifi'] as String) as List)
              .map((e) => WifiData.fromMap(e as Map<String, dynamic>))
              .toList()
          : null,
      labelX: map['label_x'] as double?,
      labelY: map['label_y'] as double?,
    );
  }

  /// CSV行に変換
  String toCsvRow() {
    final bleJson = bleData != null ? jsonEncode(bleData!.map((e) => e.toMap()).toList()) : '';
    final wifiJson = wifiData != null ? jsonEncode(wifiData!.map((e) => e.toMap()).toList()) : '';
    
    return [
      timestamp.toString(),
      bleJson,
      magX?.toString() ?? '',
      magY?.toString() ?? '',
      magZ?.toString() ?? '',
      wifiJson,
      labelX?.toString() ?? '',
      labelY?.toString() ?? '',
    ].join(',');
  }

  /// CSVヘッダー行
  static String get csvHeader => 'ts,ble,magx,magy,magz,wifi,label_x,label_y';

  @override
  String toString() {
    return 'DataRow(timestamp: $timestamp, bleData: $bleData, magX: $magX, magY: $magY, magZ: $magZ, wifiData: $wifiData, labelX: $labelX, labelY: $labelY)';
  }
}

/// BLEデータ
class BleData {
  final String id;
  final int rssi;
  final int? txPower;

  BleData({
    required this.id,
    required this.rssi,
    this.txPower,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'r': rssi,
      if (txPower != null) 'tx': txPower,
    };
  }

  factory BleData.fromMap(Map<String, dynamic> map) {
    return BleData(
      id: map['id'] as String,
      rssi: map['r'] as int,
      txPower: map['tx'] as int?,
    );
  }

  @override
  String toString() {
    return 'BleData(id: $id, rssi: $rssi, txPower: $txPower)';
  }
}

/// Wi-Fiデータ
class WifiData {
  final String bssid;
  final String ssid;
  final int rssi;
  final int frequency;

  WifiData({
    required this.bssid,
    required this.ssid,
    required this.rssi,
    required this.frequency,
  });

  Map<String, dynamic> toMap() {
    return {
      'b': bssid,
      's': ssid,
      'r': rssi,
      'f': frequency,
    };
  }

  factory WifiData.fromMap(Map<String, dynamic> map) {
    return WifiData(
      bssid: map['b'] as String,
      ssid: map['s'] as String,
      rssi: map['r'] as int,
      frequency: map['f'] as int,
    );
  }

  @override
  String toString() {
    return 'WifiData(bssid: $bssid, ssid: $ssid, rssi: $rssi, frequency: $frequency)';
  }
} 