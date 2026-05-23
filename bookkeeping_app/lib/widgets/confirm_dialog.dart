import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ai_bridge.dart';

class ConfirmDialog extends StatefulWidget {
  final AiParseResult result;
  final ValueChanged<Map<String, dynamic>> onConfirm;

  const ConfirmDialog({super.key, required this.result, required this.onConfirm});

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  late TextEditingController _amountCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _noteCtrl;
  String? _category;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.result.amount?.toString() ?? '');
    _category = widget.result.category;
    _selectedDate = _parseDate(widget.result.timestamp);
    _dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedDate));
    _noteCtrl = TextEditingController(text: widget.result.note);
  }

  DateTime _parseDate(String ts) {
    try {
      return DateTime.parse(ts);
    } catch (_) {
      return DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const allCategories = ['餐饮','交通','购物','娱乐','住房','医疗','其他支出','工资收入','其他收入'];

    return AlertDialog(
      title: const Text('确认记账'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _amountCtrl,
          decoration: const InputDecoration(labelText: '金额', hintText: '请输入金额'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: allCategories.contains(_category) ? _category : null,
          decoration: const InputDecoration(labelText: '分类'),
          items: allCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => _category = v,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _dateCtrl,
          readOnly: true,
          decoration: const InputDecoration(labelText: '日期', suffixIcon: Icon(Icons.date_range)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
                _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
              });
            }
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(labelText: '备注'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () {
          widget.onConfirm({
            'amount': double.tryParse(_amountCtrl.text) ?? widget.result.amount,
            'category': _category ?? widget.result.category,
            'timestamp': DateFormat('yyyy-MM-dd').format(_selectedDate),
            'note': _noteCtrl.text,
          });
          Navigator.pop(context);
        }, child: const Text('保存')),
      ],
    );
  }
}
