import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../database/models.dart';

class AddTransactionPage extends StatefulWidget {
  final AppDatabase db;
  final bool isExpense;
  final TransactionWithCategory? editTxn;
  final DateTime? defaultDate;
  const AddTransactionPage({super.key, required this.db, this.isExpense = true, this.editTxn, this.defaultDate});
  @override State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _amountFocus = FocusNode();
  final _noteFocus = FocusNode();
  bool _isExpense = true;
  int? _categoryId;
  DateTime _selectedDate = DateTime.now();
  bool _showTime = false;
  List<Category> _allCats = [];
  DateTime _lastSnackTime = DateTime(2000);

  @override
  void initState() {
    super.initState();
    final edit = widget.editTxn;
    if (edit != null) {
      _isExpense = edit.category.type == 'expense';
      _categoryId = edit.category.id;
      _amountCtrl.text = edit.transaction.amount.abs().toString();
      _noteCtrl.text = edit.transaction.note ?? '';
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(edit.transaction.timestamp * 1000);
    } else {
      _isExpense = widget.isExpense;
      _selectedDate = widget.defaultDate ?? DateTime.now();
    }
    widget.db.allCategories().then((cats) {
      setState(() {
        _allCats = cats;
        if (_categoryId == null && cats.isNotEmpty) {
          final first = cats.firstWhere(
            (c) => c.type == (_isExpense ? 'expense' : 'income'),
            orElse: () => cats.first,
          );
          _categoryId = first.id;
        }
      });
    });
  }

  @override
  void dispose() { _amountCtrl.dispose(); _noteCtrl.dispose(); _amountFocus.dispose(); _noteFocus.dispose(); super.dispose(); }

  List<Category> get _filteredCats =>
      _allCats.where((c) => c.type == (_isExpense ? 'expense' : 'income')).toList();

  Color get _themeColor => _isExpense ? Colors.red : Colors.green;

  OverlayEntry? _toast;

