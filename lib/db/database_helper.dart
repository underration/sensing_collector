import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../model/data_row.dart';

/// SQLiteデータベース操作を管理するクラス
class DatabaseHelper {
  static const String _databaseName = 'sensing_collector.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'raw_log';

  Database? _database;

  /// シングルトンインスタンス
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  /// データベースを取得（初期化済みの場合）
  Database? get databaseInstance => _database;

  /// データベースを初期化
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// データベースを初期化
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// テーブル作成
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        ts INTEGER PRIMARY KEY,
        ble TEXT,
        magx REAL,
        magy REAL,
        magz REAL,
        wifi TEXT,
        label_x REAL,
        label_y REAL
      )
    ''');

    // インデックスを作成（検索性能向上）
    await db.execute('CREATE INDEX idx_ts ON $_tableName (ts)');
  }

  /// データベースアップグレード
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 将来のバージョンアップグレード用
  }

  /// データ行を挿入
  Future<void> insertDataRow(DataRow dataRow) async {
    final db = await database;
    await db.insert(
      _tableName,
      dataRow.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 複数のデータ行をバッチ挿入
  Future<void> batchInsertDataRows(List<DataRow> dataRows) async {
    final db = await database;
    final batch = db.batch();

    for (final dataRow in dataRows) {
      batch.insert(
        _tableName,
        dataRow.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// 指定期間のデータを取得
  Future<List<DataRow>> getDataRows({
    int? startTimestamp,
    int? endTimestamp,
    int limit = 1000,
  }) async {
    debugPrint('DatabaseHelper: getDataRows called with limit=$limit');
    final db = await database;

    String whereClause = '';
    List<Object> whereArgs = [];

    if (startTimestamp != null && endTimestamp != null) {
      whereClause = 'ts BETWEEN ? AND ?';
      whereArgs = [startTimestamp, endTimestamp];
    } else if (startTimestamp != null) {
      whereClause = 'ts >= ?';
      whereArgs = [startTimestamp];
    } else if (endTimestamp != null) {
      whereClause = 'ts <= ?';
      whereArgs = [endTimestamp];
    }

    debugPrint(
      'DatabaseHelper: Query - whereClause: "$whereClause", args: $whereArgs',
    );

    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'ts DESC',
      limit: limit,
    );

    debugPrint('DatabaseHelper: Found ${maps.length} records in database');
    final result = List.generate(maps.length, (i) => DataRow.fromMap(maps[i]));
    debugPrint('DatabaseHelper: Returning ${result.length} DataRow objects');
    return result;
  }

  /// 最新のデータ行を取得
  Future<DataRow?> getLatestDataRow() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'ts DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return DataRow.fromMap(maps.first);
    }
    return null;
  }

  /// データベースの統計情報を取得
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;

    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    final firstResult = await db.rawQuery(
      'SELECT MIN(ts) as first_ts FROM $_tableName',
    );
    final firstTs = Sqflite.firstIntValue(firstResult);

    final lastResult = await db.rawQuery(
      'SELECT MAX(ts) as last_ts FROM $_tableName',
    );
    final lastTs = Sqflite.firstIntValue(lastResult);

    return {
      'total_rows': count,
      'first_timestamp': firstTs,
      'last_timestamp': lastTs,
      'duration_hours':
          firstTs != null && lastTs != null
              ? (lastTs - firstTs) / (1000 * 60 * 60)
              : 0.0,
    };
  }

  /// 古いデータを削除（30日以上前）
  Future<int> deleteOldData({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(Duration(days: daysToKeep));
    final cutoffTimestamp = cutoffTime.millisecondsSinceEpoch;

    return await db.delete(
      _tableName,
      where: 'ts < ?',
      whereArgs: [cutoffTimestamp],
    );
  }

  /// データベースを閉じる
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// CSVファイルにエクスポート
  /// 位置情報（position_x, position_y）も含めて出力します
  Future<File> exportToCsv({int? startTimestamp, int? endTimestamp}) async {
    debugPrint('DatabaseHelper: Starting CSV export...');

    final dataRows = await getDataRows(
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      limit: 1000000, // 大量データ対応
    );

    debugPrint('DatabaseHelper: Retrieved ${dataRows.length} rows for export');

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(join(documentsDirectory.path, 'export_$timestamp.csv'));

    debugPrint('DatabaseHelper: Exporting to ${file.path}');
    final sink = file.openWrite();
    sink.writeln(DataRow.csvHeader);
    int rowCount = 0;
    int positionTaggedRows = 0;
    for (final dataRow in dataRows) {
      final csvRow = dataRow.toCsvRow();
      sink.writeln(csvRow);

      // 位置情報が含まれる行をカウント
      if (dataRow.labelX != null && dataRow.labelY != null) {
        positionTaggedRows++;
      }

      // 最初の5行をデバッグ出力でサンプル確認
      if (rowCount < 5) {
        debugPrint(
          'DatabaseHelper: CSV row $rowCount: ${csvRow.length > 200 ? "${csvRow.substring(0, 200)}..." : csvRow}',
        );
        if (dataRow.labelX != null && dataRow.labelY != null) {
          debugPrint(
            'DatabaseHelper: Row $rowCount has position: X=${dataRow.labelX}, Y=${dataRow.labelY}',
          );
        }
      }
      rowCount++;
    }

    await sink.close();
    final fileSize = await file.length();
    debugPrint(
      'DatabaseHelper: CSV export completed. File size: $fileSize bytes, Rows with position: $positionTaggedRows/$rowCount',
    );

    return file;
  }

  /// データベースファイルのサイズを取得
  Future<int> getDatabaseSize() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    final file = File(path);

    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }
}
