import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../db/database_helper.dart';
import '../model/settings.dart';

/// クラウド同期サービス
class UploadService {
  final DatabaseHelper _databaseHelper;
  final Dio _dio;
  Timer? _uploadTimer;
  bool _isUploading = false;
  
  // アップロード設定
  String? _s3Bucket;
  String? _s3Region;
  String? _accessKey;
  String? _secretKey;

  UploadService({required DatabaseHelper databaseHelper})
      : _databaseHelper = databaseHelper,
        _dio = Dio() {
    _setupDio();
  }

  /// Dioの設定
  void _setupDio() {
    _dio.options.connectTimeout = Duration(seconds: 30);
    _dio.options.receiveTimeout = Duration(seconds: 30);
    _dio.options.sendTimeout = Duration(seconds: 30);
    
    // リトライ設定
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          // タイムアウトの場合はリトライ
          await Future.delayed(Duration(seconds: 5));
          handler.resolve(await _dio.fetch(error.requestOptions));
        } else {
          handler.next(error);
        }
      },
    ));
  }

  /// S3設定を更新
  void updateS3Settings({
    required String bucket,
    required String region,
    required String accessKey,
    required String secretKey,
  }) {
    _s3Bucket = bucket;
    _s3Region = region;
    _accessKey = accessKey;
    _secretKey = secretKey;
  }

  /// 自動アップロード開始
  Future<void> startAutoUpload({int checkInterval = 60000}) async {
    // Wi-Fi接続を監視してアップロード
    _uploadTimer = Timer.periodic(Duration(milliseconds: checkInterval), (timer) {
      _checkAndUpload();
    });
  }

  /// 自動アップロード停止
  void stopAutoUpload() {
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  /// アップロード条件をチェックして実行
  Future<void> _checkAndUpload() async {
    if (_isUploading) return;

    try {
      // Wi-Fi接続をチェック
      final isConnected = await _checkWifiConnection();
      if (!isConnected) return;

      // 未アップロードデータがあるかチェック
      final hasUnuploadedData = await _hasUnuploadedData();
      if (!hasUnuploadedData) return;

      // アップロード実行
      await _uploadData();
    } catch (e) {
      debugPrint('Auto upload check failed: $e');
    }
  }

  /// Wi-Fi接続をチェック
  Future<bool> _checkWifiConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 未アップロードデータがあるかチェック
  Future<bool> _hasUnuploadedData() async {
    try {
      final stats = await _databaseHelper.getDatabaseStats();
      return stats['total_rows'] > 0;
    } catch (e) {
      return false;
    }
  }

  /// データをアップロード
  Future<void> _uploadData() async {
    if (_isUploading) return;
    _isUploading = true;

    try {
      // CSVファイルにエクスポート
      final csvFile = await _databaseHelper.exportToCsv();
      
      // S3にアップロード
      await _uploadToS3(csvFile);
      
      // アップロード成功後、古いデータを削除
      await _databaseHelper.deleteOldData(daysToKeep: 7);
      
    } catch (e) {
      debugPrint('Upload failed: $e');
      rethrow;
    } finally {
      _isUploading = false;
    }
  }

  /// S3にアップロード
  Future<void> _uploadToS3(File file) async {
    if (_s3Bucket == null || _s3Region == null || 
        _accessKey == null || _secretKey == null) {
      throw Exception('S3 settings not configured');
    }

    final date = DateTime.now();
    final dateString = '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final fileName = 'sensing_data_${date.millisecondsSinceEpoch}.csv';
    final s3Key = 'omu-data-raw/$dateString/$fileName';

    final url = 'https://$_s3Bucket.s3.$_s3Region.amazonaws.com/$s3Key';

    // ファイルを読み込み
    final bytes = await file.readAsBytes();

    // S3にPUT
    final response = await _dio.put(
      url,
      data: bytes,
      options: Options(
        headers: {
          'Content-Type': 'text/csv',
          'Content-Length': bytes.length.toString(),
        },
        extra: {
          'aws_access_key_id': _accessKey,
          'aws_secret_access_key': _secretKey,
        },
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('S3 upload failed with status: ${response.statusCode}');
    }

    // アップロード成功後、ローカルファイルを削除
    await file.delete();
  }

  /// 手動アップロード
  Future<void> manualUpload() async {
    await _uploadData();
  }

  /// アップロード状態を取得
  bool get isUploading => _isUploading;

  /// アップロード設定が完了しているかチェック
  bool get isConfigured => _s3Bucket != null && _s3Region != null && 
                          _accessKey != null && _secretKey != null;

  /// リソースを解放
  void dispose() {
    stopAutoUpload();
    _dio.close();
  }
} 