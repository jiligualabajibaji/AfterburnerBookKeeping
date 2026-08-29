import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../database/models.dart';
import '../services/settings_service.dart';
import '../services/translations.dart';

/// 记一笔页面 — 手动录入/编辑交易记录。
/// 支持：金额算式解析、中文数字解析、再记一笔连续录入、微信输入法兼容。
class AddTransactionPage extends StatefulWidget {
  final AppDatabase db;
  final bool isExpense;                    // 新建时默认为支出还是收入
  final TransactionWithCategory? editTxn;  // 不为 null 表示编辑已有记录
  final DateTime? defaultDate;             // 默认日期
  const AddTransactionPage({super.key, required this.db, this.isExpense = true, this.editTxn, this.defaultDate});
  @override State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  // ── 表单控制器与焦点 ──
  final _amountCtrl = TextEditingController();  // 金额输入
  final _noteCtrl = TextEditingController();     // 备注输入
  final _quantityCtrl = TextEditingController(); // 数量输入
  final _unitCtrl = TextEditingController();     // 单位输入
  final _amountFocus = FocusNode();              // 金额框焦点
  final _noteFocus = FocusNode();                // 备注框焦点
  final _settings = SettingsService();           // 读取数量/单位设置
  double _stepInterval = 1.0;                    // 数量增减步长

  // ── 表单状态 ──
  bool _isExpense = true;        // true=支出 false=收入
  int? _categoryId;              // 当前选中的分类 ID
  DateTime _selectedDate = DateTime.now();  // 选中的日期
  bool _showTime = false;        // 日期选择是否包含时分
  List<Category> _allCats = [];  // 全部分类列表

  // ── 用户手动输入（用于无默认值分类间切换时恢复） ──
  String _manualAmount = '';
  String _manualNote = '';
  bool _settingDefault = false;  // 正在自动填入默认值，忽略监听

  // ── 微信输入法兼容状态 ──
  bool _amountFocusedBeforeTap = false;  // 本次触摸前金额框是否聚焦
  bool _noteFocusedBeforeTap = false;    // 本次触摸前备注框是否聚焦
  bool _keyboardResetting = false;       // 防止键盘重置重入

  // ── Toast 防重复 ──
  OverlayEntry? _toast;
  DateTime _lastSnackTime = DateTime(2000);

  @override
  void initState() {
    super.initState();
    // 监听金额/备注输入，记录用户手动输入的内容
    _amountCtrl.addListener(() {
      if (!_settingDefault) _manualAmount = _amountCtrl.text;
    });
    _noteCtrl.addListener(() {
      if (!_settingDefault) _manualNote = _noteCtrl.text;
    });
    // 异步初始化设置后再读取步长/单位/数量默认值
    _settings.init().then((_) {
      if (!mounted) return;
      setState(() {
        _stepInterval = _settings.stepInterval;
        if (_unitCtrl.text.isEmpty) _unitCtrl.text = _settings.defaultUnit;
        final defQty = _settings.defaultQuantity;
        if (defQty != null && _quantityCtrl.text.isEmpty) _quantityCtrl.text = _trimNum(defQty);
      });
    });
    final edit = widget.editTxn;
    if (edit != null) {
      // 编辑模式：从传入的交易数据填充表单
      _isExpense = edit.category.type == 'expense';
      _categoryId = edit.category.id;
      _amountCtrl.text = edit.transaction.amount.abs().toString();
      _noteCtrl.text = edit.transaction.note ?? '';
      _quantityCtrl.text = edit.transaction.quantity != null && edit.transaction.quantity! > 0
          ? _trimNum(edit.transaction.quantity!) : '';
      _unitCtrl.text = edit.transaction.unit ?? '';
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(edit.transaction.timestamp * 1000);
    } else {
      // 新增模式：使用默认值
      _isExpense = widget.isExpense;
      _selectedDate = widget.defaultDate ?? DateTime.now();
    }
    // 异步加载全部分类，自动选中第一个匹配当前支出/收入类型的分类
    widget.db.allCategories().then((cats) {
      setState(() {
        _allCats = cats;
        if (_categoryId == null && cats.isNotEmpty) {
          final first = cats.firstWhere(
            (c) => c.type == (_isExpense ? 'expense' : 'income'),
            orElse: () => cats.first,
          );
          _categoryId = first.id;
          // 自动填入默认金额
          if (first.defaultAmount != null && _amountCtrl.text.isEmpty) {
            _settingDefault = true;
            _amountCtrl.text = first.defaultAmount.toString();
            _settingDefault = false;
          }
        }
      });
    });
  }

