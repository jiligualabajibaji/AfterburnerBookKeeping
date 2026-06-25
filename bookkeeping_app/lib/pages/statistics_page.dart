import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../services/translations.dart';

/// 统计页面 — 月度/年度收支饼图。
/// 显示各类别占比，支持月/年切换和支出/收入切换。
class StatisticsPage extends StatefulWidget {
  final AppDatabase db;
  const StatisticsPage({super.key, required this.db});
  @override State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateTime _date = DateTime.now();  // 当前选中的月份/年份
  bool _showExpense = true;         // true=显示支出 false=显示收入
  bool _showYear = false;           // true=年度统计 false=月度统计

  /// 从 composite key "type__name" 中提取分类显示名并翻译
  String _catName(String key) {
    final name = key.contains('__') ? key.split('__').last : key;
    return AppTranslations.of(context).trCategory(name);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    final loc = Localizations.localeOf(context).toString();
    return SafeArea(
      child: Column(children: [
        // ── 月/年切换 ──
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ChoiceChip(label: Text(t.tr('stats.month')), selected: !_showYear,
            onSelected: (_) => setState(() => _showYear = false)),
          const SizedBox(width: 8),
          ChoiceChip(label: Text(t.tr('stats.year')), selected: _showYear,
            onSelected: (_) => setState(() => _showYear = true)),
        ]),
        // ── 年月选择（左右箭头 + 点击弹出选择器） ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _date = _showYear
                ? DateTime(_date.year - 1, _date.month, 1)
                : DateTime(_date.year, _date.month - 1, 1))),
            GestureDetector(
              onTap: () async {
                if (_showYear) {
                  // 年度视图：只选年份
                  final picked = await showDialog<int>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(t.tr('common.select_year')),
                      content: SizedBox(
                        width: 280, height: 300,
                        child: YearPicker(
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          selectedDate: _date,
                          onChanged: (d) => Navigator.pop(ctx, d.year),
                        ),
                      ),
                    ),
                  );
                  if (picked != null) setState(() => _date = DateTime(picked, 1, 1));
                } else {
                  // 月度视图：先选年份，再选月份
                  final pickedYear = await showDialog<int>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(t.tr('common.select_year')),
                      content: SizedBox(
                        width: 280, height: 300,
                        child: YearPicker(
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          selectedDate: _date,
                          onChanged: (d) => Navigator.pop(ctx, d.year),
                        ),
                      ),
                    ),
                  );
                  if (pickedYear == null) return;
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: m == _date.month && pickedYear == _date.year
                                  ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                                foregroundColor: m == _date.month && pickedYear == _date.year
                                  ? Colors.white : Colors.black87,
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.pop(ctx, m),
                              child: Text(DateFormat.MMM(loc).format(DateTime(2024, m, 1))),
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                  if (pickedMonth != null) setState(() => _date = DateTime(pickedYear, pickedMonth, 1));
                }
              },
              child: Text(
                _showYear ? '${_date.year}' : DateFormat.yMMMM(loc).format(_date),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _date = _showYear
                ? DateTime(_date.year + 1, _date.month, 1)
                : DateTime(_date.year, _date.month + 1, 1))),
          ]),
        ),
        // ── 支出/收入切换 ──
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ChoiceChip(label: Text(t.tr('stats.expense')), selected: _showExpense,
            selectedColor: Colors.red.withAlpha(40),
            onSelected: (_) => setState(() => _showExpense = true)),
          const SizedBox(width: 12),
          ChoiceChip(label: Text(t.tr('stats.income')), selected: !_showExpense,
            selectedColor: Colors.green.withAlpha(40),
            onSelected: (_) => setState(() => _showExpense = false)),
        ]),
        const SizedBox(height: 8),
        // ── 图表区域 ──
        Expanded(
          child: FutureBuilder<Map<String, double>>(
            future: _showYear ? widget.db.yearlySummary(_date.year) : widget.db.monthlySummary(_date),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final data = snap.data!;
              // 过滤出支出或收入数据
              var items = data.entries
                .where((e) => _showExpense ? e.value < 0 : e.value > 0)
                .toList();
              if (items.isEmpty) {
                return Center(child: Text(_showExpense ? t.tr('stats.no_expense') : t.tr('stats.no_income')));
              }
              final total = items.fold(0.0, (sum, e) => sum + e.value.abs());
              if (total == 0) {
                return Center(child: Text(_showExpense ? t.tr('stats.no_expense') : t.tr('stats.no_income')));
              }
              // 饼图配色：支出暖色系、收入绿色系
              final colors = _showExpense
                ? [Colors.red, Colors.deepOrange, Colors.orange, Colors.amber,
                   Colors.brown, Colors.pink, Colors.deepPurple, Colors.indigo, Colors.redAccent]
                : [Colors.green, Colors.teal, Colors.lightGreen, Colors.lime,
                   Colors.greenAccent, Colors.tealAccent, Colors.cyan, Colors.lightGreenAccent, Colors.limeAccent];
              return Column(children: [
                // 合计金额
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${_showYear ? _date.year : DateFormat.MMM(loc).format(_date)} ${_showExpense ? t.tr('stats.expense') : t.tr('stats.income')}: ¥${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                // 饼图 + 类别列表
                Expanded(
                  child: ListView(children: [
                    SizedBox(
                      height: 220,
                      child: PieChart(PieChartData(
                        sections: items.asMap().entries.map((e) {
                          final pct = e.value.value.abs() / total * 100;
                          return PieChartSectionData(
                            value: e.value.value.abs(),
                            title: pct >= 8 ? '${pct.toStringAsFixed(2)}%' : '',   // 占比 >= 8% 才在扇区内显示
                            color: colors[e.key % colors.length],
                            radius: pct < 3 ? 40 : (pct < 8 ? 52 : 62),           // 小扇区半径缩小
                            titleStyle: TextStyle(
                              fontSize: pct < 8 ? 9 : 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            badgeWidget: pct < 8
                              ? Text('${pct.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: colors[e.key % colors.length],
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    backgroundColor: Colors.white.withAlpha(200),
                                  ))
                              : null,
                            badgePositionPercentageOffset: pct < 5 ? 1.4 : 1.2,
                          );
                        }).toList(),
                      )),
                    ),
                    const Divider(height: 32),
                    // 图例：每种类别的名称和金额
                    ...items.map((e) => ListTile(
                      leading: Icon(Icons.circle, color: colors[items.indexOf(e) % colors.length], size: 12),
                      title: Text(_catName(e.key)),
                      trailing: Text('¥${e.value.abs().toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    )),
                  ]),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
