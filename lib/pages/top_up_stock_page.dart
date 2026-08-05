import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class TopUpStockPage extends StatefulWidget {
  final VoidCallback? onAdded;
  final Map? preselectedStock; // for quick topup from home
  TopUpStockPage({this.onAdded, this.preselectedStock});

  @override
  State<TopUpStockPage> createState() => _TopUpStockPageState();
}

class _TopUpStockPageState extends State<TopUpStockPage> {
  List<Map> stocks = [];
  Map? selected;
  final qtyCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    loadStocks();
    if(widget.preselectedStock!= null) selected = widget.preselectedStock;
  }

  loadStocks() async {
    stocks = await DBHelper.getStocks();
    setState(() {});
  }

  topUp() async {
    if(!_formKey.currentState!.validate() || selected == null) return;
    double qty = double.parse(qtyCtrl.text.replaceAll(',', '.'));

    await DBHelper.topUpStock(selected!['id'], qty);
    widget.onAdded?.call();

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text('${selected!['name']} topped up!')]), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
      );
      Navigator.pop(context, true); // return to home
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Top Up Stock'), centerTitle: true, backgroundColor: Colors.green),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(children: [
              Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green, Colors.lightGreen]), borderRadius: BorderRadius.circular(20)), child: Icon(Icons.add_circle, size: 50, color: Colors.white)),
              SizedBox(height: 25),
              DropdownButtonFormField(
                hint: Text('Select Stock to Top Up'),
                value: selected,
                items: stocks.map((e) => DropdownMenuItem(value: e, child: Text('${e['name']} - ${(e['currentLeft'] as num).toStringAsFixed(1)} ${e['unit']}'))).toList(),
                onChanged: (v) => setState(() => selected = v),
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(Icons.inventory, color: Colors.green)),
                validator: (v) => v == null? 'Select a stock' : null,
              ),
              SizedBox(height: 15),
              TextFormField(
                controller: qtyCtrl,
                decoration: InputDecoration(labelText: 'Quantity to Add', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(Icons.add, color: Colors.green)),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v!.isEmpty || double.tryParse(v.replaceAll(',', '.')) == null? 'Enter valid number' : null,
              ),
              SizedBox(height: 30),
              FilledButton.icon(onPressed: topUp, icon: Icon(Icons.add_circle), label: Text('Top Up', style: TextStyle(fontSize: 16)), style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), backgroundColor: Colors.green))
            ]),
          ),
        ),
      ),
    );
  }
}