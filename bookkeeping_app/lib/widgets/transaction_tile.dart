/// 交易列表项组件 — 在流水页和搜索页中展示单条交易记录。
/// 支出显示红色、收入显示绿色，金额前带 +/- 符号。
/// 选中时显示四周发光效果（用于批量删除模式）。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/translations.dart';

class TransactionTile extends StatelessWidget {
  final int id;
  final double amount;          // 金额（负数=支出，正数=收入）
  final String categoryName;    // 分类名称
  final String note;            // 备注
  final int timestamp;          // Unix 时间戳（秒）
  final String categoryType;    // 'expense' 或 'income'
  final bool isSelected;        // 是否选中（批量删除模式下）
  final bool showTime;          // 是否显示时分（主页 false，搜索页 true）
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TransactionTile({super.key, required this.id, required this.amount,
    required this.categoryName, required this.note, required this.timestamp,
    required this.categoryType, this.isSelected = false, this.showTime = true, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isExpense = categoryType == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final sign = isExpense ? '-' : '+';
    final timeStr = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000));
    // 翻译内置分类名（如 其他支出 → Other expenses）
    final displayName = AppTranslations.of(context).trCategory(categoryName);

    return Container(
      // 选中时绘制外发光边框
      decoration: isSelected ? BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(200), width: 2.5),
        boxShadow: [
          BoxShadow(color: color.withAlpha(80), blurRadius: 16, spreadRadius: 2),
        ],
      ) : null,
      margin: isSelected ? const EdgeInsets.symmetric(horizontal: 4, vertical: 3) : null,
      child: ClipRRect(
        borderRadius: isSelected ? BorderRadius.circular(11) : BorderRadius.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withAlpha(30),
            child: Text(displayName[0],  // 显示分类名的第一个字
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: note.isNotEmpty
              ? Text(note, maxLines: null, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
              : (showTime ? Text(timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)) : null),
          trailing: Text('$sign¥${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}
