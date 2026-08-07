import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'database/db_helper.dart';
import 'pages/home_page.dart';
import 'pages/add_stock_page.dart';
import 'pages/add_usage_page.dart';
import 'pages/analytics_page.dart';
import 'pages/top_up_stock_page.dart';
import 'pages/stock_detail_page.dart';
import 'pages/todo_page.dart';

void main() => runApp(StockApp());

class StockApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Manager Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  List<Map> stocks = [];

  // KEY FIX: rebuild pages every build so they get fresh callback
  List<Widget> get pages => [
    HomePage(onRefresh: loadStocks),
    AddUsagePage(onAdded: loadStocks),
    TodoPage(),
    AnalyticsPage(onRefresh: loadStocks), // CHANGED: pass refresh
  ];

  final titles = ['Dashboard', 'Log Usage', 'To-Do', 'Analytics'];

  @override
  void initState() {
    super.initState();
    loadStocks();
  }

  Future<void> loadStocks() async {
    stocks = await DBHelper.getStocks();
    if(mounted) setState(() {});
  }

  void _openAddStockPage() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => AddStockPage(onAdded: loadStocks))
    );
    if(result == true) { 
      setState(() => _currentIndex = 0);
      await loadStocks(); // force refresh after pop
    }
  }

  void _openAnalyticsPage() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => AnalyticsPage(onRefresh: loadStocks))
    );
    if(result == true) { 
      setState(() => _currentIndex = 0);
    }
  }

  void _openAddUsagePage() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => AddUsagePage(onAdded: loadStocks))
    );
    if(result == true) { 
      setState(() => _currentIndex = 0);
      await loadStocks(); // force refresh after pop
    }
  }

  void _openTopUpPage([Map? preselected]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TopUpStockPage(onAdded: loadStocks, preselectedStock: preselected))
    );
    if(result == true) {
      setState(() => _currentIndex = 0);
      await loadStocks(); // force refresh after pop
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex], style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.teal,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal, Colors.cyan])),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.inventory_2, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text('Stock Manager Pro', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('${stocks.length} Items in stock', style: TextStyle(color: Colors.white70))
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(leading: Icon(Icons.dashboard), title: Text('Dashboard'), onTap: () => setState(() { _currentIndex = 0; Navigator.pop(context); })),
                  Divider(),
                  Padding(padding: EdgeInsets.only(left: 16, top: 8, bottom: 8), child: Text('YOUR STOCKS', style: TextStyle(fontSize: 12, color: Colors.grey))),
                ...stocks.map((s) => ListTile(
                    leading: CircleAvatar(child: Text(s['name'].toString()[0].toUpperCase())),
                    title: Text(s['name'].toString()),
                    subtitle: Text('${((s['currentLeft']?? s['initialQty']) as num).toStringAsFixed(1)} ${s['unit']} left'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, size: 18),
                      onPressed: () async {
                        bool? confirm = await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('Delete ${s['name']}?'),
                            content: Text('Delete this stock and all its history?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: Text('Delete')),
                            ],
                          ),
                        );
                        if(confirm == true) {
                          await DBHelper.deleteStock(s['id']);
                          await loadStocks(); // CHANGED: await
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailPage(stockId: s['id']))); // CHANGED: go to detail
                    },
                  )),
                  Divider(),
                  ListTile(leading: Icon(Icons.add_box), title: Text('Add Stock'), onTap: () { Navigator.pop(context); _openAddStockPage(); }),
                  ListTile(leading: Icon(Icons.add_circle_outline), title: Text('Top Up Stock'), onTap: () { Navigator.pop(context); _openTopUpPage(); }),
                  ListTile(leading: Icon(Icons.remove_shopping_cart), title: Text('Log Usage'), onTap: () { Navigator.pop(context); _openAddUsagePage(); }),
                  ListTile(leading: Icon(Icons.checklist), title: Text('To-Do List'), onTap: () => setState(() { _currentIndex = 2; Navigator.pop(context); })),
                  ListTile(leading: Icon(Icons.bar_chart), title: Text('Stock Stats'), onTap: () => setState(() { _currentIndex = 3; Navigator.pop(context); })),
                ],
              ),
            )
          ],
        ),
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          if(i == 1) {
            _openAddStockPage();
          } else if(i == 2) {
            setState(() => _currentIndex = i);
          } else if(i == 3) {
            _openAddUsagePage();
          } else {
            setState(() => _currentIndex = i);
          }
        },
        destinations: [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_box), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'To-Do'),
          NavigationDestination(icon: Icon(Icons.remove_shopping_cart), label: 'Usage'),
        ],
      ),
    );
  }
}