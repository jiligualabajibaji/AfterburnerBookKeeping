import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
export 'models.dart';
import 'models.dart';

class AppDatabase {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'bookkeeping.db');
    return openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          // Remove duplicate "其他" category, reassign to "其他支出"
          await db.delete('categories', where: 'name = ? AND type = ?', whereArgs: ['其他', 'expense']);
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            type TEXT NOT NULL DEFAULT 'expense',
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category_id INTEGER NOT NULL REFERENCES categories(id),
            note TEXT,
            timestamp INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        final seeds = [
          ['其他支出', 'expense', 0], ['其他收入', 'income', 0],
          ['餐饮', 'expense', 1], ['交通', 'expense', 2], ['购物', 'expense', 3],
          ['娱乐', 'expense', 4], ['住房', 'expense', 5], ['医疗', 'expense', 6],
          ['工资收入', 'income', 7],
        ];
        for (final s in seeds) {
          await db.insert('categories', {'name': s[0], 'type': s[1], 'sort_order': s[2]});
        }
      },
    );
  }

  Future<void> close() async {
    if (_db != null) { await _db!.close(); _db = null; }
  }

  // Categories
  Future<List<Category>> allCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'sort_order');
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  Future<int> addCategory(String name, {String type = 'expense'}) async {
    final db = await database;
    return db.insert('categories', {'name': name, 'type': type, 'sort_order': 99});
  }

  Future<void> updateCategoryOrder(int id, int sortOrder) async {
    final db = await database;
    await db.update('categories', {'sort_order': sortOrder}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    // Find or create fallback category
    final fallback = await db.query('categories',
      where: 'name = ?', whereArgs: ['其他支出']);
    final fallbackId = fallback.isNotEmpty ? fallback.first['id'] as int
        : await db.insert('categories', {'name': '其他', 'type': 'expense', 'sort_order': 0});
    // Reassign transactions to fallback
    await db.update('transactions', {'category_id': fallbackId},
      where: 'category_id = ?', whereArgs: [id]);
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // Transactions
  Future<int> addTransaction({
    required double amount,
    required int categoryId,
    String? note,
    required int timestamp,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db.insert('transactions', {
      'amount': amount,
      'category_id': categoryId,
      'note': note,
      'timestamp': timestamp,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> updateTransaction(int id, {double? amount, int? categoryId, String? note, int? timestamp}) async {
    final db = await database;
    final values = <String, dynamic>{};
    if (amount != null) values['amount'] = amount;
    if (categoryId != null) values['category_id'] = categoryId;
    if (note != null) values['note'] = note;
    if (timestamp != null) values['timestamp'] = timestamp;
    values['updated_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db.update('transactions', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TransactionWithCategory>> transactionsInMonth(DateTime month) async {
    try {
      final db = await database;
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      final firstTs = firstDay.millisecondsSinceEpoch ~/ 1000;
      final lastTs = lastDay.millisecondsSinceEpoch ~/ 1000;

      final rows = await db.rawQuery('''
        SELECT t.*, c.name as cat_name, c.type as cat_type, c.sort_order
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE t.timestamp BETWEEN ? AND ?
        ORDER BY t.timestamp DESC
      ''', [firstTs, lastTs]);

      return rows.map((r) {
        final t = ExpenseRecord.fromMap(r);
        final c = Category(
          id: r['category_id'] as int,
          name: r['cat_name'] as String,
          type: r['cat_type'] as String,
          sortOrder: r['sort_order'] as int? ?? 0,
        );
        return TransactionWithCategory(t, c);
      }).toList();
    } catch (e) {
      debugPrint('transactionsInMonth 错误: $e');
      return [];
    }
  }

  Future<List<TransactionWithCategory>> allTransactions() async {
    try {
      final db = await database;
      final rows = await db.rawQuery('''
        SELECT t.*, c.name as cat_name, c.type as cat_type, c.sort_order
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        ORDER BY t.timestamp DESC
      ''');
      return rows.map((r) {
        return TransactionWithCategory(ExpenseRecord.fromMap(r), Category(
          id: r['category_id'] as int, name: r['cat_name'] as String,
          type: r['cat_type'] as String, sortOrder: r['sort_order'] as int? ?? 0,
        ));
      }).toList();
    } catch (e) {
      debugPrint('allTransactions 错误: $e');
      return [];
    }
  }

  Future<List<TransactionWithCategory>> transactionsInYear(int year) async {
    try {
      final db = await database;
      final firstTs = DateTime(year, 1, 1).millisecondsSinceEpoch ~/ 1000;
      final lastTs = DateTime(year, 12, 31, 23, 59, 59).millisecondsSinceEpoch ~/ 1000;
      final rows = await db.rawQuery('''
        SELECT t.*, c.name as cat_name, c.type as cat_type, c.sort_order
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE t.timestamp BETWEEN ? AND ?
        ORDER BY t.timestamp DESC
      ''', [firstTs, lastTs]);
      return rows.map((r) {
        return TransactionWithCategory(ExpenseRecord.fromMap(r), Category(
          id: r['category_id'] as int, name: r['cat_name'] as String,
          type: r['cat_type'] as String, sortOrder: r['sort_order'] as int? ?? 0,
        ));
      }).toList();
    } catch (e) {
      debugPrint('transactionsInYear 错误: $e');
      return [];
    }
  }

  Future<Map<String, double>> yearlySummary(int year) async {
    final txns = await transactionsInYear(year);
    final summary = <String, double>{};
    for (final r in txns) {
      summary[r.category.name] = (summary[r.category.name] ?? 0) + r.transaction.amount;
    }
    return summary;
  }

  Future<Map<String, double>> monthlySummary(DateTime month) async {
    try {
      final txns = await transactionsInMonth(month);
      final summary = <String, double>{};
      for (final r in txns) {
        final cat = r.category.name;
        summary[cat] = (summary[cat] ?? 0) + r.transaction.amount;
      }
      return summary;
    } catch (e) {
      debugPrint('monthlySummary 错误: $e');
      return {};
    }
  }

}
