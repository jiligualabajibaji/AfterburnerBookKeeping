import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';

class ExportData {
  final int version;
  final String exportTime;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;

  ExportData({
    this.version = 1, required this.exportTime,
    required this.categories, required this.transactions,
  });

  Map<String, dynamic> toJson() => {
    'version': version, 'export_time': exportTime,
    'categories': categories, 'transactions': transactions,
  };

  static ExportData fromJson(Map<String, dynamic> json) => ExportData(
    exportTime: json['export_time'] as String,
    categories: (json['categories'] as List).cast<Map<String, dynamic>>(),
    transactions: (json['transactions'] as List).cast<Map<String, dynamic>>(),
  );
}

class ExportService {
  final AppDatabase db;

  ExportService(this.db);

  Future<String> exportToJson() async {
    final cats = await db.allCategories();
    final txns = await db.allTransactions();

    final data = ExportData(
      exportTime: DateTime.now().toIso8601String(),
      categories: cats.map((c) => {
        'name': c.name, 'type': c.type,
      }).toList(),
      transactions: txns.map((t) => {
        'amount': t.transaction.amount,
        'category': t.category.name,
        'note': t.transaction.note ?? '',
        'timestamp': t.transaction.timestamp,
      }).toList(),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bookkeeping_export.json');
    await file.writeAsString(jsonEncode(data.toJson()));
    await Share.shareXFiles(
      [XFile(file.path)], text: '记账数据导出',
    );
    return file.path;
  }

  Future<Map<String, int>> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) {
      return {'imported': 0, 'skipped': 0};
    }
    final content = await File(result.files.single.path!).readAsString();
    final data = ExportData.fromJson(jsonDecode(content) as Map<String, dynamic>);

    int imported = 0, skipped = 0;

    // Import categories
    for (final c in data.categories) {
      final existing = await db.allCategories();
      if (!existing.any((e) => e.name == c['name'])) {
        await db.addCategory(c['name'] as String, type: c['type'] as String);
      }
    }

    // Import transactions (no dedup)
    final cats = await db.allCategories();
    for (final t in data.transactions) {
      final amt = (t['amount'] as num).toDouble();
      final ts = (t['timestamp'] as num).toInt();
      final note = t['note'] as String? ?? '';
      final catName = t['category'] as String? ?? '';
      final cat = cats.firstWhere(
        (c) => c.name == catName, orElse: () => cats.first,
      );
      await db.addTransaction(
        amount: amt,
        categoryId: cat.id!,
        note: note,
        timestamp: ts,
      );
      imported++;
    }

    return {'imported': imported, 'skipped': skipped};
  }
}
