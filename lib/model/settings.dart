/// アプリケーション設定
class Settings {
  final int bleScanInterval; // ms
  final int bleScanWindow; // ms
  final int magneticSamplingRate; // Hz
  final int wifiScanInterval; // ms
  final String outputFormat; // 'sqlite' or 'csv'
  final List<String> beaconFilters; // UUIDフィルタ
  final bool enableEncryption;
  final String? s3Bucket;
  final String? s3Region;

  const Settings({
    this.bleScanInterval = 200,
    this.bleScanWindow = 100,
    this.magneticSamplingRate = 50,
    this.wifiScanInterval = 4000,
    this.outputFormat = 'sqlite',
    this.beaconFilters = const [],
    this.enableEncryption = false,
    this.s3Bucket,
    this.s3Region,
  });

  /// デフォルト設定
  factory Settings.defaultSettings() {
    return const Settings();
  }

  /// 設定をコピーして更新
  Settings copyWith({
    int? bleScanInterval,
    int? bleScanWindow,
    int? magneticSamplingRate,
    int? wifiScanInterval,
    String? outputFormat,
    List<String>? beaconFilters,
    bool? enableEncryption,
    String? s3Bucket,
    String? s3Region,
  }) {
    return Settings(
      bleScanInterval: bleScanInterval ?? this.bleScanInterval,
      bleScanWindow: bleScanWindow ?? this.bleScanWindow,
      magneticSamplingRate: magneticSamplingRate ?? this.magneticSamplingRate,
      wifiScanInterval: wifiScanInterval ?? this.wifiScanInterval,
      outputFormat: outputFormat ?? this.outputFormat,
      beaconFilters: beaconFilters ?? this.beaconFilters,
      enableEncryption: enableEncryption ?? this.enableEncryption,
      s3Bucket: s3Bucket ?? this.s3Bucket,
      s3Region: s3Region ?? this.s3Region,
    );
  }

  /// Mapに変換（永続化用）
  Map<String, dynamic> toMap() {
    return {
      'bleScanInterval': bleScanInterval,
      'bleScanWindow': bleScanWindow,
      'magneticSamplingRate': magneticSamplingRate,
      'wifiScanInterval': wifiScanInterval,
      'outputFormat': outputFormat,
      'beaconFilters': beaconFilters,
      'enableEncryption': enableEncryption,
      's3Bucket': s3Bucket,
      's3Region': s3Region,
    };
  }

  /// Mapから設定を作成
  factory Settings.fromMap(Map<String, dynamic> map) {
    return Settings(
      bleScanInterval: map['bleScanInterval'] as int? ?? 200,
      bleScanWindow: map['bleScanWindow'] as int? ?? 100,
      magneticSamplingRate: map['magneticSamplingRate'] as int? ?? 50,
      wifiScanInterval: map['wifiScanInterval'] as int? ?? 4000,
      outputFormat: map['outputFormat'] as String? ?? 'sqlite',
      beaconFilters: (map['beaconFilters'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      enableEncryption: map['enableEncryption'] as bool? ?? false,
      s3Bucket: map['s3Bucket'] as String?,
      s3Region: map['s3Region'] as String?,
    );
  }

  @override
  String toString() {
    return 'Settings(bleScanInterval: $bleScanInterval, bleScanWindow: $bleScanWindow, magneticSamplingRate: $magneticSamplingRate, wifiScanInterval: $wifiScanInterval, outputFormat: $outputFormat, beaconFilters: $beaconFilters, enableEncryption: $enableEncryption, s3Bucket: $s3Bucket, s3Region: $s3Region)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Settings &&
        other.bleScanInterval == bleScanInterval &&
        other.bleScanWindow == bleScanWindow &&
        other.magneticSamplingRate == magneticSamplingRate &&
        other.wifiScanInterval == wifiScanInterval &&
        other.outputFormat == outputFormat &&
        other.beaconFilters.length == beaconFilters.length &&
        other.enableEncryption == enableEncryption &&
        other.s3Bucket == s3Bucket &&
        other.s3Region == s3Region;
  }

  @override
  int get hashCode {
    return Object.hash(
      bleScanInterval,
      bleScanWindow,
      magneticSamplingRate,
      wifiScanInterval,
      outputFormat,
      beaconFilters,
      enableEncryption,
      s3Bucket,
      s3Region,
    );
  }
} 