import 'package:bookkeeping_app/database/database.dart';
import 'package:drift/drift.dart';

/// Database tests for AppDatabase.
///
/// Uses in-memory database for testing to avoid platform dependencies.
void main() async {
  // Test 1: categories are seeded on creation
  print('Test 1: Categories seeding');
  final db = AppDatabase(useMemory: true);

  final cats = await db.allCategories();
  assert(cats.length == 9, 'Expected 9 categories, got ${cats.length}');
  print('PASS: 9 categories seeded');

  assert(cats.first.name == '餐饮', 'Expected 餐饮, got ${cats.first.name}');
  print('PASS: First category is ${cats.first.name}');

  // Test 2: add and retrieve a transaction
  print('Test 2: Add and retrieve transaction');
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final id = await db.addTransaction(TransactionsTableCompanion.insert(
    amount: -38.0,
    categoryId: cats.first.id,
    note: const Value('午餐'),
    timestamp: now,
    createdAt: now,
    updatedAt: now,
  ));
  assert(id > 0, 'Expected valid transaction ID, got $id');
  print('PASS: Transaction created with id=$id');

  final txns = await db.transactionsInMonth(DateTime.now());
  assert(txns.isNotEmpty, 'Expected at least one transaction');
  assert(txns.first.transactionsTable.amount == -38.0);
  assert(txns.first.categoriesTable.name == '餐饮');
  print('PASS: Found ${txns.length} transaction(s) in current month');

  await db.close();
  print('All database tests passed!');
}
