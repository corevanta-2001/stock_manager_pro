import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class AddUsagePage extends StatefulWidget {
  final VoidCallback? onAdded; // NEW: add callback to refresh home
  AddUsagePage({this.onAdded}); // CHANGED

  @override
  State<AddUsagePage> createState() => _AddUsagePageState();
}

class _AddUsagePageState extends State<AddUsagePage> {
  List<Map> stocks = [];
  Map? selected;
  final usedCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  DateTime date = DateTime.now();

  @override
  void initState() {
    super.initState();
    loadStocks();
  }

  loadStocks() async {
    stocks = await DBHelper.getStocks();
    setState(() {});
  }

  saveUsage() async {
  try { // <-- ADD TRY CATCH
    if(selected == null || usedCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select stock and enter quantity'), backgroundColor: Colors.red)
      );
      return;
    }
    
    double? used = double.tryParse(usedCtrl.text.trim().replaceAll(',', '.'));
    if(used == null || used <= 0) return;

    if(used > (selected!['currentLeft'] as num)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot use more than stock left!'), backgroundColor: Colors.red)
      );
      return;
    }

     await DBHelper.addUsage(
      selected!['id'], 
      used,
      DateFormat('yyyy-MM-dd').format(date),
      notesCtrl.text
    );
    
     widget.onAdded?.call(); // <-- 1. ADD AWAIT
    
    usedCtrl.clear(); 
    notesCtrl.clear();
    await loadStocks(); // <-- 2. AWAIT so dropdown updates
    
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usage logged for ${selected!['name']}'), 
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        )
      );
      
      await Future.delayed(Duration(milliseconds: 150)); // <-- 3. Let home refresh
      if(mounted) Navigator.pop(context, true); // <-- 4. Now pop
    }
  } catch (e, stack) {
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red, duration: Duration(seconds: 4))
      );
    }
    debugPrint("ADD USAGE ERROR: $e");
    debugPrint(stack.toString());
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Log Usage'), centerTitle: true, backgroundColor: Colors.orange),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [
            Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.remove_shopping_cart, size: 50, color: Colors.white)),
            SizedBox(height: 25),
            DropdownButtonFormField(
              hint: Text('Select Stock'),
              value: selected,
              items: stocks.map((e) => DropdownMenuItem(value: e, child: Text('${e['name']} - ${(e['currentLeft'] as num).toStringAsFixed(1)} ${e['unit']} left'))).toList(),
              onChanged: (v) => setState(() => selected = v),
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(Icons.inventory, color: Colors.orange)),
            ),
            if(selected != null) ...[
              SizedBox(height: 10),
              Text('Available: ${(selected!['currentLeft'] as num).toStringAsFixed(1)} ${selected!['unit']}', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
            SizedBox(height: 15),
            TextField(controller: usedCtrl, decoration: InputDecoration(labelText: 'Quantity Used', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(Icons.remove, color: Colors.orange)), keyboardType: TextInputType.numberWithOptions(decimal: true)),
            SizedBox(height: 15),
            TextField(controller: notesCtrl, decoration: InputDecoration(labelText: 'Notes - Optional', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(Icons.note, color: Colors.orange)), maxLines: 2),
            Card(margin: EdgeInsets.symmetric(vertical: 15), child: ListTile(leading: Icon(Icons.calendar_today, color: Colors.orange), title: Text('Date'), subtitle: Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(fontWeight: FontWeight.bold)), trailing: IconButton(icon: Icon(Icons.edit), onPressed: () async {final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if(d!=null) setState(() => date = d);}))),
            SizedBox(height: 20),
            FilledButton.icon(onPressed: saveUsage, icon: Icon(Icons.save), label: Text('Log Usage', style: TextStyle(fontSize: 16)), style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), backgroundColor: Colors.orange))
          ]),
        ),
      ),
    );
  }
}
