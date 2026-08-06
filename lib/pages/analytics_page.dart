import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for debugPrint
import '../database/db_helper.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  List<Map> data = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  loadData() async {
    try {
      setState(() { isLoading = true; error = null; });
      data = await DBHelper.getDashboardData(); // <-- Same function, now uses SQLite
      if(mounted) setState(() { isLoading = false; });
    } catch (e, stack) {
      if(mounted) setState(() { isLoading = false; error = e.toString(); });
      debugPrint("ANALYTICS ERROR: $e");
      debugPrint(stack.toString());
    }
  }

  Color _getColor(int index) {
    List<Color> colors = [
      Colors.teal, Colors.deepPurple, Colors.orange,
      Colors.pink, Colors.indigo, Colors.green
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    if(isLoading) return Center(child: CircularProgressIndicator());
    if(error!= null) return Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Error: $error', style: TextStyle(color: Colors.red))));
    if(data.isEmpty) return Center(child: Text('Add stocks to see analytics', style: TextStyle(fontSize: 16)));

    return RefreshIndicator( // <-- ADDED: pull to refresh analytics
      color: Colors.teal,
      onRefresh: loadData,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text('Stock Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),

        ...List.generate(data.length, (index) {
            var stock = data[index];
            double initial = (stock['initialQty'] as num).toDouble();
            double left = (stock['currentLeft'] as num).toDouble();
            double used = (stock['totalUsed'] as num).toDouble();
            double percentLeft = initial > 0? (left / initial).clamp(0, 1) : 0;
            Color color = _getColor(index);

            return Card(
              elevation: 4,
              margin: EdgeInsets.only(bottom: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(stock['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                        Chip(
                          label: Text('${left.toStringAsFixed(1)} ${stock['unit']} left', style: TextStyle(color: Colors.white)),
                          backgroundColor: percentLeft < 0.2? Colors.red : color,
                        )
                      ],
                    ),
                    SizedBox(height: 16),

                    // ROW: PIE + BAR
                    Row(
                      children: [
                        // PIE CHART: Used vs Left
                        Expanded(
                          child: Column(
                            children: [
                              Text('Distribution', style: TextStyle(fontWeight: FontWeight.w600)),
                              SizedBox(height: 8),
                              SizedBox(
                                height: 150,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 4,
                                    centerSpaceRadius: 30,
                                    sections: [
                                      PieChartSectionData(
                                        value: used,
                                        title: 'Used\n${used.toStringAsFixed(1)}',
                                        color: Colors.orangeAccent,
                                        radius: 50,
                                        titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)
                                      ),
                                      PieChartSectionData(
                                        value: left,
                                        title: 'Left\n${left.toStringAsFixed(1)}',
                                        color: color,
                                        radius: 50,
                                        titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        // BAR CHART: Initial vs Used
                        Expanded(
                          child: Column(
                            children: [
                              Text('Initial vs Used', style: TextStyle(fontWeight: FontWeight.w600)),
                              SizedBox(height: 8),
                              SizedBox(
                                height: 150,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: initial * 1.2,
                                    barGroups: [
                                      BarChartGroupData(
                                        x: 0,
                                        barRods: [BarChartRodData(toY: initial, color: color.withOpacity(0.4), width: 20, borderRadius: BorderRadius.circular(4))]
                                      ),
                                      BarChartGroupData(
                                        x: 1,
                                        barRods: [BarChartRodData(toY: used, color: Colors.orangeAccent, width: 20, borderRadius: BorderRadius.circular(4))]
                                      ),
                                    ],
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v,i) {
                                        return Text(v == 0? 'Initial' : 'Used', style: TextStyle(fontSize: 10));
                                      })),
                                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(show: false),
                                    borderData: FlBorderData(show: false),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // PROGRESS BAR
                    Text('Stock Level: ${(percentLeft * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12)),
                    SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: percentLeft,
                        minHeight: 10,
                        backgroundColor: Colors.grey[300],
                        color: percentLeft < 0.2? Colors.red : color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
        ],
      ),
    );
  }
}
