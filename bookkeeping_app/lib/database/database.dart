/// 数据访问层 — 封装所有 SQLite 操作。
/// 包含两个数据表：categories（分类）和 transactions（交易记录）。
/// 提供 CRUD、按月份/年份查询、汇总统计、关键词搜索等功能。
///
/// 数据库文件路径：getApplicationDocumentsDirectory()/bookkeeping.db
/// 当前 Schema 版本：6（v5→v6 新增 quantity/unit 字段）

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
export 'models.dart';  // 同时导出数据模型，方便外部只 import database.dart
import 'models.dart';

class AppDatabase {
  Database? _db;  // 懒加载的单例数据库连接

  /// 获取数据库连接，首次调用时初始化
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  /// 初始化数据库：打开或创建 bookkeeping.db，执行建表/迁移
  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'bookkeeping.db');
    return openDatabase(
      path,
      version: 6,  // 当前 Schema 版本
      onUpgrade: (db, oldV, newV) async {
        // v1 → v2: 删除重复的"其他"支出分类
        if (oldV < 2) {
          await db.delete('categories', where: 'name = ? AND type = ?', whereArgs: ['其他', 'expense']);
        }
        // v2 → v3: 移除 categories.name 的 UNIQUE 约束，改为允许跨类型同名
        if (oldV < 3) {
          await db.execute('ALTER TABLE categories RENAME TO categories_old');
          await db.execute('''
            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              type TEXT NOT NULL DEFAULT 'expense',
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('INSERT INTO categories SELECT * FROM categories_old');
          await db.execute('DROP TABLE categories_old');
        }
        // v3 → v4: 新增 default_amount 字段
        if (oldV < 4) {
          await db.execute('ALTER TABLE categories ADD COLUMN default_amount REAL');
        }
        // v4 → v5: 新增 default_note 字段
        if (oldV < 5) {
          await db.execute('ALTER TABLE categories ADD COLUMN default_note TEXT');
        }
        // v5 → v6: 新增 quantity/unit 字段
        if (oldV < 6) {
          await db.execute('ALTER TABLE transactions ADD COLUMN quantity REAL');
          await db.execute('ALTER TABLE transactions ADD COLUMN unit TEXT');
        }
      },
      onCreate: (db, version) async {
        // 建表：categories（分类）
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'expense',
            sort_order INTEGER NOT NULL DEFAULT 0,
            default_amount REAL,
            default_note TEXT
          )
        ''');
        // 建表：transactions（交易记录）
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            category_id INTEGER NOT NULL REFERENCES categories(id),
            note TEXT,
            quantity REAL,
            unit TEXT,
            timestamp INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        // 插入默认分类种子数据
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

  /// 关闭数据库连接
  Future<void> close() async {
    if (_db != null) { await _db!.close(); _db = null; }
  }

  // ═══════════════════════════════════════
  //  分类操作
  // ═══════════════════════════════════════

  /// 获取全部分类，按 sort_order 排序
  Future<List<Category>> allCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'sort_order');
    return rows.map((r) => Category.fromMap(r)).toList();
  }

  /// 添加新分类，默认 sort_order = 99（排到最后）
  Future<int> addCategory(String name, {String type = 'expense'}) async {
    final db = await database;
    return db.insert('categories', {'name': name, 'type': type, 'sort_order': 99});
  }

  /// 重命名分类
  Future<void> renameCategory(int id, String newName) async {
    final db = await database;
    await db.update('categories', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }

  /// 设置分类默认金额（null 表示清除默认值）
  Future<void> setCategoryDefaultAmount(int id, double? amount) async {
    final db = await database;
    await db.update('categories', {'default_amount': amount}, where: 'id = ?', whereArgs: [id]);
  }

  /// 设置分类默认备注（null 表示清除默认值）
  Future<void> setCategoryDefaultNote(int id, String? note) async {
    final db = await database;
    await db.update('categories', {'default_note': note}, where: 'id = ?', whereArgs: [id]);
  }

  /// 更新分类排序
  Future<void> updateCategoryOrder(int id, int sortOrder) async {
    final db = await database;
    await db.update('categories', {'sort_order': sortOrder}, where: 'id = ?', whereArgs: [id]);
  }

  /// 返回指定分类当前包含的交易记录数量。
  Future<int> transactionCountForCategory(int categoryId) async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM transactions WHERE category_id = ?',
      [categoryId],
    )) ?? 0;
  }

  /// 删除分类：先将该分类下的交易迁移到用户指定的同类型分类。
  /// 未指定目标时保留原有行为，迁移到对应的兜底分类。
  Future<int> deleteCategory(int id, {int? targetCategoryId, String? prependedNote}) async {
    final db = await database;
    return db.transaction((txn) async {
      final source = await txn.query('categories', where: 'id = ?', whereArgs: [id]);
      if (source.isEmpty) return 0;
      final type = source.first['type'] as String? ?? 'expense';

      int destinationId;
      if (targetCategoryId != null) {
        if (targetCategoryId == id) {
          throw ArgumentError('目标分类不能是被删除的分类');
        }
        final target = await txn.query('categories',
          where: 'id = ? AND type = ?', whereArgs: [targetCategoryId, type]);
        if (target.isEmpty) {
          throw ArgumentError('目标分类不存在或收支类型不一致');
        }
        destinationId = targetCategoryId;
      } else {
        final fallbackName = type == 'income' ? '其他收入' : '其他支出';
        final fallback = await txn.query('categories',
          where: 'name = ? AND type = ?', whereArgs: [fallbackName, type]);
        destinationId = fallback.isNotEmpty
            ? fallback.first['id'] as int
            : await txn.insert('categories', {
                'name': fallbackName, 'type': type, 'sort_order': 0,
              });
      }

      final notePrefix = prependedNote?.trim() ?? '';
      if (notePrefix.isNotEmpty) {
        await txn.rawUpdate('''
          UPDATE transactions
          SET note = CASE
            WHEN note IS NULL OR TRIM(note) = '' THEN ?
            ELSE ? || ' ' || note
          END
          WHERE category_id = ?
        ''', [notePrefix, notePrefix, id]);
      }
      await txn.update('transactions', {'category_id': destinationId},
        where: 'category_id = ?', whereArgs: [id]);
      return txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ═══════════════════════════════════════
  //  交易记录操作
  // ═══════════════════════════════════════

  /// 新增交易记录
  Future<int> addTransaction({
    required double amount,
    required int categoryId,
    String? note,
    double? quantity,
    String? unit,
    required int timestamp,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db.insert('transactions', {
      'amount': amount,
      'category_id': categoryId,
      'note': note,
      'quantity': quantity,
      'unit': unit,
      'timestamp': timestamp,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// 更新交易记录（只更新非 null 的字段）
  /// [quantity] / [unit] 使用 [_UNSET] 哨兵区分"不修改"与"清空为 null"
  static const _UNSET = Object();
  Future<int> updateTransaction(int id, {double? amount, int? categoryId, String? note,
      Object? quantity = _UNSET, Object? unit = _UNSET, int? timestamp}) async {
    final db = await database;
    final values = <String, dynamic>{};
    if (amount != null) values['amount'] = amount;
    if (categoryId != null) values['category_id'] = categoryId;
    if (note != null) values['note'] = note;
    if (quantity != _UNSET) values['quantity'] = quantity as double?;
    if (unit != _UNSET) values['unit'] = unit as String?;
    if (timestamp != null) values['timestamp'] = timestamp;
    values['updated_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return db.update('transactions', values, where: 'id = ?', whereArgs: [id]);
  }

  /// 删除单条交易记录
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// 查询某个月份的所有交易（含分类 JOIN），按时间倒序
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
        ORDER BY t.timestamp DESC, t.id DESC
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

  /// 查询全部交易（不含时间范围），按时间倒序
  Future<List<TransactionWithCategory>> allTransactions() async {
    try {
      final db = await database;
      final rows = await db.rawQuery('''
        SELECT t.*, c.name as cat_name, c.type as cat_type, c.sort_order
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        ORDER BY t.timestamp DESC, t.id DESC
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

  /// 查询某年的所有交易，按时间倒序
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
        ORDER BY t.timestamp DESC, t.id DESC
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

  /// 按关键词搜索交易，支持日期范围和收支类型筛选
  ///
  /// [keyword] 搜索关键词
  /// [searchFields] 搜索字段：'category', 'note', 'amount'，默认全选
  /// [startDate] / [endDate] 日期范围筛选
  /// [type] 收支类型筛选：'expense' 或 'income'，null 表示全部
  Future<List<TransactionWithCategory>> searchTransactions(
    String keyword, {
    Set<String>? searchFields,
    DateTime? startDate,
    DateTime? endDate,
    String? type,
  }) async {
    try {
      final db = await database;
      final pattern = '%$keyword%';
      final fields = searchFields ?? {'category', 'note', 'amount'};
      // 动态构建 WHERE 条件
      final likes = <String>[];
      final args = <dynamic>[];
      if (fields.contains('note')) { likes.add('t.note LIKE ?'); args.add(pattern); }
      if (fields.contains('category')) { likes.add('c.name LIKE ?'); args.add(pattern); }
      if (fields.contains('amount')) {
        final amount = double.tryParse(keyword);
        if (amount != null) { likes.add('ABS(t.amount) = ?'); args.add(amount.abs()); }
      }
      final conditions = <String>[likes.isEmpty ? '0' : '(${likes.join(' OR ')})'];

      if (startDate != null) {
        conditions.add('t.timestamp >= ?');
        args.add(startDate.millisecondsSinceEpoch ~/ 1000);
      }
      if (endDate != null) {
        conditions.add('t.timestamp <= ?');
        args.add(endDate.millisecondsSinceEpoch ~/ 1000);
      }
      if (type != null) {
        conditions.add('c.type = ?');
        args.add(type);
      }

      final rows = await db.rawQuery('''
        SELECT t.*, c.name as cat_name, c.type as cat_type, c.sort_order
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE ${conditions.join(' AND ')}
        ORDER BY t.timestamp DESC, t.id DESC
      ''', args);
      return rows.map((r) {
        return TransactionWithCategory(ExpenseRecord.fromMap(r), Category(
          id: r['category_id'] as int, name: r['cat_name'] as String,
          type: r['cat_type'] as String, sortOrder: r['sort_order'] as int? ?? 0,
        ));
      }).toList();
    } catch (e) {
      debugPrint('searchTransactions 错误: $e');
      return [];
    }
  }

  /// 年度汇总：按类别名+类型分组求和各交易金额
  Future<Map<String, double>> yearlySummary(int year) async {
    final txns = await transactionsInYear(year);
    final summary = <String, double>{};
    for (final r in txns) {
      final key = '${r.category.type}__${r.category.name}';
      summary[key] = (summary[key] ?? 0) + r.transaction.amount;
    }
    return summary;
  }

  /// 月度汇总：按类别名+类型分组求和各交易金额
  Future<Map<String, double>> monthlySummary(DateTime month) async {
    try {
      final txns = await transactionsInMonth(month);
      final summary = <String, double>{};
      for (final r in txns) {
        final key = '${r.category.type}__${r.category.name}';
        summary[key] = (summary[key] ?? 0) + r.transaction.amount;
      }
      return summary;
    } catch (e) {
      debugPrint('monthlySummary 错误: $e');
      return {};
    }
  }
}
