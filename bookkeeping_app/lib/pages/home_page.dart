import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../services/settings_service.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_page.dart';
import 'ai_input_page.dart';
import 'statistics_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final AppDatabase db;
  final SettingsService settings;
  final VoidCallback onThemeChanged;
  final String appName;
  const HomePage({super.key, required this.db, required this.settings, required this.onThemeChanged, this.appName = ''});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  DateTime _month = DateTime.now();
  final Set<int> _selectedIds = {};

  bool get _selectMode => _selectedIds.isNotEmpty || _selecting;
  bool _selecting = false;
  bool _openApiSettings = false;

  void _toggleSelect(int id) {
    setState(() { if (_selectedIds.contains(id)) _selectedIds.remove(id); else _selectedIds.add(id); });
  }

  late final PageController _pageCtrl = PageController(
    initialPage: DateTime.now().year * 12 + DateTime.now().month - 1,
  );

  Widget _buildSwipeableTransactions() {
    return PageView.builder(
      controller: _pageCtrl,
      onPageChanged: (page) {
        final y = page ~/ 12;
        final m = (page % 12) + 1;
        _month = DateTime(y, m, 1);
        setState(() {});
      },
      itemBuilder: (_, page) {
        final y = page ~/ 12;
        final m = (page % 12) + 1;
        final month = DateTime(y, m, 1);
        return _buildTransactionsForMonth(month);
      },
    );
  }

  DateTime _defaultDate() {
    final now = DateTime.now();
    if (_month.year == now.year && _month.month == now.month) return now;
    return DateTime(_month.year, _month.month, 1);
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('确认删除 ${_selectedIds.length} 条记录'),
        content: SizedBox(
          width: double.maxFinite,
          child: Text('确定要删除选中的 ${_selectedIds.length} 条记录吗？\n此操作不可撤销。'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认删除')),
        ],
      ),
    );
    if (ok == true) {
      for (final id in _selectedIds) await widget.db.deleteTransaction(id);
      _selectedIds.clear();
      _selecting = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgPath = widget.settings.backgroundImagePath;
    return Scaffold(
      body: Container(
        decoration: bgPath != null ? BoxDecoration(
          image: DecorationImage(image: FileImage(File(bgPath)), fit: BoxFit.cover, opacity: 0.3),
        ) : null,
        child: IndexedStack(
        index: _tab,
        children: [
          _buildSwipeableTransactions(),
          StatisticsPage(db: widget.db),
          SettingsPage(key: ValueKey('settings$_openApiSettings'), db: widget.db, settings: widget.settings, onThemeChanged: widget.onThemeChanged, apiExpanded: _openApiSettings),
        ],
      ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() { _tab = i; if (i != 2) _openApiSettings = false; }),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: '流水'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
      floatingActionButton: _tab == 0 ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: FloatingActionButton(
              backgroundColor: Colors.green.withOpacity(0.33),
              heroTag: 'income',
              child: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddTransactionPage(db: widget.db, isExpense: false, defaultDate: _defaultDate())),
              ).then((_) => setState(() {})),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 60,
            height: 60,
            child: FloatingActionButton(
              backgroundColor: Colors.red.withOpacity(0.33),
              heroTag: 'expense',
              child: const Icon(Icons.remove, color: Colors.white, size: 28),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddTransactionPage(db: widget.db, isExpense: true, defaultDate: _defaultDate())),
              ).then((_) => setState(() {})),
            ),
          ),
        ],
      ) : null,
    );
  }

  Widget _buildTransactionsForMonth(DateTime month) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left),
                  onPressed: () => _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
                GestureDetector(
                  onTap: () async {
                    // Year picker
                    final pickedYear = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('选择年份'),
                        content: SizedBox(
                          width: 280, height: 300,
                          child: YearPicker(
                            firstDate: DateTime(2000), lastDate: DateTime(2100),
                            selectedDate: month,
                            onChanged: (d) => Navigator.pop(ctx, d.year),
                          ),
                        ),
                      ),
                    );
                    if (pickedYear == null) return;
                    // Month picker
                    final pickedMonth = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('${pickedYear}年'),
                        content: SizedBox(
                          width: 280,
                          child: GridView.count(
                            crossAxisCount: 3, shrinkWrap: true,
                            mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2,
                            children: List.generate(12, (i) {
                              final m = i + 1;
                              return ElevatedButton(
                                style: ElevatedButton.styleFrom(elevation: 0,
                                  backgroundColor: m == month.month && pickedYear == month.year
                                    ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                                  foregroundColor: m == month.month && pickedYear == month.year
                                    ? Colors.white : Colors.black87,
                                ),
                                onPressed: () => Navigator.pop(ctx, m),
                                child: Text('${m}月'),
                              );
                            }),
                          ),
                        ),
                      ),
                    );
                    if (pickedMonth != null) {
                      final targetPage = pickedYear * 12 + pickedMonth - 1;
                      _pageCtrl.jumpToPage(targetPage);
                    }
                  },
                  child: Text(DateFormat('yyyy年M月', 'zh_CN').format(month),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(icon: const Icon(Icons.chevron_right),
                  onPressed: () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
                const Spacer(),
                if (_selectMode)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.select_all, size: 20),
                      tooltip: '全选',
                      onSelected: (v) async {
                        final txns = await widget.db.transactionsInMonth(_month);
                        setState(() {
                          _selectedIds.clear();
                          for (final t in txns) {
                            if (v == 'all' ||
                                (v == 'expense' && t.category.type == 'expense') ||
                                (v == 'income' && t.category.type == 'income')) {
                              _selectedIds.add(t.transaction.id!);
                            }
                          }
                        });
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'all', child: Text('全选本月')),
                        const PopupMenuItem(value: 'expense', child: Text('全选本月支出')),
                        const PopupMenuItem(value: 'income', child: Text('全选本月收入')),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDeleteSelected),
                    TextButton(onPressed: () { _selectedIds.clear(); _selecting = false; setState(() {}); }, child: const Text('取消')),
                  ]),
                if (!_selectMode)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _selecting = true), tooltip: '批量删除'),
                    IconButton(icon: const Icon(Icons.record_voice_over),
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AiInputPage(
                          db: widget.db,
                          onRequestSettings: () { _tab = 2; _openApiSettings = true; },
                        )))
                          .then((_) => setState(() {})),
                    ),
                  ]),
              ],
            ),
          ),
          _buildSummary(month),
          const Divider(height: 1),
          Expanded(child: _buildList(month)),
        ],
      ),
    );
  }

  Widget _buildSummary(DateTime month) {
    return FutureBuilder<Map<String, double>>(
      future: widget.db.monthlySummary(month),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!;
        double expense = 0, income = 0;
        for (final v in data.values) {
          if (v < 0) expense += v; else income += v;
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text('支出: ¥${expense.abs().toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.red, fontSize: 15)),
            const SizedBox(width: 16),
            Text('收入: ¥${income.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green, fontSize: 15)),
          ]),
        );
      },
    );
  }

  Widget _buildList(DateTime month) {
    return FutureBuilder<List<TransactionWithCategory>>(
      future: widget.db.transactionsInMonth(month),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final txns = snap.data!;
        if (txns.isEmpty) return const Center(child: Text('暂无记录'));
        // Group by date
        final grouped = <String, List<TransactionWithCategory>>{};
        for (final t in txns) {
          final dt = DateTime.fromMillisecondsSinceEpoch(t.transaction.timestamp * 1000);
          final key = DateFormat('yyyy-MM-dd').format(dt);
          grouped.putIfAbsent(key, () => []).add(t);
        }
        return ListView(
          children: grouped.entries.map((e) {
            final date = DateTime.parse(e.key);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Text(DateFormat('M月d日 EEEE', 'zh_CN').format(date),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                  if (_selectMode)
                    Checkbox(
                      value: e.value.every((t) => _selectedIds.contains(t.transaction.id)),
                      tristate: false,
                      onChanged: (_) {
                        setState(() {
                          final allSelected = e.value.every((t) => _selectedIds.contains(t.transaction.id));
                          for (final t in e.value) {
                            if (allSelected) {
                              _selectedIds.remove(t.transaction.id);
                            } else {
                              _selectedIds.add(t.transaction.id!);
                            }
                          }
                        });
                      },
                    ),
                  const Spacer(),
                  if (!_selectMode)
                    SizedBox(
                      width: 28, height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => AddTransactionPage(
                            db: widget.db, defaultDate: date,
                          )),
                        ).then((_) => setState(() {})),
                      ),
                    ),
                ]),
              ),
              ...e.value.map((t) {
                final txnId = t.transaction.id!;
                return TransactionTile(
                  id: txnId,
                  amount: t.transaction.amount,
                  categoryName: t.category.name,
                  note: t.transaction.note ?? '',
                  timestamp: t.transaction.timestamp,
                  categoryType: t.category.type,
                  isSelected: _selectedIds.contains(txnId),
                  onTap: _selecting
                      ? () => _toggleSelect(txnId)
                      : () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => AddTransactionPage(db: widget.db, editTxn: t)),
                        ).then((_) => setState(() {})),
                );
              }),
            ]);
          }).toList(),
        );
      },
    );
  }
}
