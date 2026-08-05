import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class StockDetailPage extends StatefulWidget {
  final int stockId;
  const StockDetailPage({Key? key, required this.stockId}) : super(key: key);

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  Map? stock;
  List<Map> usage = [];
  List<Map> topups = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  loadData() async {
    stock = await DBHelper.getStockById(widget.stockId);
    usage = await DBHelper.getUsageForStock(widget.stockId);
    topups = await DBHelper.getTopUpsForStock(widget.stockId);
    setState(() => loading = false);
  }

  String formatDate(String raw) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw));
    } catch (e) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    if(loading) return Scaffold(appBar: AppBar(), body: Center(child: CircularProgressIndicator()));
    if(stock == null) return Scaffold(appBar: AppBar(), body: Center(child: Text('Stock not found')));

    double progress = ((stock!['currentLeft'] as num) / (stock!['initialQty'] as num)).clamp(0, 1).toDouble();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(stock!['name'], style: TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.teal, Colors.cyan], begin: Alignment.topLeft, end: Alignment.bottomRight)
                ),
                child: Center(child: Icon(Icons.inventory_2, size: 60, color: Colors.white.withOpacity(0.3))),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STATS CARD
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade600]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))]
                    ),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        _stat('Current', '${(stock!['currentLeft'] as num).toStringAsFixed(1)} ${stock!['unit']}'),
                        _stat('Initial', '${(stock!['initialQty'] as num).toStringAsFixed(1)} ${stock!['unit']}'),
                        _stat('Used', '${(stock!['totalUsed']?? 0).toStringAsFixed(1)} ${stock!['unit']}'),
                      ]),
                      SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress, 
                          minHeight: 8, 
                          backgroundColor: Colors.white24,
                          color: Colors.white,
                        ),
                      )
                    ]),
                  ),
                  SizedBox(height: 24),

                  // TOPUP HISTORY
                  Row(children: [
                    Icon(Icons.add_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Top Up History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  SizedBox(height: 12),
                ...topups.isEmpty? [_emptyState(Icons.add_circle_outline, 'No topups yet')] :
                  topups.map((t) => _historyCard(
                    icon: Icons.add, 
                    color: Colors.green,
                    title: '+${(t['qty'] as num).toStringAsFixed(1)} ${stock!['unit']}',
                    subtitle: formatDate(t['date']),
                    badge: 'ADDED'
                  )),
                  SizedBox(height: 20),

                  // USAGE HISTORY
                  Row(children: [
                    Icon(Icons.remove_circle, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Usage History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  SizedBox(height: 12),
                ...usage.isEmpty? [_emptyState(Icons.remove_circle_outline, 'No usage yet')] :
                  usage.map((u) => _historyCard(
                    icon: Icons.remove, 
                    color: Colors.orange,
                    title: '-${(u['qtyUsed'] as num).toStringAsFixed(1)} ${stock!['unit']}',
                    subtitle: '${u['notes']?? 'No notes'} • ${formatDate(u['date'])}',
                    badge: 'USED'
                  )),
                  SizedBox(height: 40),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.white70)),
    ]);
  }

  Widget _historyCard({required IconData icon, required Color color, required String title, required String subtitle, required String badge}) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: Offset(0, 2))]
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
      child: Center(child: Column(children: [
        Icon(icon, size: 40, color: Colors.grey),
        SizedBox(height: 8),
        Text(text, style: TextStyle(color: Colors.grey))
      ])),
    );
  }
}