import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../services/settings_service.dart';
import '../services/translations.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_page.dart';
import 'ai_input_page.dart';
import 'statistics_page.dart';
import 'search_page.dart';
import 'settings_page.dart';

/// 主页 — 应用的根页面。
/// 底部导航栏包含：流水 / 统计 / 搜索 / 设置。
/// 同时也是所有子页面的容器，持有 db 和 settings 两个核心依赖。
class HomePage extends StatefulWidget {
  final AppDatabase db;
  final SettingsService settings;
  final VoidCallback onThemeChanged;
  final String appName;
  const HomePage({super.key, required this.db, required this.settings, required this.onThemeChanged, this.appName = ''});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;              // 当前选中的底部导航 tab 索引
  DateTime _month = DateTime.now();  // 当前显示的月份（流水页）
  final Set<int> _selectedIds = {};  // 批量删除模式下选中的交易记录 ID 集合

  // 是否处于批量删除模式
  bool get _selectMode => _selectedIds.isNotEmpty || _selecting;
  bool _selecting = false;

  bool _openApiSettings = false;  // 从 AI 页跳转设置时自动展开 API 配置

  /// 切换某条记录的选中状态（批量删除用）
  void _toggleSelect(int id) {
    setState(() { if (_selectedIds.contains(id)) _selectedIds.remove(id); else _selectedIds.add(id); });
  }

  // PageView 控制器，按 (year*12 + month - 1) 索引月份页面
  late final PageController _pageCtrl = PageController(
    initialPage: DateTime.now().year * 12 + DateTime.now().month - 1,
  );

