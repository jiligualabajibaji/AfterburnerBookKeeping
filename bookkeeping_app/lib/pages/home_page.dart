import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../services/settings_service.dart';
import '../services/translations.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/transaction_locator_list.dart';
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
  final Map<int, String> _selectedTypes = {}; // 已选记录 ID 对应的收支类型

  // 是否处于批量删除模式
  bool get _selectMode => _selectedIds.isNotEmpty || _selecting;
  bool _selecting = false;

  bool _openApiSettings = false;  // 从 AI 页跳转设置时自动展开 API 配置
  int? _jumpTransactionId;
  DateTime? _jumpMonth;
  GlobalKey<TransactionHighlightState>? _jumpTargetKey;
  OverlayEntry? _selectionNotice;

  void _jumpToTransaction(TransactionWithCategory record) {
    _removeSelectionNotice();
    final date = DateTime.fromMillisecondsSinceEpoch(record.transaction.timestamp * 1000);
    setState(() {
      _tab = 0;
      _selecting = false;
      _selectedIds.clear();
      _selectedTypes.clear();
      _month = DateTime(date.year, date.month);
      _jumpMonth = _month;
      _jumpTransactionId = record.transaction.id;
      // 每次使用新 key，让重复跳转同一笔也重新定位、高亮。
      _jumpTargetKey = GlobalKey<TransactionHighlightState>();
    });
    _pageCtrl.jumpToPage(date.year * 12 + date.month - 1);
  }

  @override
  void dispose() {
    _removeSelectionNotice();
    _pageCtrl.dispose();
    super.dispose();
  }

  /// 切换某条记录的选中状态（批量删除用）
  void _toggleSelect(int id, String type) {
    setState(() {
      if (_selectedIds.remove(id)) {
        _selectedTypes.remove(id);
      } else {
        _selectedIds.add(id);
        _selectedTypes[id] = type;
      }
    });
    _showSelectionNotice();
  }

  void _showSelectionNotice() {
    if (!mounted || !_selectMode || _tab != 0) return;
    _removeSelectionNotice();
    final t = AppTranslations.of(context);
    final expenseCount = _selectedIds
        .where((id) => _selectedTypes[id] == 'expense')
        .length;
    final incomeCount = _selectedIds
        .where((id) => _selectedTypes[id] == 'income')
        .length;
    _selectionNotice = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                key: const ValueKey('selection-count-notice'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(153),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  key: const ValueKey('selection-count-text'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.3,
                          decoration: TextDecoration.none,
                        ),
                        children: [
                          TextSpan(text: t.tr('home.selected_prefix')),
                          TextSpan(text: t.tr('home.selected_expense_mid', {'n': '$expenseCount'}),
                            style: const TextStyle(color: Colors.red)),
                          TextSpan(text: t.tr('home.selected_suffix')),
                        ],
                      ),
                    ),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.3,
                          decoration: TextDecoration.none,
                        ),
                        children: [
                          TextSpan(text: t.tr('home.selected_prefix')),
                          TextSpan(text: t.tr('home.selected_income_mid', {'n': '$incomeCount'}),
                            style: const TextStyle(color: Colors.green)),
                          TextSpan(text: t.tr('home.selected_suffix')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_selectionNotice!);
  }

  void _removeSelectionNotice() {
    _selectionNotice?.remove();
    _selectionNotice = null;
  }

  void _enterSelectionMode() {
    setState(() => _selecting = true);
    _showSelectionNotice();
  }

  void _exitSelectionMode() {
    _selectedIds.clear();
    _selectedTypes.clear();
    _selecting = false;
    _removeSelectionNotice();
    setState(() {});
  }

  Future<void> _openAddTransaction({required bool isExpense}) async {
    if (_selectMode) {
      _exitSelectionMode();
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionPage(
        db: widget.db,
        isExpense: isExpense,
        defaultDate: _defaultDate(),
        settings: widget.settings,
      )),
    );
    if (mounted) setState(() {});
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
        if (_jumpMonth != _month) {
          _jumpTransactionId = null;
          _jumpMonth = null;
          _jumpTargetKey = null;
        }
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

  void _returnToCurrentMonth() {
    final now = DateTime.now();
    final targetPage = now.year * 12 + now.month - 1;
    _pageCtrl.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
      if (!mounted) return;
      _selectedIds.clear();
      _selectedTypes.clear();
      _selecting = false;
      _removeSelectionNotice();
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
          SearchPage(db: widget.db, onJumpToTransaction: _jumpToTransaction), // tab 2: 搜索
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
              key: const ValueKey('income-floating-button'),
              backgroundColor: Colors.green.withOpacity(0.33),
              heroTag: 'income',
              child: const Icon(Icons.add, color: Colors.white, size: 28),
              onPressed: () => _openAddTransaction(isExpense: false),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 60, height: 60,
            child: FloatingActionButton(
              key: const ValueKey('expense-floating-button'),
              backgroundColor: Colors.red.withOpacity(0.33),
              heroTag: 'expense',
              child: const Icon(Icons.remove, color: Colors.white, size: 28),
              onPressed: () => _openAddTransaction(isExpense: true),
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
                      key: const ValueKey('monthly-selection-menu'),
                      icon: const Icon(Icons.select_all, size: 20),
                      tooltip: t.tr('home.select_all'),
                      onSelected: (v) async {
                        final txns = await widget.db.transactionsInMonth(_month);
                        if (!mounted) return;
                        setState(() {
                          if (v == 'invert') {
                            for (final t in txns) {
                              final id = t.transaction.id!;
                              if (!_selectedIds.remove(id)) {
                                _selectedIds.add(id);
                                _selectedTypes[id] = t.category.type;
                              } else {
                                _selectedTypes.remove(id);
                              }
                            }
                          } else {
                            _selectedIds.clear();
                            _selectedTypes.clear();
                            for (final t in txns) {
                              if (v == 'all' ||
                                  (v == 'expense' && t.category.type == 'expense') ||
                                  (v == 'income' && t.category.type == 'income')) {
                                _selectedIds.add(t.transaction.id!);
                                _selectedTypes[t.transaction.id!] = t.category.type;
                              }
                            }
                          }
                        });
                        _showSelectionNotice();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'all', child: Text(t.tr('home.select_month'))),
                        PopupMenuItem(value: 'expense', child: Text(t.tr('home.select_expense'))),
                        PopupMenuItem(value: 'income', child: Text(t.tr('home.select_income'))),
                        PopupMenuItem(value: 'invert', child: Text(t.tr('home.invert_month'))),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDeleteSelected),
                    TextButton(onPressed: _exitSelectionMode, child: Text(t.tr('home.cancel_select'))),
                  ]),
                // 普通模式下显示：批量删除入口 + AI 记账入口
                if (!_selectMode)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _enterSelectionMode, tooltip: t.tr('home.batch_delete')),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
          height: 32,
          child: Row(key: const ValueKey('monthly-summary-row'), children: [
            Text('${t.tr('home.expense')}: ¥${expense.abs().toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.red, fontSize: 15)),
            const SizedBox(width: 16),
            Text('${t.tr('home.income')}: ¥${income.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green, fontSize: 15)),
            const Spacer(),
            TextButton(
              key: ValueKey('return-current-month-${month.year}-${month.month}'),
              onPressed: month.year == DateTime.now().year && month.month == DateTime.now().month
                  ? null
                  : _returnToCurrentMonth,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(t.tr('home.return_current_month')),
            ),
          ]),
          ),
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
        final targetKey = _jumpMonth == DateTime(month.year, month.month) ? _jumpTargetKey : null;
        return TransactionLocatorList(
          key: ValueKey('transactions-${month.year}-${month.month}'),
          targetKey: targetKey,
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
              SizedBox(
                key: ValueKey('daily-summary-${e.key}'),
                height: 47.04,
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(child: Text('${DateFormat.MMMd(loc).format(date)} ${DateFormat.EEEE(loc).format(date)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600, fontSize: 15.68))),
                  // 批量删除模式下的日期全选复选框
                  if (_selectMode)
                    Checkbox(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: e.value.every((t) => _selectedIds.contains(t.transaction.id)),
                      tristate: false,
                      onChanged: (_) {
                        setState(() {
                          final allSelected = e.value.every((t) => _selectedIds.contains(t.transaction.id));
                          for (final t in e.value) {
                            if (allSelected) {
                              _selectedIds.remove(t.transaction.id);
                              _selectedTypes.remove(t.transaction.id);
                            } else {
                              _selectedIds.add(t.transaction.id!);
                              _selectedTypes[t.transaction.id!] = t.category.type;
                            }
                          }
                        });
                        _showSelectionNotice();
                      },
                    ),
                  const SizedBox(width: 8),
                  // 当日收支合计
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '${t.tr('home.expense')}: ¥${e.value.fold(0.0, (s, t) => s + (t.transaction.amount < 0 ? t.transaction.amount.abs() : 0)).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.red, fontSize: 13.44)),
                    const TextSpan(text: '  '),
                    TextSpan(text: '${t.tr('home.income')}: ¥${e.value.fold(0.0, (s, t) => s + (t.transaction.amount > 0 ? t.transaction.amount : 0)).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.green, fontSize: 13.44)),
                  ])),
                  const SizedBox(width: 12),
                  // 非删除模式下显示的"添加"按钮（在最右侧）
                  if (!_selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: SizedBox(
                        width: 31.36, height: 31.36,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add_circle_outline, size: 20.16),
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
              ),
              // 当日每笔交易
              ...e.value.map((t) {
                final txnId = t.transaction.id!;
                final tile = TransactionTile(
                  id: txnId,
                  amount: t.transaction.amount,
                  categoryName: t.category.name,
                  note: t.transaction.note ?? '',
                  quantity: t.transaction.quantity,
                  unit: t.transaction.unit,
                  timestamp: t.transaction.timestamp,
                  categoryType: t.category.type,
                  showTime: false,
                  compactAmount: true,
                  showFixedDecimals: widget.settings.showLedgerFixedDecimals,
                  compactLayout: true,
                  isSelected: _selectedIds.contains(txnId),
                  // 删除模式下点击选中/取消，否则进入编辑页面
                  onTap: _selecting
                      ? () => _toggleSelect(txnId, t.category.type)
                      : () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => AddTransactionPage(db: widget.db, editTxn: t)),
                        ).then((_) => setState(() {})),
                );
                if (targetKey != null && txnId == _jumpTransactionId) {
                  return TransactionHighlight(
                    key: targetKey,
                    color: t.category.type == 'expense' ? Colors.red : Colors.green,
                    child: tile,
                  );
                }
                return tile;
              }),
            ]);
          }).toList(),
        );
      },
    );
  }
}
