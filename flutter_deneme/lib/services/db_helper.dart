import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ocr_result.dart';

class DBHelper {
  static const String _dbName = 'ocr_app.db';
  static const int _dbVersion = 3;
  static Database? _db;

  /// Singleton database getter
  static Future<Database> get database async {
    if (_db != null) return _db!;
    final documents = await getApplicationDocumentsDirectory();
    final path = join(documents.path, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  /// Initial table creation
  static Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE results(
        id INTEGER PRIMARY KEY,
        imagePath TEXT,
        text TEXT,
        timestamp TEXT,
        lectureCode TEXT,
        note TEXT,
        tags TEXT
      )
    ''');
  }

  /// Handle schema migrations
  static Future _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      // v2 adds lectureCode
      await db.execute(
        'ALTER TABLE results ADD COLUMN lectureCode TEXT'
      );
    }
    if (oldV < 3) {
      // v3 adds note and tags
      await db.execute(
        'ALTER TABLE results ADD COLUMN note TEXT'
      );
      await db.execute(
        'ALTER TABLE results ADD COLUMN tags TEXT'
      );
    }
  }

  /// In DBHelper:
static Future<List<String>> getDistinctLectureCodes() async {
  final db = await database;
  // Only non-null, non-empty lectureCode values
  final maps = await db.query(
    'results',
    distinct: true,
    columns: ['lectureCode'],
    where: 'lectureCode IS NOT NULL AND lectureCode != ""',
  );
  // Extract the String out of each map
  return maps
      .map((m) => m['lectureCode'] as String)
      .toList()
    ..sort(); // optional alphabetical sort
}


  /// Fetch all records
  static Future<List<OCRResult>> getResults() async {
    final db = await database;
    final maps = await db.query('results');
    return maps.map((m) => OCRResult.fromMap(m)).toList();
  }

  /// Insert a new record
  static Future<int> insertResult(OCRResult r) async {
    final db = await database;
    return db.insert('results', r.toMap());
  }

  /// Update existing record
  static Future<int> updateResult(OCRResult r) async {
    final db = await database;
    return db.update(
      'results',
      r.toMap(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  /// Delete a single record
  static Future<int> deleteResult(int id) async {
    final db = await database;
    return db.delete('results', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all records
  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('results');
  }

  /// Backup all records to a local JSON file
  static Future<String> backupToJson() async {
    final results = await getResults();
    final jsonStr = jsonEncode(results.map((r) => r.toMap()).toList());
    final dir = await getExternalStorageDirectory();
    final file = File(join(
      dir!.path,
      'ocr_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    ));
    await file.writeAsString(jsonStr);
    return file.path;
  }

  /// Restore records from a JSON file
  static Future<void> restoreFromJson(String filePath) async {
    final content = await File(filePath).readAsString();
    final List list = jsonDecode(content);
    for (final map in list) {
      final r = OCRResult.fromMap(Map<String, dynamic>.from(map));
      await insertResult(r);
    }
  }
}
