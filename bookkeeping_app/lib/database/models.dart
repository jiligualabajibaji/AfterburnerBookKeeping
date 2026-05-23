class Category {
  final int? id;
  final String name;
  final String type; // 'expense' or 'income'
  final int sortOrder;

  Category({this.id, required this.name, this.type = 'expense', this.sortOrder = 0});

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type,
    'sort_order': sortOrder,
  };

  factory Category.fromMap(Map<String, dynamic> m) => Category(
    id: m['id'] as int?,
    name: m['name'] as String,
    type: m['type'] as String? ?? 'expense',
    sortOrder: m['sort_order'] as int? ?? 0,
  );
}

class ExpenseRecord {
  final int? id;
  final double amount;
  final int categoryId;
  final String? note;
  final int timestamp;
  final int createdAt;
  final int updatedAt;

  ExpenseRecord({
    this.id,
    required this.amount,
    required this.categoryId,
    this.note,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'category_id': categoryId,
    'note': note,
    'timestamp': timestamp,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory ExpenseRecord.fromMap(Map<String, dynamic> m) => ExpenseRecord(
    id: m['id'] as int?,
    amount: (m['amount'] as num).toDouble(),
    categoryId: m['category_id'] as int,
    note: m['note'] as String?,
    timestamp: m['timestamp'] as int,
    createdAt: m['created_at'] as int,
    updatedAt: m['updated_at'] as int,
  );
}

class TransactionWithCategory {
  final ExpenseRecord transaction;
  final Category category;
  TransactionWithCategory(this.transaction, this.category);
}
