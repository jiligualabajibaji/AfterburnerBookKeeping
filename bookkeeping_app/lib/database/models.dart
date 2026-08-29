/// 数据模型 — 定义 Category（分类）和 ExpenseRecord（交易记录）两个核心类。
/// 提供 fromMap() / toMap() 用于 SQLite 行数据的序列化和反序列化。
/// TransactionWithCategory 是 JOIN 查询结果的联合模型。

class Category {
  final int? id;       // 分类 ID，null 表示尚未存入数据库
  final String name;   // 分类名称
  final String type;   // 'expense'（支出）或 'income'（收入）
  final int sortOrder; // 排序序号
  final double? defaultAmount; // 默认金额，null 表示无默认值
  final String? defaultNote;   // 默认备注，null 表示无默认值

  Category({this.id, required this.name, this.type = 'expense', this.sortOrder = 0, this.defaultAmount, this.defaultNote});

  /// 序列化为 SQLite 行数据
  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type,
    'sort_order': sortOrder,
    'default_amount': defaultAmount,
    'default_note': defaultNote,
  };

  /// 从 SQLite 行数据反序列化
  factory Category.fromMap(Map<String, dynamic> m) => Category(
    id: m['id'] as int?,
    name: m['name'] as String,
    type: m['type'] as String? ?? 'expense',
    sortOrder: m['sort_order'] as int? ?? 0,
    defaultAmount: m['default_amount'] as double?,
    defaultNote: m['default_note'] as String?,
  );
}

/// 交易记录模型（单表字段，不含分类信息）
class ExpenseRecord {
  final int? id;
  final double amount;       // 金额（支出为负数，收入为正数）
  final int categoryId;      // 分类 ID
  final String? note;        // 备注
  final double? quantity;    // 数量，null 表示未填写
  final String? unit;        // 单位，null 表示未填写
  final int timestamp;       // Unix 时间戳（秒）
  final int createdAt;       // 创建时间
  final int updatedAt;       // 最后更新时间

  ExpenseRecord({
    this.id,
    required this.amount,
    required this.categoryId,
    this.note,
    this.quantity,
    this.unit,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'category_id': categoryId,
    'note': note,
    'quantity': quantity,
    'unit': unit,
    'timestamp': timestamp,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory ExpenseRecord.fromMap(Map<String, dynamic> m) => ExpenseRecord(
    id: m['id'] as int?,
    amount: (m['amount'] as num).toDouble(),
    categoryId: m['category_id'] as int,
    note: m['note'] as String?,
    quantity: (m['quantity'] as num?)?.toDouble(),
    unit: m['unit'] as String?,
    timestamp: m['timestamp'] as int,
    createdAt: m['created_at'] as int,
    updatedAt: m['updated_at'] as int,
  );
}

/// 交易记录 + 分类的联合模型（JOIN 查询结果）
/// 将 transactions 表和 categories 表 JOIN 后的结果拆分为两个结构化对象
class TransactionWithCategory {
  final ExpenseRecord transaction;
  final Category category;
  TransactionWithCategory(this.transaction, this.category);
}
