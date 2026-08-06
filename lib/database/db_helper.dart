import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db!= null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'stocks.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
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
    // Not needed with AUTOINCREMENT, but kept for compatibility
    return 0;
  }

  static Future<int> addStock(String name, double qty, String unit) async {
    final db = await database;
    // Same behavior as before: replace if name exists
    await db.delete('stocks', where: 'LOWER(name) =?', whereArgs: [name.trim().toLowerCase()]);
    return await db.insert('stocks', {
      'name': name.trim(),
      'initialQty': qty,
      'unit': unit
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> getStocksRaw() async {
    final db = await database;
    return await db.query('stocks');
  }

  static Future<List<Map<String, dynamic>>> getStocks() async {
    final db = await database;
    List<Map<String, dynamic>> stocks = await db.query('stocks');
    List<Map<String, dynamic>> usage = await db.query('usage_log');
    List<Map<String, dynamic>> topups = await db.query('topups_log');

    for (var s in stocks) {
      double initial = (s['initialQty'] as num).toDouble();
      double totalUsed = usage
         .where((u) => u['stockId'] == s['id'])
         .fold(0.0, (sum, u) => sum + (u['qtyUsed'] as num).toDouble());
      double totalTopUp = topups
         .where((t) => t['stockId'] == s['id'])
         .fold(0.0, (sum, t) => sum + (t['qty'] as num).toDouble());

      s['totalUsed'] = totalUsed;
      s['initialQty'] = initial + totalTopUp; // Initial + all topups
      s['currentLeft'] = (initial + totalTopUp) - totalUsed;
    }
    stocks.sort((a, b) => (a['currentLeft'] as num).compareTo(b['currentLeft'] as num));
    return stocks;
  }

  static Future<List<Map<String, dynamic>>> getUsageRaw() async {
    final db = await database;
    return await db.query('usage_log');
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
    return await db.query('usage_log',
        where: 'stockId =?', whereArgs: [stockId], orderBy: 'date DESC');
  }

  static Future<List<Map<String, dynamic>>> getTopUpsRaw() async {
    final db = await database;
    return await db.query('topups_log');
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
      // Add calculated fields like getStocks does
      final stock = res.first;
      final allStocks = await getStocks();
      return allStocks.firstWhere((s) => s['id'] == stockId, orElse: () => stock);
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getUsageForStock(int stockId) async {
    return await getUsage(stockId);
  }

  static Future<List<Map<String, dynamic>>> getTopUpsForStock(int stockId) async {
    final db = await database;
    return await db.query('topups_log',
        where: 'stockId =?', whereArgs: [stockId], orderBy: 'date DESC');
  }

  static Future<List<Map<String, dynamic>>> getDashboardData() async {
    return await getStocks();
  }

  static Future<void> deleteStock(int id) async {
    final db = await database;
    await db.delete('stocks', where: 'id =?', whereArgs: [id]);
    await db.delete('usage_log', where: 'stockId =?', whereArgs: [id]);
    await db.delete('topups_log', where: 'stockId =?', whereArgs: [id]);
  }
}