  void _showTopSnack(String msg, {bool isError = true}) {
    if (DateTime.now().difference(_lastSnackTime).inSeconds < 2) return;
    _lastSnackTime = DateTime.now();
    _toast?.remove();
    final overlay = Overlay.of(context);
    _toast = OverlayEntry(builder: (ctx) {
      return Positioned(
        top: MediaQuery.of(ctx).padding.top + 10,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: isError ? Colors.deepOrange : Colors.green.shade600,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              child: Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ),
        ),
      );
    });
    overlay.insert(_toast!);
    Future.delayed(const Duration(seconds: 2), () { _toast?.remove(); _toast = null; });
  }

  /// Evaluate simple arithmetic like "100+50-20", returns null if invalid.
  double? _calcExpression(String input) {
    final trimmed = input.trim();
    // Try direct number first
    final direct = double.tryParse(trimmed);
    if (direct != null) return direct;
    // Try Chinese number (汉字数字, 如 一百三十六、一块二毛七)
    final chinese = _parseChineseNumber(trimmed);
    if (chinese != null) return chinese;
    // Try expression with +/- separated
    try {
      final parts = trimmed.split(RegExp(r'(?=[+-])'));
      double total = 0;
      for (final part in parts) {
        if (part.isEmpty) continue;
        final num = double.tryParse(part);
        if (num == null) return null;
        total += num;
      }
      return total;
    } catch (_) {
      return null;
    }
  }

  bool _hasChineseNum(String s) =>
    s.contains(RegExp(r'[一两三四五六七八九十百千万亿零两块元毛角分]'));

  double? _parseChineseNumber(String s) {
    if (!_hasChineseNum(s)) return null;
    if (s.contains(RegExp(r'[块元毛角分]'))) return _parseChineseCurrency(s);
    return _parseChineseInteger(s);
  }

  double? _parseChineseInteger(String s) {
    final digits = <String, int>{
      '一': 1, '二': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '两': 2,
    };
    double result = 0, temp = 0;
    double lastMult = 1;
    bool hadZero = false;
    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '零') { temp = 0; hadZero = true; }
      else if (digits.containsKey(c)) { temp = digits[c]!.toDouble(); }
      else if (c == '十') { if (temp == 0) temp = 1; temp *= 10; result += temp; temp = 0; lastMult = 10; hadZero = false; }
      else if (c == '百') { if (temp == 0) temp = 1; temp *= 100; result += temp; temp = 0; lastMult = 100; hadZero = false; }
      else if (c == '千') { if (temp == 0) temp = 1; temp *= 1000; result += temp; temp = 0; lastMult = 1000; hadZero = false; }
      else if (c == '万') { if (temp == 0) temp = 1; result = (result + temp) * 10000; temp = 0; lastMult = 10000; hadZero = false; }
      else if (c == '亿') { if (temp == 0) temp = 1; result = (result + temp) * 100000000; temp = 0; lastMult = 100000000; hadZero = false; }
    }
    // 口语修正："一百八" = 180 (8×10), "一千五" = 1500 (5×100)
    if (temp > 0 && !hadZero && lastMult >= 100) {
      temp *= lastMult / 10;
    }
    return result + temp;
  }

  double? _parseChineseCurrency(String s) {
    final digits = <String, int>{
      '零': 0, '一': 1, '二': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '两': 2,
    };
    double result = 0;
    s = s.replaceAll('元', '块').replaceAll('角', '毛');
    final parts = s.split('块');
    if (parts[0].isNotEmpty && parts.length > 1) {
      final yuan = _parseChineseInteger(parts[0]);
      if (yuan == null) return null;
      result += yuan;
    }
    String rest = parts.length > 1 ? parts.last : s;
    if (rest.isEmpty) return result;
    // Handle 毛 and 分 in remainder
    final maoIdx = rest.indexOf('毛');
    final fenIdx = rest.indexOf('分');
    if (maoIdx >= 0) {
      if (maoIdx > 0) {
        final mao = digits[rest[maoIdx - 1]];
        if (mao == null) return null;
        result += mao * 0.1;
      }
      if (maoIdx + 1 < rest.length) {
        String fenStr = rest.substring(maoIdx + 1).replaceAll('分', '');
        if (fenStr.isNotEmpty) {
          final fen = digits[fenStr[0]];
          if (fen == null) return null;
          result += fen * 0.01;
        }
      }
    } else if (fenIdx >= 0 && fenIdx > 0) {
      final fen = digits[rest[fenIdx - 1]];
      if (fen == null) return null;
      result += fen * 0.01;
    } else if (parts.length > 1 && rest.isNotEmpty) {
      // X块Y (no 毛/分) → Y is 毛
      final mao = digits[rest[0]];
      if (mao == null) return null;
      result += mao * 0.1;
    }
    return result;
  }

  Future<void> _save({bool stay = false}) async {
    if (_amountCtrl.text.isEmpty) {
      _showTopSnack('请填写金额');
      return;
    }
    final amountVal = _calcExpression(_amountCtrl.text);
    if (amountVal == null) {
      _showTopSnack('金额必须为数字或算式（如 100+50）');
      return;
    }
    if (amountVal < 0) {
      _showTopSnack('金额不能小于0');
      return;
    }
    if (_categoryId == null) {
      _showTopSnack('请选择分类');
      return;
    }
    final amount = double.parse(amountVal.toStringAsFixed(2));
    final ts = _showTime
        ? _selectedDate.millisecondsSinceEpoch ~/ 1000
        : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
            .millisecondsSinceEpoch ~/ 1000;
    final edit = widget.editTxn;
    if (edit != null) {
      await widget.db.updateTransaction(edit.transaction.id!, amount: _isExpense ? -amount : amount,
          categoryId: _categoryId!, note: _noteCtrl.text, timestamp: ts);
    } else {
      await widget.db.addTransaction(
        amount: _isExpense ? -amount : amount,
        categoryId: _categoryId!,
        note: _noteCtrl.text,
        timestamp: ts,
      );
    }
    if (stay) {
      _amountCtrl.clear();
      _noteCtrl.clear();
      _selectedDate = DateTime.now();
      _showTime = false;
      // Keep the same category and expense/income selection
      setState(() {});
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _themeColor;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: color,
          primaryContainer: color.withAlpha(30),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('记一笔'),
          actions: [
            FilledButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('再记一笔'),
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: () => _save(stay: true),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 支出/收入切换 + 金额
            Row(children: [
              ChoiceChip(label: const Text('支出'), selected: _isExpense,
                selectedColor: Colors.red.withAlpha(40),
                onSelected: (_) => setState(() {
                  _isExpense = true; _categoryId = _filteredCats.firstOrNull?.id;
                })),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('收入'), selected: !_isExpense,
                selectedColor: Colors.green.withAlpha(40),
                onSelected: (_) => setState(() {
                  _isExpense = false; _categoryId = _filteredCats.firstOrNull?.id;
                })),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  focusNode: _amountFocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    _amountFocus.unfocus();
                    Future.delayed(const Duration(milliseconds: 100), () => _noteFocus.requestFocus());
                  },
                  decoration: InputDecoration(
                    labelText: '金额', prefixText: '¥ ',
                    filled: true, fillColor: color.withAlpha(15),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: color),
                    ),
                  ),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text('支持算式和中文数字，如 100+50、一百三十六', style: TextStyle(color: color.withAlpha(150), fontSize: 12)),
            ),
            const SizedBox(height: 16),

            Text('选择分类', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _allCats.isEmpty
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : Wrap(spacing: 8, runSpacing: 8,
                  children: [
                    ..._filteredCats.map((c) => _buildCatChip(c, color)),
                    _buildAddCatChip(color),
                  ]),
            const SizedBox(height: 20),

            Text('日期', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    filled: true, fillColor: color.withAlpha(15),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color)),
                    suffixIcon: IconButton(
                      icon: Icon(_showTime ? Icons.access_time : Icons.date_range, size: 20),
                      onPressed: () => setState(() => _showTime = !_showTime),
                    ),
                  ),
                  controller: TextEditingController(
                    text: _showTime
                      ? DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate)
                      : DateFormat('yyyy-MM-dd').format(_selectedDate),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (date == null) return;
                    TimeOfDay? time;
                    if (_showTime) {
                      time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_selectedDate),
                      );
                    }
                    setState(() => _selectedDate = DateTime(
                      date.year, date.month, date.day,
                      time?.hour ?? 0, time?.minute ?? 0,
                    ));
                  },
                ),
              ),
            ]),
            const SizedBox(height: 20),

            Text('备注', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              focusNode: _noteFocus,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: '可选', filled: true, fillColor: color.withAlpha(15),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color)),
              ),
            ),
            const SizedBox(height: 32),

            // 底部按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: const Text('保存并返回'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color, side: BorderSide(color: color),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _save(stay: false),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ]),
        ),
      ),
    );
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('添加${_isExpense ? '支出' : '收入'}分类'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '分类名称', hintText: '输入新分类名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('添加')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final id = await widget.db.addCategory(name, type: _isExpense ? 'expense' : 'income');
      await widget.db.allCategories().then((cats) => setState(() { _allCats = cats; _categoryId = id; }));
    }
  }

  Widget _buildAddCatChip(Color color) {
    return GestureDetector(
      onTap: _addCategory,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(100), width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, size: 16, color: color),
          const SizedBox(width: 4),
          Text('新增', style: TextStyle(color: color, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _buildCatChip(Category c, Color color) {
    final selected = _categoryId == c.id;
    return GestureDetector(
      onTap: () => setState(() => _categoryId = c.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : Colors.grey.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.withAlpha(80),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(c.name, style: TextStyle(
          fontSize: 15,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? color : null,
        )),
      ),
    );
  }
}
