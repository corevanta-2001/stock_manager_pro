import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';

class ExportService {
  static Future<void> exportStocksToCSV() async {
    final stocks = await DBHelper.getStocks(); // uses your existing function
    
    // CSV Headers
    List<List<dynamic>> rows = [];
    rows.add(['Name', 'Unit', 'Initial Qty', 'Total TopUp', 'Total Used', 'Current Left', 'Status']);

    for (var s in stocks) {
      double initial = (s['initialQty'] as num).toDouble();
      double current = (s['currentLeft'] as num).toDouble();
      double totalUsed = (s['totalUsed'] as num).toDouble();
      double topUp = initial - (s['initialQty'] as num).toDouble() + totalUsed; // approx
      
      String status = current < initial * 0.2 ? 'LOW' : 'OK';

      rows.add([
        s['name'],
        s['unit'],
        initial.toStringAsFixed(2),
        topUp.toStringAsFixed(2),
        totalUsed.toStringAsFixed(2),
        current.toStringAsFixed(2),
        status
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    // Save file
    final dir = await getApplicationDocumentsDirectory();
    final date = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
    final file = File('${dir.path}/Stock_Report_$date.csv');
    await file.writeAsString(csv);

    // Share it
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Stock Report - $date',
    );
  }
}