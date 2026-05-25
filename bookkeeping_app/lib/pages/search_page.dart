import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../services/translations.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_page.dart';

class SearchPage extends StatefulWidget {
  final AppDatabase db;
  const SearchPage({super.key, required this.db});
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchCtrl = TextEditingController();
  List<TransactionWithCategory>? _results;
  bool _searching = false;

  DateTime? _startDate;
  DateTime? _endDate;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) {
      setState(() => _results = null);
      return;
    }
    _doSearch(keyword);
  }

  Future<void> _doSearch(String keyword) async {
    if (_searching) return;
    _searching = true;
    final r = await widget.db.searchTransactions(keyword,
      startDate: _startDate,
      endDate: _endDate,
      type: _typeFilter,
    );
    if (mounted) setState(() { _results = r; _searching = false; });
  }

  void _onFilterChanged() {
    final keyword = _searchCtrl.text.trim();
    if (keyword.isNotEmpty) _doSearch(keyword);
  }

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

  List<Widget> _buildGroupedResults() {
    final sloc = Localizations.localeOf(context).toString();
    final grouped = <String, List<TransactionWithCategory>>{};
    for (final t in _results!) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t.transaction.timestamp * 1000);
      final key = DateFormat('yyyy-MM-dd').format(dt);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    return grouped.entries.map((e) {
      final date = DateTime.parse(e.key);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('${DateFormat.yMMMd(sloc).format(date)} ${DateFormat.EEEE(sloc).format(date)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        ...e.value.map((t) => TransactionTile(
          id: t.transaction.id!,
          amount: t.transaction.amount,
          categoryName: t.category.name,
          note: t.transaction.note ?? '',
          timestamp: t.transaction.timestamp,
          categoryType: t.category.type,
          onTap: () {
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(children: [
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
