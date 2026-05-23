import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionTile extends StatelessWidget {
  final int id;
  final double amount;
  final String categoryName;
  final String note;
  final int timestamp;
  final String categoryType;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TransactionTile({super.key, required this.id, required this.amount,
    required this.categoryName, required this.note, required this.timestamp,
    required this.categoryType, this.isSelected = false, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final isExpense = categoryType == 'expense';
    final color = isExpense ? Colors.red : Colors.green;
    final sign = isExpense ? '-' : '+';
    final timeStr = DateFormat('HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000));

    return Container(
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
            child: Text(categoryName[0],
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          title: Text(note.isNotEmpty ? note : categoryName),
          subtitle: Text('$categoryName  $timeStr'),
          trailing: Text('$sign¥${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}
