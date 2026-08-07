import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'stock_detail_page.dart';
import 'top_up_stock_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onRefresh;
  const HomePage({Key? key, this.onRefresh}) : super(key: key);
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map> data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => _loading = true);
    data = await DBHelper.getDashboardData();
    if(mounted) setState(() => _loading = false);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    loadData(); // refresh when parent rebuilds
  }

  Future<void> _confirmDelete(Map stock) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${stock['name']}?'),
        content: Text('This will delete the stock and ALL usage history. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('Delete')),
        ],
      ),
    );
    if(confirm == true) {
      await DBHelper.deleteStock(stock['id']);
      await loadData();
      widget.onRefresh?.call();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Row(children: [Icon(Icons.delete, color: Colors.white), SizedBox(width: 10), Text('${stock['name']} deleted')]), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: EdgeInsets.all(12))
      );
    }
  }

  void _openTopUpForStock(Map stock) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => TopUpStockPage(onAdded: loadData, preselectedStock: stock)));
    if(result == true) await loadData();
  }

  @override
  Widget build(BuildContext context) {
    if(_loading) return Center(child: CircularProgressIndicator());

    double totalStock = data.fold(0, (sum, e) => sum + (e['initialQty'] as num).toDouble());
    double totalUsed = data.fold(0, (sum, e) => sum + (e['totalUsed'] as num).toDouble());
    var lowStock = data.where((e) => (e['currentLeft'] as num).toDouble() < (e['initialQty'] as num).toDouble() * 0.2).toList();

    return RefreshIndicator(
      color: Colors.teal,
      onRefresh: loadData,
      child: data.isEmpty
  ? ListView(children: [SizedBox(height: 120), Center(child: Column(children: [Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey.shade300), SizedBox(height: 16), Text('No stocks yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('Pull down or add your first stock', style: TextStyle(color: Colors.grey))]))])
        : ListView(
          padding: EdgeInsets.all(16),
          children: [
            Row(children: [
              Expanded(child: _statCard('Total Stock', totalStock.toStringAsFixed(1), Icons.inventory, [Colors.blue.shade400, Colors.blue.shade600])),
              SizedBox(width: 12),
              Expanded(child: _statCard('Used', totalUsed.toStringAsFixed(1), Icons.trending_down, [Colors.orange.shade400, Colors.orange.shade600])),
            ]),
            SizedBox(height: 24),
            if(lowStock.isNotEmpty)...[
              Text('Low Stock Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
         ...lowStock.map((e) => Container(margin: EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade100)), child: ListTile(leading: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.warning_amber_rounded, color: Colors.red)), title: Text(e['name'], style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text('${(e['currentLeft'] as num).toStringAsFixed(1)} ${e['unit']} left', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))))),
              SizedBox(height: 12),
            ] else...[
              Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text('All stocks are healthy', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold))])),
              SizedBox(height: 24),
            ],
            Text('All Stocks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
       ...data.map((e) {
              double initial = (e['initialQty'] as num).toDouble();
              double current = (e['currentLeft'] as num).toDouble();
              double progress = initial > 0? (current / initial).clamp(0, 1).toDouble() : 0;
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))]),
                child: ListTile(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailPage(stockId: e['id'])));
                  },
                  contentPadding: EdgeInsets.all(16),
                  leading: CircleAvatar(backgroundColor: Colors.teal.shade100, child: Text(e['name'].toString()[0].toUpperCase(), style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))),
                  title: Text(e['name'].toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.grey.shade200, color: progress < 0.2? Colors.red : Colors.teal)),
                    SizedBox(height: 6),
                    Text('${current.toStringAsFixed(1)} / ${initial.toStringAsFixed(1)} ${e['unit']}', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _openTopUpForStock(e)),
                    IconButton(icon: Icon(Icons.delete_outline, color: Colors.red.shade300), onPressed: () => _confirmDelete(e)),
                  ]),
                )
              );
            })
          ],
        ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, List<Color> gradient) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: gradient[1].withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))]),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 26)),
          SizedBox(height: 14),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(title, style: TextStyle(color: Colors.white70, fontSize: 13))
        ]),
      ),
    );
  }
}