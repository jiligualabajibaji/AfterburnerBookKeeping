import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../services/translations.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_page.dart';

/// 搜索页面 — 按关键词搜索交易记录，支持日期范围和收支类型筛选。
/// 位于底部导航栏的第三个 tab（流水→统计→搜索→设置）。
class SearchPage extends StatefulWidget {
  final AppDatabase db;
  const SearchPage({super.key, required this.db});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchCtrl = TextEditingController();
  List<TransactionWithCategory>? _results;  // 搜索结果，null 表示尚未搜索
  bool _searching = false;

  // ── 筛选条件 ──
  DateTime? _startDate;   // 筛选：开始日期
  DateTime? _endDate;     // 筛选：结束日期
  String? _typeFilter;    // 筛选：null=全部, 'expense'=支出, 'income'=收入
  Set<String> _searchFields = {'category', 'note', 'amount'}; // 搜索字段

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);  // 输入框内容变化时自动搜索
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 搜索框内容变化时触发搜索（实时）
  void _onSearchChanged() {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) {
      setState(() => _results = null);  // 清空输入时清除结果
      return;
    }
    _doSearch(keyword);
  }

  /// 执行搜索，将筛选条件和关键词一起传给数据库
  Future<void> _doSearch(String keyword) async {
    if (_searching) return;
    _searching = true;
    final r = await widget.db.searchTransactions(keyword,
      searchFields: _searchFields.isEmpty ? null : _searchFields,
      startDate: _startDate,
      endDate: _endDate,
      type: _typeFilter,
    );
    if (mounted) setState(() { _results = r; _searching = false; });
  }

  /// 筛选条件变化时重新搜索
  void _onFilterChanged() {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isNotEmpty) _doSearch(keyword);
  }

  /// 选择日期（开始/结束）
  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) _startDate = picked; else _endDate = picked;
    });
    _onFilterChanged();
  }

  /// 将搜索结果按日期分组，生成带日期标题的列表
  List<Widget> _buildGroupedResults() {
    final sloc = Localizations.localeOf(context).toString();
    // 按日期分组
    final grouped = <String, List<TransactionWithCategory>>{};
    for (final t in _results!) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t.transaction.timestamp * 1000);
      final key = DateFormat('yyyy-MM-dd').format(dt);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    return grouped.entries.map((e) {
      final date = DateTime.parse(e.key);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 日期分组标题
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('${DateFormat.yMMMd(sloc).format(date)} ${DateFormat.EEEE(sloc).format(date)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        // 该日期的交易列表
        ...e.value.map((t) => TransactionTile(
          id: t.transaction.id!,
          amount: t.transaction.amount,
          categoryName: t.category.name,
          note: t.transaction.note ?? '',
          timestamp: t.transaction.timestamp,
          categoryType: t.category.type,
          onTap: () {
            // 点击跳转到编辑页面，编辑后重新搜索
            Navigator.push(context,
              MaterialPageRoute(builder: (_) => AddTransactionPage(db: widget.db, editTxn: t)),
            ).then((_) => _onSearchChanged());
          },
        )),
      ]);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return SafeArea(
      child: Column(children: [
        // ── 搜索输入框 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: t.tr('search.hint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () { _searchCtrl.clear(); setState(() => _results = null); },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        // ── 搜索字段筛选：类别/备注/金额 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(children: [
            _searchFieldChip(label: t.tr('search.field_category'), value: 'category'),
            const SizedBox(width: 6),
            _searchFieldChip(label: t.tr('search.field_note'), value: 'note'),
            const SizedBox(width: 6),
            _searchFieldChip(label: t.tr('search.field_amount'), value: 'amount'),
          ]),
        ),
        // ── 筛选栏：日期范围 + 收支类型 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(children: [
            // 开始日期按钮
            Expanded(
              child: _filterChip(
                label: _startDate == null ? t.tr('search.start_date') : DateFormat('yyyy-MM-dd').format(_startDate!),
                icon: Icons.date_range,
                onTap: () => _pickDate(isStart: true),
                onClear: _startDate == null ? null : () {
                  setState(() => _startDate = null);
                  _onFilterChanged();
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('—'),
            ),
            // 结束日期按钮
            Expanded(
              child: _filterChip(
                label: _endDate == null ? t.tr('search.end_date') : DateFormat('yyyy-MM-dd').format(_endDate!),
                icon: Icons.date_range,
                onTap: () => _pickDate(isStart: false),
                onClear: _endDate == null ? null : () {
                  setState(() => _endDate = null);
                  _onFilterChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            // 类型筛选：全部/支出/收入
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _typeChip(label: t.tr('search.all'), value: null),
                _typeChip(label: t.tr('search.expense'), value: 'expense'),
                _typeChip(label: t.tr('search.income'), value: 'income'),
              ]),
            ),
          ]),
        ),
        // ── 搜索结果 ──
        Expanded(
          child: _results == null
              ? Center(
                  child: Text(t.tr('search.placeholder'),
                    style: TextStyle(color: Colors.grey.shade500)),
                )
              : _results!.isEmpty
                  ? Center(child: Text(t.tr('search.no_results')))
                  : ListView(
                      children: _buildGroupedResults(),
                    ),
        ),
      ]),
    );
  }

  /// 构建日期筛选按钮
  Widget _filterChip({required String label, required IconData icon, required VoidCallback onTap, VoidCallback? onClear}) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 14),
              const SizedBox(width: 2),
              Expanded(
                child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 14),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  /// 构建搜索字段筛选按钮（类别/备注/金额，颜色跟随收支类型）
  Widget _searchFieldChip({required String label, required String value}) {
    final selected = _searchFields.contains(value);
    final chipColor = _typeFilter == null ? Colors.amber : (_typeFilter == 'expense' ? Colors.red : Colors.green);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selected) {
            if (_searchFields.length > 1) _searchFields.remove(value);
          } else {
            _searchFields.add(value);
          }
        });
        _onFilterChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? chipColor.withAlpha(40) : Colors.grey.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? chipColor : Colors.grey.withAlpha(80),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          color: selected ? chipColor : null,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        )),
      ),
    );
  }

  /// 构建类型筛选按钮（全部=黄色、支出=红色、收入=绿色）
  Widget _typeChip({required String label, required String? value}) {
    final selected = _typeFilter == value;
    Color? bgColor;
    Color? fgColor;
    if (selected) {
      if (value == null) {
        bgColor = Colors.amber;
        fgColor = Colors.black;
      } else if (value == 'expense') {
        bgColor = Colors.red;
        fgColor = Colors.white;
      } else {
        bgColor = Colors.green;
        fgColor = Colors.white;
      }
    }
    return GestureDetector(
      onTap: () {
        setState(() => _typeFilter = value);
        _onFilterChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12,
            color: fgColor,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
