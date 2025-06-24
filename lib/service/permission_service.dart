import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';

/// 権限管理サービス
class PermissionService {
  /// Android SDKバージョンを取得
  Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;
    return int.tryParse(
          defaultTargetPlatform == TargetPlatform.android
              ? await DeviceInfoPlugin().androidInfo.then(
                (info) => info.version.sdkInt.toString(),
              )
              : '0',
        ) ??
        0;
  }

  /// 必要な権限をチェック
  Future<Map<String, bool>> checkRequiredPermissions() async {
    final permissions = <String, bool>{};
    final isAndroid33OrAbove =
        Platform.isAndroid && await _getAndroidSdkVersion() >= 33;

    // 位置情報権限
    permissions['location'] = await Permission.location.isGranted;

    // Bluetooth権限
    permissions['bluetooth'] = await Permission.bluetooth.isGranted;
    permissions['bluetoothScan'] = await Permission.bluetoothScan.isGranted;
    permissions['bluetoothConnect'] =
        await Permission.bluetoothConnect.isGranted;

    // Wi-Fi権限（位置情報権限で代用）
    permissions['wifi'] = await Permission.locationWhenInUse.isGranted;

    // ストレージ権限
    if (isAndroid33OrAbove) {
      permissions['photos'] = await Permission.photos.isGranted;
      // 必要に応じて以下を有効化
      // permissions['videos'] = await Permission.videos.isGranted;
      // permissions['audio'] = await Permission.audio.isGranted;
    } else {
      permissions['storage'] = await Permission.storage.isGranted;
    }

    // カメラ権限（QRコードスキャン用）
    permissions['camera'] = await Permission.camera.isGranted;

    debugPrint('PermissionService: Permission status - $permissions');
    return permissions;
  }

  /// 必要な権限をリクエスト
  Future<Map<String, bool>> requestRequiredPermissions() async {
    final permissions = <String, bool>{};
    final isAndroid33OrAbove =
        Platform.isAndroid && await _getAndroidSdkVersion() >= 33;

    // 位置情報権限
    final locationStatus = await Permission.location.request();
    permissions['location'] = locationStatus.isGranted;

    // Bluetooth権限
    final bluetoothStatus = await Permission.bluetooth.request();
    permissions['bluetooth'] = bluetoothStatus.isGranted;

    final bluetoothScanStatus = await Permission.bluetoothScan.request();
    permissions['bluetoothScan'] = bluetoothScanStatus.isGranted;

    final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    permissions['bluetoothConnect'] = bluetoothConnectStatus.isGranted;

    // Wi-Fi権限（位置情報権限で代用）
    final wifiStatus = await Permission.locationWhenInUse.request();
    permissions['wifi'] = wifiStatus.isGranted;

    // ストレージ権限
    if (isAndroid33OrAbove) {
      final photosStatus = await Permission.photos.request();
      permissions['photos'] = photosStatus.isGranted;
      // 必要に応じて以下を有効化
      // final videosStatus = await Permission.videos.request();
      // permissions['videos'] = videosStatus.isGranted;
      // final audioStatus = await Permission.audio.request();
      // permissions['audio'] = audioStatus.isGranted;
    } else {
      final storageStatus = await Permission.storage.request();
      permissions['storage'] = storageStatus.isGranted;
    }

    // カメラ権限
    final cameraStatus = await Permission.camera.request();
    permissions['camera'] = cameraStatus.isGranted;

    debugPrint('PermissionService: Requested permissions - $permissions');
    return permissions;
  }

  /// 権限が不足しているかチェック
  Future<List<String>> getMissingPermissions() async {
    final currentPermissions = await checkRequiredPermissions();
    final missingPermissions = <String>[];
    final isAndroid33OrAbove =
        Platform.isAndroid && await _getAndroidSdkVersion() >= 33;

    if (!currentPermissions['location']!) {
      missingPermissions.add('Location');
    }

    if (!currentPermissions['bluetooth']! ||
        !currentPermissions['bluetoothScan']! ||
        !currentPermissions['bluetoothConnect']!) {
      missingPermissions.add('Bluetooth');
    }

    if (!currentPermissions['wifi']!) {
      missingPermissions.add('Wi-Fi');
    }

    // ストレージ権限チェック
    if (isAndroid33OrAbove) {
      if (!currentPermissions['photos']!) {
        missingPermissions.add('Photos');
      }
      // 必要に応じて以下を有効化
      // if (!currentPermissions['videos']!) {
      //   missingPermissions.add('Videos');
      // }
      // if (!currentPermissions['audio']!) {
      //   missingPermissions.add('Audio');
      // }
    } else if (!currentPermissions['storage']!) {
      missingPermissions.add('Storage');
    }

    if (!currentPermissions['camera']!) {
      missingPermissions.add('Camera');
    }

    debugPrint('PermissionService: Missing permissions - $missingPermissions');
    return missingPermissions;
  }

  /// 設定画面を開く
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