  /// 构建左右滑动的月份页面容器
  Widget _buildSwipeableTransactions() {
    return PageView.builder(
      controller: _pageCtrl,
      onPageChanged: (page) {
        // 页面切换后更新 _month 状态
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

  /// 计算默认日期：当前月用今天，其他月份用当月 1 号
  DateTime _defaultDate() {
    final now = DateTime.now();
    if (_month.year == now.year && _month.month == now.month) return now;
    return DateTime(_month.year, _month.month, 1);
  }

  /// 批量删除确认弹窗
  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final t2 = AppTranslations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t2.tr('home.confirm_delete_title', {'n': '${_selectedIds.length}'})),
        content: SizedBox(
          width: double.maxFinite,
          child: Text(t2.tr('home.confirm_delete_body', {'n': '${_selectedIds.length}'})),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t2.tr('home.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t2.tr('home.confirm_delete'))),
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
    final t = AppTranslations.of(context);
    final bgPath = widget.settings.backgroundImagePath;
    return Scaffold(
      // body 用 Container 包裹以支持背景图
      body: Container(
        decoration: bgPath != null ? BoxDecoration(
          image: DecorationImage(image: FileImage(File(bgPath)), fit: BoxFit.cover, opacity: 0.3),
        ) : null,
        // IndexedStack 保持各 tab 页面状态不丢失
        child: IndexedStack(
        index: _tab,
        children: [
          _buildSwipeableTransactions(),    // tab 0: 流水
          StatisticsPage(db: widget.db),    // tab 1: 统计
          SearchPage(db: widget.db),        // tab 2: 搜索
          SettingsPage(                     // tab 3: 设置
            key: ValueKey('settings$_openApiSettings'),
            db: widget.db, settings: widget.settings,
            onThemeChanged: widget.onThemeChanged,
            apiExpanded: _openApiSettings,
          ),
        ],
      ),
      ),
      // 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() { _tab = i; if (i != 3) _openApiSettings = false; }),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.receipt_long), label: t.tr('tab.transactions')),
          BottomNavigationBarItem(icon: const Icon(Icons.pie_chart), label: t.tr('tab.stats')),
          BottomNavigationBarItem(icon: const Icon(Icons.search), label: t.tr('tab.search')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings), label: t.tr('tab.settings')),
        ],
      ),
      // 只在水流页显示浮动按钮（收入 + 和支出 -）
      floatingActionButton: _tab == 0 ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60, height: 60,
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
            width: 60, height: 60,
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

  /// 构建单个月份的流水视图（年月切换 + 月度汇总 + 交易列表）
  Widget _buildTransactionsForMonth(DateTime month) {
    final t = AppTranslations.of(context);
    final loc = Localizations.localeOf(context).toString();
    return SafeArea(
      child: Column(
        children: [
          // 顶部操作栏：左右箭头 + 年月点击选择 + 全选/删除/AI按钮
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 左箭头 ← 上一个月
                IconButton(icon: const Icon(Icons.chevron_left),
                  onPressed: () => _pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
                // 点击年月弹出年份/月份选择器
                GestureDetector(
                  onTap: () async {
                    // 第一步：选择年份
                    final pickedYear = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(t.tr('common.select_year')),
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
                    // 第二步：选择月份
                    final pickedMonth = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(t.tr('common.year_title', {'year': '$pickedYear'})),
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
                                child: Text(DateFormat.MMM(loc).format(DateTime(2024, m, 1))),
                              );
                            }),
                          ),
                        ),
                      ),
                    );
                    if (pickedMonth != null) {
                      // 跳转到目标月份页面
                      final targetPage = pickedYear * 12 + pickedMonth - 1;
                      _pageCtrl.jumpToPage(targetPage);
                    }
                  },
                  child: Text(DateFormat.yMMMM(loc).format(month),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                // 右箭头 → 下一个月
                IconButton(icon: const Icon(Icons.chevron_right),
                  onPressed: () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)),
                const Spacer(),
                // 批量删除模式下显示：全选菜单 + 删除按钮 + 取消
                if (_selectMode)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.select_all, size: 20),
                      tooltip: t.tr('home.select_all'),
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
                        PopupMenuItem(value: 'all', child: Text(t.tr('home.select_month'))),
                        PopupMenuItem(value: 'expense', child: Text(t.tr('home.select_expense'))),
                        PopupMenuItem(value: 'income', child: Text(t.tr('home.select_income'))),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDeleteSelected),
                    TextButton(onPressed: () { _selectedIds.clear(); _selecting = false; setState(() {}); }, child: Text(t.tr('home.cancel_select'))),
                  ]),
                // 普通模式下显示：批量删除入口 + AI 记账入口
                if (!_selectMode)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _selecting = true), tooltip: t.tr('home.batch_delete')),
                    IconButton(icon: const Icon(Icons.record_voice_over),
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AiInputPage(
                          db: widget.db,
                          onRequestSettings: () { _tab = 3; _openApiSettings = true; },
                        )))
                          .then((_) => setState(() {})),
                    ),
                  ]),
              ],
            ),
          ),
          // 底部小提示
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(t.tr('home.hint'),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ),
          // 月度收支汇总
          _buildSummary(month),
          const Divider(height: 1),
          // 交易列表
          Expanded(child: _buildList(month)),
        ],
      ),
    );
  }

  /// 月度收支汇总条：显示支出总计和收入总计
  Widget _buildSummary(DateTime month) {
    final t = AppTranslations.of(context);
    final loc = Localizations.localeOf(context).toString();
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
            Text('${t.tr('home.expense')}: ¥${expense.abs().toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.red, fontSize: 15)),
            const SizedBox(width: 16),
            Text('${t.tr('home.income')}: ¥${income.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green, fontSize: 15)),
          ]),
        );
      },
    );
  }

  /// 某个月的交易列表，按日期分组展示
  Widget _buildList(DateTime month) {
    final t = AppTranslations.of(context);
    final loc = Localizations.localeOf(context).toString();
    return FutureBuilder<List<TransactionWithCategory>>(
      future: widget.db.transactionsInMonth(month),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final txns = snap.data!;
        if (txns.isEmpty) return Center(child: Text(t.tr('home.no_records')));
        // 按日期分组
        final grouped = <String, List<TransactionWithCategory>>{};
        for (final t in txns) {
          final dt = DateTime.fromMillisecondsSinceEpoch(t.transaction.timestamp * 1000);
          final key = DateFormat('yyyy-MM-dd').format(dt);
          grouped.putIfAbsent(key, () => []).add(t);
        }
        return ListView(
          children: grouped.entries.toList().asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final date = DateTime.parse(e.key);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 日期分隔线（第一天不显示）
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 4, thickness: 0.5),
                ),
              // 日期分组标题
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(children: [
                  Text('${DateFormat.MMMd(loc).format(date)} ${DateFormat.EEEE(loc).format(date)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
                  // 批量删除模式下的日期全选复选框
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
                  // 当日收支合计
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${t.tr('home.expense')}: ¥${e.value.fold(0.0, (s, t) => s + (t.transaction.amount < 0 ? t.transaction.amount.abs() : 0)).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                    const TextSpan(text: '  '),
                    TextSpan(text: '${t.tr('home.income')}: ¥${e.value.fold(0.0, (s, t) => s + (t.transaction.amount > 0 ? t.transaction.amount : 0)).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.green, fontSize: 12)),
                  ])),
                  const SizedBox(width: 12),
                  // 非删除模式下显示的"添加"按钮（在最右侧）
                  if (!_selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: SizedBox(
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
                    ),
                ]),
              ),
              // 当日每笔交易
              ...e.value.map((t) {
                final txnId = t.transaction.id!;
                return TransactionTile(
                  id: txnId,
                  amount: t.transaction.amount,
                  categoryName: t.category.name,
                  note: t.transaction.note ?? '',
                  timestamp: t.transaction.timestamp,
                  categoryType: t.category.type,
                  showTime: false,
                  isSelected: _selectedIds.contains(txnId),
                  // 删除模式下点击选中/取消，否则进入编辑页面
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
