import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'; // ADD for web

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db!= null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    if (kIsWeb) {
      // KEY FIX 1: WEB SUPPORT
      var factory = databaseFactoryFfiWeb;
      final db = await factory.openDatabase('stocks.db');
      // create tables manually because onCreate doesn't fire on web
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stocks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE,
          initialQty REAL,
          unit TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS usage_log(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stockId INTEGER,
          qtyUsed REAL,
          date TEXT,
          notes TEXT,
          FOREIGN KEY (stockId) REFERENCES stocks(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS topups_log(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          stockId INTEGER,
          qty REAL,
          date TEXT,
          FOREIGN KEY (stockId) REFERENCES stocks(id) ON DELETE CASCADE
        )
      ''');
      return db;
    } else {
      // ANDROID/IOS
      String path = join(await getDatabasesPath(), 'stocks.db');
      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
      );
    }
  }

  static Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE stocks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE,
        initialQty REAL,
        unit TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE usage_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stockId INTEGER,
        qtyUsed REAL,
        date TEXT,
        notes TEXT,
        FOREIGN KEY (stockId) REFERENCES stocks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE topups_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stockId INTEGER,
        qty REAL,
        date TEXT,
        FOREIGN KEY (stockId) REFERENCES stocks(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<int> _getNextId() async {
    return 0;
  }

  static Future<int> addStock(String name, double qty, String unit) async {
    final db = await database;
    await db.delete('stocks', where: 'LOWER(name) =?', whereArgs: [name.trim().toLowerCase()]);
    return await db.insert('stocks', {
      'name': name.trim(),
      'initialQty': qty,
      'unit': unit
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getStocksRaw() async {
    final db = await database;
    final res = await db.query('stocks');
    return res.map((e) => Map<String, dynamic>.from(e)).toList(); // KEY FIX 2: mutable copy
  }

  static Future<List<Map<String, dynamic>>> getStocks() async {
    final db = await database;
    List<Map<String, dynamic>> stocks = await db.query('stocks');
    List<Map<String, dynamic>> usage = await db.query('usage_log');
    List<Map<String, dynamic>> topups = await db.query('topups_log');

    List<Map<String, dynamic>> result = [];
    for (var s in stocks) {
      // KEY FIX 3: mutable copy for release
      Map<String, dynamic> stock = Map<String, dynamic>.from(s);
      double initial = (stock['initialQty'] as num).toDouble();
      double totalUsed = usage
        .where((u) => u['stockId'] == stock['id'])
        .fold(0.0, (sum, u) => sum + (u['qtyUsed'] as num).toDouble());
      double totalTopUp = topups
        .where((t) => t['stockId'] == stock['id'])
        .fold(0.0, (sum, t) => sum + (t['qty'] as num).toDouble());

      stock['totalUsed'] = totalUsed;
      stock['initialQty'] = initial + totalTopUp; // Initial + all topups
      stock['currentLeft'] = (initial + totalTopUp) - totalUsed;
      result.add(stock);
    }
    result.sort((a, b) => (a['currentLeft'] as num).compareTo(b['currentLeft'] as num));
    return result;
  }

  static Future<List<Map<String, dynamic>>> getUsageRaw() async {
    final db = await database;
    final res = await db.query('usage_log');
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addUsage(int stockId, double qtyUsed, String date, String notes) async {
    final db = await database;
    await db.insert('usage_log', {
      'stockId': stockId,
      'qtyUsed': qtyUsed,
      'date': date,
      'notes': notes
    });
  }

  static Future<List<Map<String, dynamic>>> getUsage(int stockId) async {
    final db = await database;
    final res = await db.query('usage_log',
        where: 'stockId =?', whereArgs: [stockId], orderBy: 'date DESC');
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> getTopUpsRaw() async {
    final db = await database;
    final res = await db.query('topups_log');
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> topUpStock(int stockId, double qty) async {
    final db = await database;
    await db.insert('topups_log', {
      'stockId': stockId,
      'qty': qty,
      'date': DateTime.now().toIso8601String().split('T')[0]
    });
  }

  static Future<Map<String, dynamic>?> getStockById(int stockId) async {
    final db = await database;
    final res = await db.query('stocks', where: 'id =?', whereArgs: [stockId], limit: 1);
    if (res.isNotEmpty) {
      final allStocks = await getStocks();
      return allStocks.firstWhere((s) => s['id'] == stockId, orElse: () => Map<String, dynamic>.from(res.first));
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getUsageForStock(int stockId) async {
    return await getUsage(stockId);
  }

  static Future<List<Map<String, dynamic>>> getTopUpsForStock(int stockId) async {
    final db = await database;
    final res = await db.query('topups_log',
        where: 'stockId =?', whereArgs: [stockId], orderBy: 'date DESC');
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<List<Map<String, dynamic>>> getDashboardData() async {
    return await getStocks(); // Same scope as yours
  }

  static Future<void> deleteStock(int id) async {
    final db = await database;
    await db.delete('stocks', where: 'id =?', whereArgs: [id]);
    await db.delete('usage_log', where: 'stockId =?', whereArgs: [id]);
    await db.delete('topups_log', where: 'stockId =?', whereArgs: [id]);
  }
}