import 'package:flutter/material.dart';
import '../database/database.dart';
import '../database/models.dart';

class CategoryEditor extends StatefulWidget {
  final AppDatabase db;
  const CategoryEditor({super.key, required this.db});
  @override State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  final _nameCtrl = TextEditingController();

  Future<void> _add({String defaultType = 'expense'}) async {
    _nameCtrl.clear();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        String name = '';
        return AlertDialog(
          title: Text('添加${defaultType == 'expense' ? '支出' : '收入'}分类'),
          content: TextField(
            decoration: const InputDecoration(labelText: '分类名称', hintText: '输入新分类名称'),
            onChanged: (v) => name = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, {'name': name, 'type': defaultType}), child: const Text('添加')),
          ],
        );
      },
    );
    if (result != null && result['name']!.isNotEmpty) {
      await widget.db.addCategory(result['name']!, type: result['type']!);
      setState(() {});
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('该分类下的账单将自动归入"其他"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await widget.db.deleteCategory(id);
      setState(() {});
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Widget _buildCategoryList(List<Category> cats, String title, {required String addType}) {
    if (cats.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Align(alignment: Alignment.centerLeft,
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
      ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cats.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            final item = cats.removeAt(oldIndex);
            cats.insert(newIndex, item);
          });
          for (int i = 0; i < cats.length; i++) {
            widget.db.updateCategoryOrder(cats[i].id!, i);
          }
        },
        itemBuilder: (_, i) {
          final c = cats[i];
          return ListTile(
            key: ValueKey(c.id),
            leading: Icon(Icons.drag_handle, color: Colors.grey.shade400),
            title: Text(c.name),
            subtitle: Text(c.type == 'expense' ? '支出' : '收入'),
            trailing: (c.name == '其他支出' || c.name == '其他收入')
              ? const Icon(Icons.lock_outline, color: Colors.grey, size: 20)
              : IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _delete(c.id!),
              ),
          );
        },
      ),
      ListTile(
        leading: const Icon(Icons.add_circle_outline, color: Colors.teal),
        title: Text('添加${title.replaceAll('分类', '')}分类'),
        onTap: () => _add(defaultType: addType),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: widget.db.allCategories(),
      builder: (_, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        final cats = snap.data!;
        final expenseCats = cats.where((c) => c.type == 'expense').toList();
        final incomeCats = cats.where((c) => c.type == 'income').toList();
        return Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('长按拖动调整顺序', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          _buildCategoryList(expenseCats, '支出分类', addType: 'expense'),
          _buildCategoryList(incomeCats, '收入分类', addType: 'income'),
        ]);
      },
    );
  }
}
