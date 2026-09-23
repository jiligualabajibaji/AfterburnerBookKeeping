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
  final double? quantity;       // 数量，null 或 0 不显示
  final String? unit;           // 单位
  final int timestamp;          // Unix 时间戳（秒）
  final String categoryType;    // 'expense' 或 'income'
  final bool isSelected;        // 是否选中（批量删除模式下）
  final bool showTime;          // 是否显示时分（主页 false，搜索页 true）
  final bool compactAmount;     // 整数金额省略小数部分，非整数去掉末尾多余的 0
  final bool showFixedDecimals; // compactAmount 模式下，金额是否统一显示两位小数
  final bool compactLayout;     // 流水页使用的紧凑布局
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onJump;

  const TransactionTile({super.key, required this.id, required this.amount,
    required this.categoryName, required this.note, this.quantity, this.unit,
    required this.timestamp, required this.categoryType, this.isSelected = false,
    this.showTime = true, this.compactAmount = false,
    this.showFixedDecimals = false, this.compactLayout = false,
    this.onTap, this.onLongPress, this.onJump});

  /// 去掉小数末尾多余的 0
  static String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = categoryType == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final sign = isExpense ? '-' : '+';
    final timeStr = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000));
    final subtitleFontSize = compactLayout ? 11.5 : 13.0;
    final timeFontSize = compactLayout ? 10.2 : 12.0;
    final amountFontSize = compactLayout ? 14.8 : 16.0;
    // 翻译内置分类名（如 其他支出 → Other expenses）
    final displayName = AppTranslations.of(context).trCategory(categoryName);
    // 数量/单位（数量为空或 0 时不显示），用淡红/淡绿显示在副标题
    final qty = (quantity == null || quantity! <= 0) ? '' : ' ×${_trimNum(quantity!)}${unit ?? ''}';
    final subtitle = (note.isNotEmpty || qty.isNotEmpty)
        ? Text.rich(TextSpan(children: [
            if (note.isNotEmpty)
              TextSpan(text: note, style: TextStyle(color: Colors.grey.shade600, fontSize: subtitleFontSize)),
            if (qty.isNotEmpty)
              TextSpan(text: qty, style: TextStyle(color: color.withAlpha(200), fontSize: subtitleFontSize)),
          ]), maxLines: null)
        : (showTime ? Text(timeStr, style: TextStyle(color: Colors.grey.shade500, fontSize: timeFontSize)) : null);
    final absoluteAmount = amount.abs();
    final amountText = compactAmount
        ? (showFixedDecimals
            ? absoluteAmount.toStringAsFixed(2)
            : _trimNum(absoluteAmount))
        : absoluteAmount.toStringAsFixed(2);
    final amountLabel = Text('$sign¥$amountText',
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: amountFontSize));

    // 左右等宽，中间按钮独立处理点击，其他区域仍打开编辑页。
    if (onJump != null) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Expanded(child: Row(children: [
              CircleAvatar(radius: 16, backgroundColor: color.withAlpha(30),
                child: Text(displayName[0], style: TextStyle(color: color))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (subtitle != null) subtitle,
              ])),
            ])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton(
                key: ValueKey('jump-transaction-$id'),
                onPressed: onJump,
                style: TextButton.styleFrom(
                  backgroundColor: color.shade50,
                  foregroundColor: color.shade800,
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(AppTranslations.of(context).tr('search.jump')),
              ),
            ),
            Expanded(child: Align(alignment: Alignment.centerRight, child: amountLabel)),
          ]),
        ),
      );
    }

    return Container(
      // 选中时绘制外发光边框
      decoration: isSelected ? BoxDecoration(
        borderRadius: BorderRadius.circular(compactLayout ? 10.2 : 12),
        border: Border.all(color: color.withAlpha(200), width: compactLayout ? 2.125 : 2.5),
        boxShadow: [
          BoxShadow(color: color.withAlpha(80),
            blurRadius: compactLayout ? 13.6 : 16,
            spreadRadius: compactLayout ? 1.7 : 2),
        ],
      ) : null,
      margin: isSelected
          ? EdgeInsets.symmetric(horizontal: 4, vertical: compactLayout ? 2.55 : 3)
          : null,
      child: ClipRRect(
        borderRadius: isSelected
            ? BorderRadius.circular(compactLayout ? 9.35 : 11)
            : BorderRadius.zero,
        child: ListTile(
          leading: CircleAvatar(
            radius: compactLayout ? 19 : null,
            backgroundColor: color.withAlpha(30),
            child: Text(displayName[0],  // 显示分类名的第一个字
              style: TextStyle(color: color, fontWeight: FontWeight.bold,
                fontSize: compactLayout ? 15 : null)),
          ),
          title: Text(displayName, style: TextStyle(fontWeight: FontWeight.w500,
            fontSize: compactLayout ? 14.3 : null)),
          subtitle: subtitle,
          trailing: amountLabel,
          dense: false,
          visualDensity: compactLayout ? const VisualDensity(vertical: -1.8) : null,
          minVerticalPadding: compactLayout ? 2.5 : null,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}
