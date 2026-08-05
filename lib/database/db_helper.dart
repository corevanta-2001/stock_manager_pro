import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DBHelper {
  static const _stocksKey = 'stocks';
  static const _usageKey = 'usage_log';
  static const _topupsKey = 'topups_log'; // NEW

  static Future<int> _getNextId() async {
    final prefs = await SharedPreferences.getInstance();
    int id = prefs.getInt('id_counter')?? 1;
    await prefs.setInt('id_counter', id + 1);
    return id;
  }

  static Future<int> addStock(String name, double qty, String unit) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map> stocks = await getStocksRaw();
    stocks.removeWhere((s) => s['name'].toString().toLowerCase() == name.trim().toLowerCase());
    int newId = await _getNextId();
    stocks.add({'id': newId, 'name': name.trim(), 'initialQty': qty, 'unit': unit});
    await prefs.setString(_stocksKey, jsonEncode(stocks));
    return newId;
  }

  static Future<List<Map>> getStocksRaw() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_stocksKey);
    if (data == null) return [];
    try {
      List decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch(e) { return []; }
  }

  static Future<List<Map>> getStocks() async {
    List<Map> stocks = await getStocksRaw();
    List<Map> usage = await getUsageRaw();
    List<Map> topups = await getTopUpsRaw(); // NEW

    for (var s in stocks) {
      double initial = (s['initialQty'] as num).toDouble();
      double totalUsed = usage.where((u) => u['stockId'] == s['id']).fold(0.0, (sum, u) => sum + (u['qtyUsed'] as num).toDouble());
      double totalTopUp = topups.where((t) => t['stockId'] == s['id']).fold(0.0, (sum, t) => sum + (t['qty'] as num).toDouble()); // NEW

      s['totalUsed'] = totalUsed;
      s['initialQty'] = initial + totalTopUp; // Initial + all topups
      s['currentLeft'] = (initial + totalTopUp) - totalUsed; // ensure double
    }
    stocks.sort((a,b) => (a['currentLeft'] as num).compareTo(b['currentLeft'] as num));
    return stocks;
  }

  static Future<List<Map>> getUsageRaw() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_usageKey);
    if (data == null) return [];
    try {
      List decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch(e) { return []; }
  }

  static Future<void> addUsage(int stockId, double qtyUsed, String date, String notes) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map> usage = await getUsageRaw();
    int newId = await _getNextId();
    usage.add({'id': newId, 'stockId': stockId, 'qtyUsed': qtyUsed, 'date': date, 'notes': notes});
    await prefs.setString(_usageKey, jsonEncode(usage));
  }

  static Future<List<Map>> getUsage(int stockId) async {
    List<Map> usage = await getUsageRaw();
    usage = usage.where((u) => u['stockId'] == stockId).toList();
    usage.sort((a,b) => b['date'].compareTo(a['date']));
    return usage;
  }

  // ====== NEW FUNCTIONS FOR TOPUP + HISTORY ======

  static Future<List<Map>> getTopUpsRaw() async { // NEW
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_topupsKey);
    if (data == null) return [];
    try {
      List decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch(e) { return []; }
  }

  static Future<void> topUpStock(int stockId, double qty) async { // NEW
    final prefs = await SharedPreferences.getInstance();
    List<Map> topups = await getTopUpsRaw();
    int newId = await _getNextId();
    topups.add({'id': newId, 'stockId': stockId, 'qty': qty, 'date': DateTime.now().toIso8601String().split('T')[0]});
    await prefs.setString(_topupsKey, jsonEncode(topups));
  }

  static Future<Map?> getStockById(int stockId) async { // NEW
    List<Map> stocks = await getStocks();
    try {
      return stocks.firstWhere((s) => s['id'] == stockId);
    } catch(e) {
      return null;
    }
  }

  static Future<List<Map>> getUsageForStock(int stockId) async { // NEW
    return await getUsage(stockId);
  }

  static Future<List<Map>> getTopUpsForStock(int stockId) async { // NEW
    List<Map> topups = await getTopUpsRaw();
    topups = topups.where((t) => t['stockId'] == stockId).toList();
    topups.sort((a,b) => b['date'].compareTo(a['date']));
    return topups;
  }
  // ====== END NEW FUNCTIONS ======

  static Future<List<Map>> getDashboardData() async {
    return await getStocks();
  }

  static Future<void> deleteStock(int id) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map> stocks = await getStocksRaw();
    List<Map> usage = await getUsageRaw();
    List<Map> topups = await getTopUpsRaw(); // NEW
    stocks.removeWhere((s) => s['id'] == id);
    usage.removeWhere((u) => u['stockId'] == id);
    topups.removeWhere((t) => t['stockId'] == id); // NEW
    await prefs.setString(_stocksKey, jsonEncode(stocks));
    await prefs.setString(_usageKey, jsonEncode(usage));
    await prefs.setString(_topupsKey, jsonEncode(topups)); // NEW
  }
}