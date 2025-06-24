import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/data_row.dart';
import '../model/settings.dart';
import '../db/database_helper.dart';
import '../sensor/sensor_manager.dart';
import '../service/location_tag_service.dart';
import '../service/upload_service.dart';
import '../service/permission_service.dart';

/// アプリケーション状態
class AppState {
  final bool isCollecting;
  final bool isUploading;
  final DataRow? latestDataRow;
  final int bufferSize;
  final Map<String, bool> sensorStatus;
  final Settings settings;
  final Map<String, dynamic> databaseStats;
  final String? errorMessage;
  final Map<String, bool> permissions;

  AppState({
    this.isCollecting = false,
    this.isUploading = false,
    this.latestDataRow,
    this.bufferSize = 0,
    this.sensorStatus = const {},
    required this.settings,
    this.databaseStats = const {},
    this.errorMessage,
    this.permissions = const {},
  });

  AppState copyWith({
    bool? isCollecting,
    bool? isUploading,
    DataRow? latestDataRow,
    int? bufferSize,
    Map<String, bool>? sensorStatus,
    Settings? settings,
    Map<String, dynamic>? databaseStats,
    String? errorMessage,
    Map<String, bool>? permissions,
  }) {
    return AppState(
      isCollecting: isCollecting ?? this.isCollecting,
      isUploading: isUploading ?? this.isUploading,
      latestDataRow: latestDataRow ?? this.latestDataRow,
      bufferSize: bufferSize ?? this.bufferSize,
      sensorStatus: sensorStatus ?? this.sensorStatus,
      settings: settings ?? this.settings,
      databaseStats: databaseStats ?? this.databaseStats,
      errorMessage: errorMessage ?? this.errorMessage,
      permissions: permissions ?? this.permissions,
    );
  }
}

/// アプリケーション状態管理クラス
class AppStateNotifier extends StateNotifier<AppState> {
  final DatabaseHelper _databaseHelper;
  final SensorManager _sensorManager;
  final LocationTagService _locationTagService;
  final UploadService _uploadService;
  final PermissionService _permissionService;

  AppStateNotifier({
    required DatabaseHelper databaseHelper,
    required SensorManager sensorManager,
    required LocationTagService locationTagService,
    required UploadService uploadService,
  }) : _databaseHelper = databaseHelper,
       _sensorManager = sensorManager,
       _locationTagService = locationTagService,
       _uploadService = uploadService,
       _permissionService = PermissionService(),
       super(AppState(settings: Settings.defaultSettings())) {
    _initialize();
  }

  /// 初期化
  Future<void> _initialize() async {
    // 権限チェック
    await _checkPermissions();

    // データベース統計を取得
    await _updateDatabaseStats();

    // センサーマネージャーのコールバックを設定
    _sensorManager.onDataCollected = _onDataCollected;
    _sensorManager.onError = _onSensorError;

    // 位置サービスのコールバックを設定
    _locationTagService.onLocationUpdate = _onLocationUpdate;
  }

  /// 権限チェック
  Future<void> _checkPermissions() async {
    try {
      final permissions = await _permissionService.checkRequiredPermissions();
      state = state.copyWith(permissions: permissions);

      final missingPermissions =
          await _permissionService.getMissingPermissions();
      if (missingPermissions.isNotEmpty) {
        state = state.copyWith(
          errorMessage: 'Missing permissions: ${missingPermissions.join(', ')}',
        );
      }
    } catch (e) {
      debugPrint('Failed to check permissions: $e');
    }
  }

