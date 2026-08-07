import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // ADD THIS FOR DATE
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
  List<Map<String, dynamic>> _allData = []; // typed
  List<Map<String, dynamic>> data = []; // filtered data shown on screen
  bool _loading = true;
  bool _isFetching = false; // prevent multiple calls

  // SEARCH + FILTER
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (_isFetching) return; // KEY FIX: prevent loop
    _isFetching = true;
    if(mounted) setState(() => _loading = true);

    try {
      final raw = await DBHelper.getDashboardData();
      // KEY FIX FOR RELEASE: mutable copy
      final result = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      _allData = result;
      _applySearch(); // apply search on new data
      widget.onRefresh?.call();
    } catch (e) {
      debugPrint("HOME ERROR: $e");
    }

    if(mounted) setState(() => _loading = false);
    _isFetching = false;
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      data = _allData;
    } else {
      data = _allData.where((s) =>
        s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    if(mounted) setState(() {});
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
    // Show loading only on first load
    if(_loading && _allData.isEmpty) return Center(child: CircularProgressIndicator(color: Colors.teal));

    int totalItems = _allData.length;
    var lowStock = _allData.where((e) => (e['currentLeft'] as num).toDouble() < (e['initialQty'] as num).toDouble() * 0.2).toList();
    String today = DateFormat('EEE, dd MMM yyyy').format(DateTime.now()); // e.g. Fri, 04 Apr 2026

    return RefreshIndicator(
      color: Colors.teal,
      onRefresh: loadData,
      child: CustomScrollView(
        slivers: [
          // SEARCH BAR
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search stock...',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchQuery = '';
                          _applySearch();
                        },
                      )
                    : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _applySearch();
                },
              ),
            ),
          ),

          // STAT CARDS - Always show
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                // CARD 1: UPDATED
                Expanded(child: _statCard(
                  'Welcome back!',
                  '$totalItems Stocks\n$today',
                  Icons.waving_hand_rounded, // better icon
                  [Colors.teal.shade400, Colors.teal.shade600]
                )),
                SizedBox(width: 12),
                // CARD 2: DEVELOPER - UNCHANGED
                Expanded(child: _statCard(
                  'Developer',
                  'puremundex@gmail.com\n@Core-Vanta',
                  Icons.code_rounded,
                  [Colors.purple.shade400, Colors.purple.shade600]
                )),
              ]),
            ),
          ),

          // CONTENT HEADER
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if(lowStock.isNotEmpty)...[
                    Text('Low Stock Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
               ...lowStock.map((e) => Container(margin: EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade100)), child: ListTile(leading: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.warning_amber_rounded, color: Colors.red)), title: Text(e['name'].toString(), style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text('${(e['currentLeft'] as num).toStringAsFixed(1)} ${e['unit']} left', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))))),
                    SizedBox(height: 12),
                  ] else...[
                    Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text('All stocks are healthy', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold))])),
                    SizedBox(height: 24),
                  ],
                  Text('All Stocks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // STOCK LIST OR NO RESULTS
          if(_allData.isEmpty)
            SliverFillRemaining(
              child: ListView(children: [SizedBox(height: 60), Center(child: Column(children: [Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey.shade300), SizedBox(height: 16), Text('No stocks yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('Pull down or add your first stock', style: TextStyle(color: Colors.grey))]))])
            )
          else if(data.isEmpty && _searchQuery.isNotEmpty)
            SliverFillRemaining(
              child: Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No results for "$_searchQuery"')))
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final e = data[index];
                  double initial = (e['initialQty'] as num).toDouble();
                  double current = (e['currentLeft'] as num).toDouble();
                  double progress = initial > 0? (current / initial).clamp(0, 1).toDouble() : 0;
                  return Container(
                    margin: EdgeInsets.only(bottom: 12, left: 16, right: 16),
                    decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))]),
                    child: ListTile(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailPage(stockId: e['id'])));
                        loadData(); // refresh when coming back
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
                },
                childCount: data.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, List<Color> gradient) {
    return Container(
      height: 130,
      decoration: BoxDecoration(gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: gradient[1].withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))]),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white, size: 24)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            SizedBox(height: 2),
            Text(title, style: TextStyle(color: Colors.white70, fontSize: 11))
          ])
        ]),
      ),
    );
  }
}