import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';

class StatisticsPage extends StatefulWidget {
  final AppDatabase db;
  const StatisticsPage({super.key, required this.db});
  @override State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  DateTime _date = DateTime.now();
  bool _showExpense = true;
  bool _showYear = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ChoiceChip(label: const Text('月'), selected: !_showYear,
            onSelected: (_) => setState(() => _showYear = false)),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('年'), selected: _showYear,
            onSelected: (_) => setState(() => _showYear = true)),
        ]),
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
                  final picked = await showDialog<int>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('选择年份'),
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
                  final pickedYear = await showDialog<int>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('选择年份'),
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
                      title: Text('${pickedYear}年'),
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
                              child: Text('${m}月'),
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
                _showYear ? '${_date.year}年' : DateFormat('yyyy年M月', 'zh_CN').format(_date),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _date = _showYear
                ? DateTime(_date.year + 1, _date.month, 1)
                : DateTime(_date.year, _date.month + 1, 1))),
          ]),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ChoiceChip(label: const Text('支出'), selected: _showExpense,
            onSelected: (_) => setState(() => _showExpense = true)),
          const SizedBox(width: 12),
          ChoiceChip(label: const Text('收入'), selected: !_showExpense,
            onSelected: (_) => setState(() => _showExpense = false)),
        ]),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<Map<String, double>>(
            future: _showYear ? widget.db.yearlySummary(_date.year) : widget.db.monthlySummary(_date),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final data = snap.data!;
              var items = data.entries
                .where((e) => _showExpense ? e.value < 0 : e.value > 0)
                .toList();
              if (items.isEmpty) {
                return Center(child: Text(_showExpense ? '暂无支出' : '暂无收入'));
              }
              final total = items.fold(0.0, (sum, e) => sum + e.value.abs());
              if (total == 0) {
                return Center(child: Text(_showExpense ? '暂无支出' : '暂无收入'));
              }
              final colors = _showExpense
                ? [Colors.red, Colors.deepOrange, Colors.orange, Colors.amber,
                   Colors.brown, Colors.pink, Colors.deepPurple, Colors.indigo, Colors.redAccent]
                : [Colors.green, Colors.teal, Colors.lightGreen, Colors.lime,
                   Colors.greenAccent, Colors.tealAccent, Colors.cyan, Colors.lightGreenAccent, Colors.limeAccent];
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${_showYear ? _date.year : DateFormat('M月', 'zh_CN').format(_date)} ${_showExpense ? '支出' : '收入'} 合计: ¥${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView(children: [
                    SizedBox(
                      height: 220,
                      child: PieChart(PieChartData(
                        sections: items.asMap().entries.map((e) {
                          final pct = e.value.value.abs() / total * 100;
                          return PieChartSectionData(
                            value: e.value.value.abs(),
                            title: pct >= 8 ? '${pct.toStringAsFixed(2)}%' : '',
                            color: colors[e.key % colors.length],
                            radius: pct < 3 ? 40 : (pct < 8 ? 52 : 62),
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
                    ...items.map((e) => ListTile(
                      leading: Icon(Icons.circle, color: colors[items.indexOf(e) % colors.length], size: 12),
                      title: Text(e.key),
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
