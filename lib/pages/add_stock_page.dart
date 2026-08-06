import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for debugPrint
import '../database/db_helper.dart';

class AddStockPage extends StatefulWidget {
  final VoidCallback onAdded; 
  AddStockPage({required this.onAdded});

  @override
  State<AddStockPage> createState() => _AddStockPageState();
}

class _AddStockPageState extends State<AddStockPage> {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  String unit = 'kg';
  final _formKey = GlobalKey<FormState>();

  addStock() async {

  try {
    if(!_formKey.currentState!.validate()) return;
    double qty = double.parse(qtyCtrl.text.replaceAll(',', '.'));
    
    await DBHelper.addStock(nameCtrl.text, qty, unit);
    widget.onAdded(); // <-- REMOVE AWAIT HERE. Just call it

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text('${nameCtrl.text} Added!')]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
        )
      );
      
      nameCtrl.clear();
      qtyCtrl.clear();
      setState(() => unit = 'kg');
      FocusScope.of(context).unfocus();

      await Future.delayed(Duration(milliseconds: 300)); // <-- INCREASED to 300ms for web
      if(mounted) Navigator.pop(context, true);

    catch (e, stack) {
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red, duration: Duration(seconds: 4))
      );
    }
    debugPrint("ADD STOCK ERROR: $e");
    debugPrint(stack.toString());
  }
}


  @override
  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add New Stock'), centerTitle: true, backgroundColor: Colors.teal),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(children: [
              Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal, Colors.teal.shade300]),  borderRadius: BorderRadius.circular(20)), child: Icon(Icons.inventory_2, size: 50, color: Colors.white)),
              SizedBox(height: 25),
              TextFormField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Stock Name', hintText: 'e.g. RICE, WHEAT', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(Icons.label, color: Colors.teal)), validator: (v) => v!.isEmpty? 'Enter stock name' : null),
              SizedBox(height: 15),
              Row(children: [
                Expanded(child: TextFormField(controller: qtyCtrl, decoration: InputDecoration(labelText: 'Initial Quantity', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: Icon(Icons.numbers, color: Colors.teal)), keyboardType: TextInputType.numberWithOptions(decimal: true), validator: (v) => v!.isEmpty || double.tryParse(v.replaceAll(',', '.')) == null ? 'Enter valid number' : null)),
                SizedBox(width: 10),
                Container(padding: EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton(value: unit, items: ['Kg','Ltrs','Pcs','Bags','USD', 'Others'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => unit = v!))))
              ]),
              SizedBox(height: 30),
              FilledButton.icon(onPressed: addStock, icon: Icon(Icons.add_circle), label: Text('Add Stock', style: TextStyle(fontSize: 16)), style: FilledButton.styleFrom(minimumSize: Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), backgroundColor: Colors.teal))
            ]),
          ),
        ),
      ),
    );
  }
}