  /// 去掉小数末尾多余的 0（1.0 → "1"，1.50 → "1.5"）
  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }

  /// 步进按钮（减号/加号）
  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 44, height: 48,
        child: Icon(icon, size: 20, color: _themeColor),
      ),
    );
  }

  /// 单个单位行（用于设置对话框中的自定义拖拽列表）
  Widget _buildUnitRow(String unit, {required VoidCallback onDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.drag_handle, size: 18, color: Colors.grey),
        title: Text(unit, style: const TextStyle(fontSize: 14)),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 16, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }

  /// 数量加减
  void _changeQuantity(double delta) {
    final text = _quantityCtrl.text.trim();
    final cur = text.isEmpty ? 0.0 : (double.tryParse(text) ?? 0.0);
    final next = cur + delta;
    if (next < 0) return;  // 不允许负数
    _quantityCtrl.text = _trimNum(double.parse(next.toStringAsFixed(2)));
  }

  /// 长按提示文字 → 打开数量/单位设置
  Future<void> _openQuantitySettings() async {
    final s = AppTranslations.of(context);
    final stepCtrl = TextEditingController(text: _trimNum(_stepInterval));
    final qtyCtrl = TextEditingController(text: _settings.defaultQuantity != null ? _trimNum(_settings.defaultQuantity!) : '');
    final newUnitCtrl = TextEditingController();
    final unitList = List<String>.from(_settings.units);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDiaState) => AlertDialog(
          scrollable: true,
          title: Text(s.tr('add.quantity_settings')),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: stepCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.tr('add.step_interval'), isDense: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: s.tr('add.default_quantity'), isDense: true),
                ),
                const SizedBox(height: 16),
                // 单位列表管理（固定高度内部滚动，长按整行拖动排序 + 删除 + 新增）
                Text(s.tr('add.units'), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                if (unitList.isNotEmpty)
                  Column(children: [
                    for (int i = 0; i < unitList.length; i++)
                      DragTarget<int>(
                        key: ValueKey('drag_$i'),
                        onWillAccept: (data) => data != null && data != i,
                        onAccept: (from) {
                          setDiaState(() {
                            final item = unitList.removeAt(from);
                            unitList.insert(i, item);
                          });
                        },
                        builder: (context, candidates, rejected) =>
                            LongPressDraggable<int>(
                          data: i,
                          axis: Axis.vertical,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Opacity(opacity: 0.9, child: _buildUnitRow(unitList[i], onDelete: () => setDiaState(() { unitList.remove(unitList[i]); if (unitList.isEmpty) unitList.add('个'); }))),
                          ),
                          childWhenDragging: Opacity(opacity: 0.3, child: _buildUnitRow(unitList[i], onDelete: () => setDiaState(() { unitList.remove(unitList[i]); if (unitList.isEmpty) unitList.add('个'); }))),
                          child: _buildUnitRow(unitList[i], onDelete: () => setDiaState(() { unitList.remove(unitList[i]); if (unitList.isEmpty) unitList.add('个'); })),
                        ),
                      ),
                  ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: newUnitCtrl,
                      decoration: InputDecoration(labelText: s.tr('add.new_unit'), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () {
                      final v = newUnitCtrl.text.trim();
                      if (v.isNotEmpty && !unitList.contains(v)) {
                        setDiaState(() => unitList.add(v));
                        newUnitCtrl.clear();
                      }
                    },
                    child: Text(s.tr('add.confirm_add')),
                  ),
            ]),
          ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.tr('home.cancel'))),
            FilledButton(onPressed: () {
              final step = double.tryParse(stepCtrl.text.trim());
              if (step != null && step > 0) {
                _settings.stepInterval = step;
                _stepInterval = step;
              }
              _settings.units = unitList;
              _settings.defaultUnit = unitList.first;
              final qty = double.tryParse(qtyCtrl.text.trim());
              _settings.defaultQuantity = (qty == null || qty <= 0) ? null : qty;
              // 同步当前表单
              _unitCtrl.text = _settings.defaultUnit;
              final defQty = _settings.defaultQuantity;
              if (defQty != null && _quantityCtrl.text.isEmpty) _quantityCtrl.text = _trimNum(defQty);
              setState(() {});
              Navigator.pop(ctx);
            }, child: Text(s.tr('add.rename_confirm'))),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _quantityCtrl.dispose();
    _unitCtrl.dispose();
    _amountFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  /// 过滤出当前类型（支出/收入）下的分类
  List<Category> get _filteredCats =>
      _allCats.where((c) => c.type == (_isExpense ? 'expense' : 'income')).toList();

  /// 查找当前选中的分类对象
  Category? _findSelectedCategory() =>
      _allCats.where((c) => c.id == _categoryId).firstOrNull;

  /// 根据收支类型返回主题色：支出=红色，收入=绿色
  Color get _themeColor => _isExpense ? Colors.red : Colors.green;

  /// 可选的单位列表（来自设置）
  List<String> get _unitOptions => _settings.units;

  /// 在屏幕顶部显示 Toast 提示，2 秒内重复的消息不会弹出两次
  void _showTopSnack(String msg, {bool isError = true}) {
    if (DateTime.now().difference(_lastSnackTime).inSeconds < 2) return;
    _lastSnackTime = DateTime.now();
    _toast?.remove();
    final overlay = Overlay.of(context);
    _toast = OverlayEntry(builder: (ctx) {
      return Positioned(
        top: MediaQuery.of(ctx).padding.top + 10,
        left: 0, right: 0,
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

  // ═══════════════════════════════════════
  //  金额解析引擎
  // ═══════════════════════════════════════

  /// 解析金额输入，支持三种格式：
  /// 1. 直接数字 "100" → 100
  /// 2. 中文数字 "一百三十六" → 136, "一块二毛七" → 1.27
  /// 3. 算式 "100+50-20" → 130
  /// 无法解析时返回 null
  double? _calcExpression(String input) {
    final trimmed = input.trim();
    // 尝试直接数字
    final direct = double.tryParse(trimmed);
    if (direct != null) return direct;
    // 尝试中文数字
    final chinese = _parseChineseNumber(trimmed);
    if (chinese != null) return chinese;
    // 尝试加减算式
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

  /// 判断字符串是否包含中文数字字符
  bool _hasChineseNum(String s) =>
    s.contains(RegExp(r'[一两三四五六七八九十百千万亿零两块元毛角分]'));

  /// 中文数字解析入口，区分整数和货币格式
  double? _parseChineseNumber(String s) {
    if (!_hasChineseNum(s)) return null;
    if (s.contains(RegExp(r'[块元毛角分]'))) return _parseChineseCurrency(s);
    return _parseChineseInteger(s);
  }

  /// 解析中文整数，如 "一百三十六" → 136
  /// 含口语修正："一百八" → 180（不是 108）
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
    // 口语修正："一百八" = 180 (8×10而不是8)，"一千五" = 1500
    if (temp > 0 && !hadZero && lastMult >= 100) {
      temp *= lastMult / 10;
    }
    return result + temp;
  }

  /// 解析中文货币，如 "一块二毛七" → 1.27
  /// 统一将"元"替换为"块"、"角"替换为"毛"后处理
  double? _parseChineseCurrency(String s) {
    final digits = <String, int>{
      '零': 0, '一': 1, '二': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9, '两': 2,
    };
    double result = 0;
    s = s.replaceAll('元', '块').replaceAll('角', '毛');
    final parts = s.split('块');
    // 解析"块"前面的整数部分
    if (parts[0].isNotEmpty && parts.length > 1) {
      final yuan = _parseChineseInteger(parts[0]);
      if (yuan == null) return null;
      result += yuan;
    }
    String rest = parts.length > 1 ? parts.last : s;
    if (rest.isEmpty) return result;
    // 解析"毛"和"分"
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
      // "X块Y"（没有毛/分）→ Y 视为毛
      final mao = digits[rest[0]];
      if (mao == null) return null;
      result += mao * 0.1;
    }
    return result;
  }

  // ═══════════════════════════════════════
  //  保存逻辑
  // ═══════════════════════════════════════

  /// 保存交易记录。
  /// [stay] = true: 保存后不返回，清空表单继续录入（"再记一笔"）。
  Future<void> _save({bool stay = false}) async {
    final s = AppTranslations.of(context);
    // 校验
    if (_amountCtrl.text.isEmpty) {
      _showTopSnack(s.tr('add.error_amount_empty'));
      return;
    }
    final amountVal = _calcExpression(_amountCtrl.text);
    if (amountVal == null) {
      _showTopSnack(s.tr('add.error_amount_invalid'));
      return;
    }
    if (amountVal < 0) {
      _showTopSnack(s.tr('add.error_amount_negative'));
      return;
    }
    if (_categoryId == null) {
      _showTopSnack(s.tr('add.error_no_category'));
      return;
    }
    // 数量/单位（数量为空或 <=0 则存 null）
    final qtyText = _quantityCtrl.text.trim();
    final qty = double.tryParse(qtyText);
    final quantity = (qty == null || qty <= 0) ? null : double.parse(qty.toStringAsFixed(2));
    final unit = quantity != null ? (_unitCtrl.text.trim().isEmpty ? '个' : _unitCtrl.text.trim()) : null;
    // 计算金额和时间戳
    final amount = double.parse(amountVal.toStringAsFixed(2));
    final ts = _showTime
        ? _selectedDate.millisecondsSinceEpoch ~/ 1000
        : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
            .millisecondsSinceEpoch ~/ 1000;
    // 写入数据库（新增或更新）
    final edit = widget.editTxn;
    if (edit != null) {
      await widget.db.updateTransaction(edit.transaction.id!, amount: _isExpense ? -amount : amount,
          categoryId: _categoryId!, note: _noteCtrl.text, quantity: quantity, unit: unit, timestamp: ts);
    } else {
      await widget.db.addTransaction(
        amount: _isExpense ? -amount : amount,
        categoryId: _categoryId!,
        note: _noteCtrl.text,
        quantity: quantity,
        unit: unit,
        timestamp: ts,
      );
    }
    if (stay) {
      // 再记一笔：清空表单，保留分类和日期，聚焦金额框
      _amountCtrl.clear();
      _noteCtrl.clear();
      _quantityCtrl.clear();
      final defQty = _settings.defaultQuantity;
      if (defQty != null) _quantityCtrl.text = _trimNum(defQty);
      _unitCtrl.text = _settings.defaultUnit;
      _showTime = false;
      _amountFocus.unfocus();
      _noteFocus.unfocus();
      setState(() {});
      Future.delayed(const Duration(milliseconds: 50), () => _amountFocus.requestFocus());
    } else if (mounted) {
      Navigator.pop(context);  // 返回上一页
    }
  }

  // ═══════════════════════════════════════
  //  UI 构建
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    final color = _themeColor;
    // 用 Theme 包裹使子组件颜色跟随当前收支类型
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: color,
          primaryContainer: color.withAlpha(30),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.tr('add.title')),
          actions: [
            // 右上角"再记一笔"按钮
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(t.tr('add.add_another')),
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: () => _save(stay: true),
              ),
            ),
          ],
        ),
        body: Listener(
          // 触摸前记录焦点状态，用于微信输入法键盘类型切换
          onPointerDown: (_) {
            _amountFocusedBeforeTap = _amountFocus.hasFocus;
            _noteFocusedBeforeTap = _noteFocus.hasFocus;
          },
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── 第一行：支出/收入切换 + 金额输入 ──
            Row(children: [
              ChoiceChip(label: Text(t.tr('add.expense')), selected: _isExpense,
                selectedColor: Colors.red.withAlpha(40),
                onSelected: (_) => setState(() {
                  _isExpense = true; _categoryId = _filteredCats.firstOrNull?.id;
                })),
              const SizedBox(width: 8),
              ChoiceChip(label: Text(t.tr('add.income')), selected: !_isExpense,
                selectedColor: Colors.green.withAlpha(40),
                onSelected: (_) => setState(() {
                  _isExpense = false; _categoryId = _filteredCats.firstOrNull?.id;
                })),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  focusNode: _amountFocus,
                  keyboardType: TextInputType.number,    // 数字键盘
                  textInputAction: TextInputAction.next,  // 键盘 Next 按钮
                  onSubmitted: (_) {
                    // 按 Next → 切换焦点到备注框（先 unfocus 再 focus 以兼容微信输入法）
                    _amountFocus.unfocus();
                    Future.delayed(const Duration(milliseconds: 50), () => _noteFocus.requestFocus());
                  },
                  onTap: () {
                    // 从备注切回金额时强制键盘刷新（微信输入法兼容）
                    if (_noteFocusedBeforeTap && !_keyboardResetting) {
                      _keyboardResetting = true;
                      _amountFocus.unfocus();
                      Future.delayed(const Duration(milliseconds: 50), () {
                        if (mounted) _amountFocus.requestFocus();
                        _keyboardResetting = false;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: t.tr('add.amount'), prefixText: '¥ ',
                    filled: true, fillColor: color.withAlpha(15),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: color),
                    ),
                  ),
                ),
              ),
            ]),
            // 金额输入提示
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(t.tr('add.amount_hint'), style: TextStyle(color: color.withAlpha(150), fontSize: 12)),
            ),
            const SizedBox(height: 16),

            // ── 日期选择 ──
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (detail) {
                    final diff = detail.primaryVelocity ?? 0;
                    setState(() {
                      _selectedDate = _selectedDate.add(Duration(days: diff < 0 ? 1 : -1));
                    });
                  },
                  child: TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      filled: true, fillColor: color.withAlpha(15),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color)),
                      suffix: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(t.tr('add.date_hint_swipe'), style: TextStyle(fontSize: 10, color: color.withAlpha(100))),
                      ),
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
            ),
          ]),
          const SizedBox(height: 16),

          // ── 数量 + 单位 ──
          Row(children: [
            // 数量步进器：[-] 输入框 [+]（固定较短宽度）
            Container(
              width: 168,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withAlpha(60)),
              ),
              child: Row(children: [
                _stepBtn(Icons.remove, () => _changeQuantity(-_stepInterval)),
                Expanded(
                  child: TextField(
                    controller: _quantityCtrl,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                _stepBtn(Icons.add, () => _changeQuantity(_stepInterval)),
              ]),
            ),
            const SizedBox(width: 8),
            // 单位下拉选择（不可手动输入）
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: color.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _unitCtrl.text.isNotEmpty && _unitOptions.contains(_unitCtrl.text)
                        ? _unitCtrl.text : _unitOptions.first,
                    isExpanded: true,
                    icon: Icon(Icons.arrow_drop_down, size: 20, color: color),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    items: _unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _unitCtrl.text = v); },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 提示文字：长按进入设置
            Expanded(
              child: GestureDetector(
                onLongPress: _openQuantitySettings,
                child: Text(
                  t.tr('add.unit_hint_longpress'),
                  style: TextStyle(color: color.withAlpha(120), fontSize: 11),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // ── 备注输入 ──
            TextField(
              controller: _noteCtrl,
              focusNode: _noteFocus,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              onTap: () {
                if (_amountFocusedBeforeTap && !_keyboardResetting) {
                  _keyboardResetting = true;
                  _noteFocus.unfocus();
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted) _noteFocus.requestFocus();
                    _keyboardResetting = false;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: t.tr('add.note_hint'), filled: true, fillColor: color.withAlpha(15),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: color)),
              ),
            ),
            const SizedBox(height: 20),

            // ── 分类选择 ──
            Row(children: [
              Text(t.tr('add.select_category'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(color: color.withAlpha(150), fontSize: 11),
                  children: [
                    TextSpan(text: '${t.tr('add.category_hint_longpress')}  '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: SizedBox(width: 10, height: 10, child: Icon(Icons.lock, size: 9, color: color.withAlpha(150))),
                    ),
                    TextSpan(text: t.tr('add.category_hint_protected')),
                  ],
                ),
              )),
            ]),
            const SizedBox(height: 8),
            _allCats.isEmpty
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : Wrap(spacing: 8, runSpacing: 8,
                  children: [
                    ..._filteredCats.map((c) => _buildCatChip(c, color)),
                    _buildAddCatChip(color),
                  ]),
            const SizedBox(height: 32),

            // ── 底部保存按钮 ──
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: Text(t.tr('add.save_return')),
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
      ),
    );
  }

  // ═══════════════════════════════════════
  //  分类相关
  // ═══════════════════════════════════════

  /// 弹窗让用户输入新分类名称，然后写入数据库并刷新
  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final s = AppTranslations.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('add.add_category_title', {'type': s.tr(_isExpense ? 'category.type_expense' : 'category.type_income')})),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: s.tr('add.category_name'), hintText: s.tr('add.category_hint'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.tr('home.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(s.tr('add.confirm_add'))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      // 查重：同一类型下不允许同名
      if (_allCats.any((c) => c.name == name && c.type == (_isExpense ? 'expense' : 'income'))) {
        _showTopSnack(s.tr('add.error_category_duplicate'));
        return;
      }
      final id = await widget.db.addCategory(name, type: _isExpense ? 'expense' : 'income');
      await widget.db.allCategories().then((cats) => setState(() { _allCats = cats; _categoryId = id; }));
    }
  }

  /// 构建"+新增"分类按钮
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
          Text(AppTranslations.of(context).tr('add.new_category'), style: TextStyle(color: color, fontSize: 14)),
        ]),
      ),
    );
  }

  /// 构建单个分类选择按钮
  Widget _buildCatChip(Category c, Color color) {
    final selected = _categoryId == c.id;
    // 是否为不可删除的默认分类（兜底分类）
    final isProtected = c.name == '其他支出' || c.name == '其他收入';
    final lockColor = c.type == 'expense' ? Colors.red : Colors.green;
    return GestureDetector(
      onTap: () {
        setState(() { _categoryId = c.id; });
        // 金额
        if (c.defaultAmount != null) {
          _settingDefault = true;
          _amountCtrl.text = c.defaultAmount.toString();
          _settingDefault = false;
        } else {
          _amountCtrl.text = _manualAmount;
        }
        // 备注
        _settingDefault = true;
        _noteCtrl.text = c.defaultNote ?? _manualNote;
        _settingDefault = false;
      },
      onLongPress: isProtected
          ? null
          : () => _showCategoryOptions(c),
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isProtected)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.lock, size: 12, color: lockColor),
            ),
          Text(AppTranslations.of(context).trCategory(c.name), style: TextStyle(
            fontSize: 15,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? color : null,
          )),
        ]),
      ),
    );
  }

  /// 长按分类弹出操作菜单：默认金额 / 重命名 / 删除
  Future<void> _showCategoryOptions(Category c) async {
    final s = AppTranslations.of(context);
    final hint = c.defaultAmount != null ? '${s.tr('add.default_amount_current')}: ¥${c.defaultAmount!.toStringAsFixed(2)}' : s.tr('add.default_amount_none');
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.trCategory(c.name)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.attach_money, color: Colors.orange),
            title: Text(s.tr('add.default_amount')),
            subtitle: Text(hint, style: const TextStyle(fontSize: 12)),
            onTap: () { Navigator.pop(ctx, 'default'); },
          ),
          ListTile(
            leading: const Icon(Icons.notes, color: Colors.blueGrey),
            title: Text(s.tr('add.default_note')),
            subtitle: Text(c.defaultNote ?? s.tr('add.default_amount_none'), style: const TextStyle(fontSize: 12)),
            onTap: () { Navigator.pop(ctx, 'note'); },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: Text(s.tr('add.rename')),
            onTap: () { Navigator.pop(ctx, 'rename'); },
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert, color: Colors.teal),
            title: Text(s.tr('add.sort')),
            onTap: () { Navigator.pop(ctx, 'sort'); },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text(s.tr('add.delete'), style: const TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(ctx, 'delete'); },
          ),
        ]),
      ),
    );
    if (action == 'default') {
      await _setDefaultAmount(c);
    } else if (action == 'note') {
      await _setDefaultNote(c);
    } else if (action == 'rename') {
      await _renameCategory(c);
    } else if (action == 'sort') {
      await _showCategorySorter();
    } else if (action == 'delete') {
      await _deleteCategory(c);
    }
  }

  /// 设置分类默认金额
  Future<void> _setDefaultAmount(Category c) async {
    final controller = TextEditingController(text: c.defaultAmount?.toStringAsFixed(2) ?? '');
    final s = AppTranslations.of(context);
    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDiaState) => AlertDialog(
          title: Text(s.tr('add.default_amount_set', {'name': s.trCategory(c.name)})),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: s.tr('add.amount'), hintText: s.tr('add.default_amount_hint')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(s.tr('home.cancel'))),
            if (c.defaultAmount != null || controller.text.isNotEmpty)
              TextButton(
                onPressed: () {
                  controller.clear();
                  setDiaState(() {});
                },
                child: Text(s.tr('add.default_amount_clear'), style: const TextStyle(color: Colors.red)),
              ),
            FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(s.tr('add.rename_confirm'))),
          ],
        ),
      ),
    );
    if (confirm == null) return;
    if (confirm.isEmpty) {
      await widget.db.setCategoryDefaultAmount(c.id!, null);
    } else {
      final amount = double.tryParse(confirm);
      if (amount != null && amount > 0) {
        await widget.db.setCategoryDefaultAmount(c.id!, amount);
      } else {
        _showTopSnack(s.tr('add.error_amount_invalid'));
        return;
      }
    }
    final cats = await widget.db.allCategories();
    setState(() { _allCats = cats; });
  }

  /// 设置分类默认备注
  Future<void> _setDefaultNote(Category c) async {
    final controller = TextEditingController(text: c.defaultNote ?? '');
    final s = AppTranslations.of(context);
    final confirm = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('add.default_note_set', {'name': s.trCategory(c.name)})),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: s.tr('add.note'), hintText: s.tr('add.default_note_hint')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(s.tr('home.cancel'))),
          TextButton(
            onPressed: () { controller.clear(); },
            child: Text(s.tr('add.default_amount_clear'), style: const TextStyle(color: Colors.red)),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(s.tr('add.rename_confirm'))),
        ],
      ),
    );
    if (confirm == null) return;
    await widget.db.setCategoryDefaultNote(c.id!, confirm.isEmpty ? null : confirm);
    final cats = await widget.db.allCategories();
    setState(() { _allCats = cats; });
  }

  /// 拖拽排序分类
  Future<void> _showCategorySorter() async {
    final s = AppTranslations.of(context);
    // 临时复制一份，在对话框中拖拽排序
    final sorted = List<Category>.from(_filteredCats);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDiaState) => AlertDialog(
          title: Text(s.tr('add.sort_title')),
          content: SizedBox(
            width: double.maxFinite,
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              onReorder: (oldI, newI) {
                setDiaState(() {
                  if (newI > oldI) newI--;
                  final item = sorted.removeAt(oldI);
                  sorted.insert(newI, item);
                });
              },
              children: sorted.map((c) => ListTile(
                key: ValueKey(c.id),
                leading: ReorderableDragStartListener(
                  index: sorted.indexOf(c),
                  child: const Icon(Icons.drag_handle, color: Colors.grey),
                ),
                title: Text(s.trCategory(c.name)),
                trailing: c.defaultAmount != null
                    ? Text('¥${c.defaultAmount!.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
                    : null,
              )).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.tr('home.cancel'))),
            FilledButton(onPressed: () async {
              for (int i = 0; i < sorted.length; i++) {
                await widget.db.updateCategoryOrder(sorted[i].id!, i);
              }
              final cats = await widget.db.allCategories();
              setState(() { _allCats = cats; });
              if (ctx.mounted) Navigator.pop(ctx);
            }, child: Text(s.tr('add.rename_confirm'))),
          ],
        ),
      ),
    );
  }

  /// 重命名分类
  Future<void> _renameCategory(Category c) async {
    final controller = TextEditingController(text: c.name);
    final s = AppTranslations.of(context);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('add.rename_category_title')),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: s.tr('add.category_name'), hintText: c.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.tr('home.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(s.tr('add.rename_confirm'))),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != c.name) {
      // 查重
      if (_allCats.any((cat) => cat.name == newName && cat.type == c.type && cat.id != c.id)) {
        _showTopSnack(s.tr('add.error_category_duplicate'));
        return;
      }
      await widget.db.renameCategory(c.id!, newName);
      final cats = await widget.db.allCategories();
      setState(() { _allCats = cats; });
    }
  }

  /// 删除分类 — 确认后将分类下的交易归入"其他支出/其他收入"后删除
  Future<void> _deleteCategory(Category c) async {
    final s = AppTranslations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('add.delete_category_title', {'name': s.trCategory(c.name)})),
        content: Text(s.tr('add.delete_category_body', {'name': s.trCategory(c.name)})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.tr('home.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.tr('add.confirm_delete')),
          ),
        ],
      ),
    );
    if (ok == true && c.id != null) {
      await widget.db.deleteCategory(c.id!);
      final cats = await widget.db.allCategories();
      setState(() {
        _allCats = cats;
        // 如果删掉了当前选中的分类，自动选中第一个同类分类
        if (_categoryId == c.id) {
          _categoryId = _filteredCats.firstOrNull?.id;
        }
      });
    }
  }
}