  /// 権限リクエスト
  Future<void> requestPermissions() async {
    try {
      final permissions = await _permissionService.requestRequiredPermissions();
      state = state.copyWith(permissions: permissions);

      final missingPermissions =
          await _permissionService.getMissingPermissions();
      if (missingPermissions.isNotEmpty) {
        state = state.copyWith(
          errorMessage:
              'Some permissions are still missing: ${missingPermissions.join(', ')}',
        );
      } else {
        state = state.copyWith(errorMessage: null);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to request permissions: $e');
    }
  }

  /// データ収集開始
  Future<void> startCollection() async {
    try {
      // 権限チェック
      final missingPermissions =
          await _permissionService
              .getMissingPermissions(); // カメラとストレージ系権限は無視（データ収集に必須ではないため）
      final filteredMissing =
          missingPermissions
              .where(
                (p) =>
                    !p.contains('Camera') &&
                    !p.contains('Photos') &&
                    !p.contains('Videos') &&
                    !p.contains('Audio') &&
                    !p.contains('Storage') &&
                    !p.contains('Media Access'),
              )
              .toList();
      if (filteredMissing.isNotEmpty) {
        state = state.copyWith(
          errorMessage:
              'Cannot start collection. Missing permissions: ${filteredMissing.join(', ')}',
        );
        return;
      }

      state = state.copyWith(errorMessage: null);

      await _sensorManager.startCollection(settings: state.settings);

      // センサー開始直後にステータスを更新
      state = state.copyWith(
        isCollecting: true,
        sensorStatus: _sensorManager.sensorStatus,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to start collection: $e');
    }
  }

  /// データ収集停止
  Future<void> stopCollection() async {
    try {
      await _sensorManager.stopCollection();

      // センサー停止直後にステータスを更新
      state = state.copyWith(
        isCollecting: false,
        sensorStatus: _sensorManager.sensorStatus,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to stop collection: $e');
    }
  }

  /// 設定を更新
  Future<void> updateSettings(Settings newSettings) async {
    state = state.copyWith(settings: newSettings);

    // センサーマネージャーに設定を反映
    _sensorManager.updateSettings(newSettings);
  }

  /// 手動位置ラベル付与
  Future<void> addManualLocationLabel(double x, double y) async {
    if (state.latestDataRow == null) return;

    try {
      final updatedDataRow = _locationTagService.addManualLocationLabel(
        state.latestDataRow!,
        x,
        y,
      );

      // データベースに保存
      await _databaseHelper.insertDataRow(updatedDataRow);

      state = state.copyWith(latestDataRow: updatedDataRow);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to add location label: $e');
    }
  }

  /// QRコード位置ラベル付与
  Future<void> addQrLocationLabel(String qrData) async {
    if (state.latestDataRow == null) return;

    try {
      final updatedDataRow = await _locationTagService.addQrLocationLabel(
        state.latestDataRow!,
        qrData,
      );

      if (updatedDataRow != null) {
        // データベースに保存
        await _databaseHelper.insertDataRow(updatedDataRow);

        state = state.copyWith(latestDataRow: updatedDataRow);
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to add QR location label: $e',
      );
    }
  }

  /// GNSS位置追跡開始
  Future<void> startGnssTracking() async {
    try {
      await _locationTagService.startGnssLocationTracking();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to start GNSS tracking: $e');
    }
  }

  /// GNSS位置追跡停止
  Future<void> stopGnssTracking() async {
    try {
      await _locationTagService.stopGnssLocationTracking();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to stop GNSS tracking: $e');
    }
  }

  /// 手動アップロード
  Future<void> manualUpload() async {
    try {
      state = state.copyWith(isUploading: true, errorMessage: null);

      await _uploadService.manualUpload();

      state = state.copyWith(isUploading: false);

      // データベース統計を更新
      await _updateDatabaseStats();
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: 'Upload failed: $e',
      );
    }
  }

  /// データベース統計を更新
  Future<void> _updateDatabaseStats() async {
    try {
      final stats = await _databaseHelper.getDatabaseStats();
      state = state.copyWith(databaseStats: stats);
    } catch (e) {
      debugPrint('Failed to update database stats: $e');
    }
  }

  /// センサーデータ収集時のコールバック
  void _onDataCollected(DataRow dataRow) {
    state = state.copyWith(
      latestDataRow: dataRow,
      bufferSize: _sensorManager.bufferSize,
      sensorStatus: _sensorManager.sensorStatus,
    );
  }

  /// センサーエラー時のコールバック
  void _onSensorError(String error) {
    state = state.copyWith(errorMessage: error);
  }

  /// 位置情報更新時のコールバック
  void _onLocationUpdate(dynamic position) {
    // 位置情報が更新された場合の処理
    // 必要に応じて最新のDataRowに位置ラベルを追加
  }

  /// エラーメッセージをクリア
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// リソースを解放
  @override
  void dispose() {
    _sensorManager.dispose();
    _locationTagService.dispose();
    _uploadService.dispose();
    super.dispose();
  }
}

/// プロバイダー定義
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});

final settingsProvider = StateProvider<Settings>((ref) {
  return Settings.defaultSettings();
});

final sensorManagerProvider = Provider<SensorManager>((ref) {
  final settings = ref.watch(settingsProvider);
  final databaseHelper = ref.watch(databaseHelperProvider);
  return SensorManager(settings: settings, databaseHelper: databaseHelper);
});

final locationTagServiceProvider = Provider<LocationTagService>((ref) {
  return LocationTagService();
});

final uploadServiceProvider = Provider<UploadService>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return UploadService(databaseHelper: databaseHelper);
});

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((
  ref,
) {
  return AppStateNotifier(
    databaseHelper: ref.watch(databaseHelperProvider),
    sensorManager: ref.watch(sensorManagerProvider),
    locationTagService: ref.watch(locationTagServiceProvider),
    uploadService: ref.watch(uploadServiceProvider),
  );
});
