import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({Key? key}) : super(key: key);

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  List<Map> todos = [];
  final _taskCtrl = TextEditingController();
  static const _todoKey = 'todo_list';

  @override
  void initState() {
    super.initState();
    loadTodos();
  }

  loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_todoKey);
    if(data!= null) {
      try {
        List decoded = jsonDecode(data);
        todos = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch(e) { todos = []; }
    }
    setState(() {});
  }

  saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_todoKey, jsonEncode(todos));
  }

  addTodo() {
    if(_taskCtrl.text.trim().isEmpty) return;
    setState(() {
      todos.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch,
        'task': _taskCtrl.text.trim(),
        'done': false,
        'date': DateTime.now().toIso8601String()
      });
      _taskCtrl.clear();
    });
    saveTodos();
  }

  toggleTodo(int id) {
    setState(() {
      final index = todos.indexWhere((t) => t['id'] == id);
      todos[index]['done'] =!todos[index]['done'];
      // move done items to bottom
      todos.sort((a,b) => (a['done']? 1 : 0).compareTo(b['done']? 1 : 0));
    });
    saveTodos();
  }

  deleteTodo(int id) {
    setState(() {
      todos.removeWhere((t) => t['id'] == id);
    });
    saveTodos();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Task deleted'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
    );
  }

  @override
  Widget build(BuildContext context) {
    int doneCount = todos.where((t) => t['done'] == true).length;
    double progress = todos.isEmpty? 0 : doneCount / todos.length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text('To-Do List', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.indigo, Colors.purple], begin: Alignment.topLeft, end: Alignment.bottomRight)
                ),
                child: Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(height: 20),
                    Text('${doneCount}/${todos.length} Completed', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white24, color: Colors.white),
                      ),
                    )
                  ]),
                )
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _taskCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add a new task...',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16)
                    ),
                    onSubmitted: (_) => addTodo(),
                  ),
                ),
                SizedBox(width: 10),
                FilledButton(
                  onPressed: addTodo,
                  style: FilledButton.styleFrom(
                    shape: CircleBorder(),
                    padding: EdgeInsets.all(16),
                    backgroundColor: Colors.indigo
                  ),
                  child: Icon(Icons.add, size: 26),
                )
              ]),
            ),
          ),
          todos.isEmpty
         ? SliverFillRemaining(
              child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.checklist, size: 80, color: Colors.grey.shade300),
                SizedBox(height: 16),
                Text('No tasks yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Add your first task above', style: TextStyle(color: Colors.grey))
              ])),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final todo = todos[index];
                  return Dismissible(
                    key: Key(todo['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => deleteTodo(todo['id']),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: Offset(0, 2))]
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: GestureDetector(
                          onTap: () => toggleTodo(todo['id']),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: todo['done']? Colors.indigo : Colors.transparent,
                              border: Border.all(color: todo['done']? Colors.indigo : Colors.grey, width: 2)
                            ),
                            child: todo['done']? Icon(Icons.check, size: 18, color: Colors.white) : null,
                          ),
                        ),
                        title: Text(
                          todo['task'],
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            decoration: todo['done']? TextDecoration.lineThrough : null,
                            color: todo['done']? Colors.grey : null,
                            fontWeight: FontWeight.w500
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                          onPressed: () => deleteTodo(todo['id']),
                        ),
                      ),
                    ),
                  );
                },
                childCount: todos.length,
              ),
            ),
        ],
      ),
    );
  }
}