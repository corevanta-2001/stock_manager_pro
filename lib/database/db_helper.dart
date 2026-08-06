import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DBHelper {
  static const _stocksKey = 'stocks';
  static const _usageKey = 'usage_log';
  static const _topupsKey = 'topups_log';

  static Future<int> _getNextId() async {
    final prefs = await SharedPreferences.getInstance();
    int id = prefs.getInt('id_counter')?? 1;
    await prefs.setInt('id_counter', id + 1);
    return id;
  }

  static Future<int> addStock(String name, double qty, String unit) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> stocks = await getStocksRaw(); // <-- ADD TYPE

    String newName = name.trim().toLowerCase();
    // SAFE CHECK: avoid.toString() on null
    stocks.removeWhere((s) => (s['name']?.toString().toLowerCase()?? '') == newName);

    int newId = await _getNextId();
    stocks.add({'id': newId, 'name': name.trim(), 'initialQty': qty, 'unit': unit});
    await prefs.setString(_stocksKey, jsonEncode(stocks));
    return newId;
  }

  static Future<List<Map<String, dynamic>>> getStocksRaw() async { // <-- ADD TYPE
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_stocksKey);
    if (data == null || data.isEmpty) return []; // <-- ADD EMPTY CHECK
    try {
      final List decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList(); // <-- CAST
    } catch(e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getStocks() async { // <-- ADD TYPE
    List<Map<String, dynamic>> stocks = await getStocksRaw();
    List<Map<String, dynamic>> usage = await getUsageRaw();
    List<Map<String, dynamic>> topups = await getTopUpsRaw();

    for (var s in stocks) {
      double initial = (s['initialQty'] as num?)?.toDouble()?? 0.0; // <-- NULL SAFE
      double totalUsed = usage.where((u) => u['stockId'] == s['id']).fold(0.0, (sum, u) => sum + ((u['qtyUsed'] as num?)?.toDouble()?? 0.0));
      double totalTopUp = topups.where((t) => t['stockId'] == s['id']).fold(0.0, (sum, t) => sum + ((t['qty'] as num?)?.toDouble()?? 0.0));

      s['totalUsed'] = totalUsed;
      s['initialQty'] = initial + totalTopUp;
      s['currentLeft'] = (initial + totalTopUp) - totalUsed;
    }
    stocks.sort((a,b) => ((a['currentLeft'] as num?)?.toDouble()?? 0.0).compareTo((b['currentLeft'] as num?)?.toDouble()?? 0.0));
    return stocks;
  }

  static Future<List<Map<String, dynamic>>> getUsageRaw() async { // <-- ADD TYPE
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_usageKey);
    if (data == null || data.isEmpty) return [];
    try {
      final List decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch(e) { return []; }
  }

  static Future<void> addUsage(int stockId, double qtyUsed, String date, String notes) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> usage = await getUsageRaw();
    int newId = await _getNextId();
    usage.add({'id': newId, 'stockId': stockId, 'qtyUsed': qtyUsed, 'date': date, 'notes': notes});
    await prefs.setString(_usageKey, jsonEncode(usage));
  }

  static Future<List<Map<String, dynamic>>> getUsage(int stockId) async { // <-- ADD TYPE
    List<Map<String, dynamic>> usage = await getUsageRaw();
    usage = usage.where((u) => u['stockId'] == stockId).toList();
    usage.sort((a,b) => b['date'].toString().compareTo(a['date'].toString()));
    return usage;
  }

  static Future<List<Map<String, dynamic>>> getTopUpsRaw() async { // <-- ADD TYPE
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_topupsKey);
    if (data == null || data.isEmpty) return [];
    try {
      final List decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch(e) { return []; }
  }

  static Future<void> topUpStock(int stockId, double qty) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> topups = await getTopUpsRaw();
    int newId = await _getNextId();
    topups.add({'id': newId, 'stockId': stockId, 'qty': qty, 'date': DateTime.now().toIso8601String().split('T')[0]});
    await prefs.setString(_topupsKey, jsonEncode(topups));
  }

  static Future<Map<String, dynamic>?> getStockById(int stockId) async { // <-- ADD TYPE
    List<Map<String, dynamic>> stocks = await getStocks();
    try {
      return stocks.firstWhere((s) => s['id'] == stockId);
    } catch(e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getUsageForStock(int stockId) async {
    return await getUsage(stockId);
  }

  static Future<List<Map<String, dynamic>>> getTopUpsForStock(int stockId) async { // <-- ADD TYPE
    List<Map<String, dynamic>> topups = await getTopUpsRaw();
    topups = topups.where((t) => t['stockId'] == stockId).toList();
    topups.sort((a,b) => b['date'].toString().compareTo(a['date'].toString()));
    return topups;
  }

  static Future<List<Map<String, dynamic>>> getDashboardData() async { // <-- ADD TYPE
    return await getStocks();
  }

  static Future<void> deleteStock(int id) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> stocks = await getStocksRaw();
    List<Map<String, dynamic>> usage = await getUsageRaw();
    List<Map<String, dynamic>> topups = await getTopUpsRaw();
    stocks.removeWhere((s) => s['id'] == id);
    usage.removeWhere((u) => u['stockId'] == id);
    topups.removeWhere((t) => t['stockId'] == id);
    await prefs.setString(_stocksKey, jsonEncode(stocks));
    await prefs.setString(_usageKey, jsonEncode(usage));
    await prefs.setString(_topupsKey, jsonEncode(topups));
  }
}