import 'package:bookkeeping_app/database/database.dart';
import 'package:bookkeeping_app/pages/add_transaction_page.dart';
import 'package:bookkeeping_app/services/settings_service.dart';
import 'package:bookkeeping_app/services/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _Settings extends SettingsService {
  final Set<int> collapsed = {};
  List<String> unitList = ['个', '箱'];
  Map<String, double> steps = {'个': 1, '箱': 6};
  String selectedDefaultUnit = '个';
  double? selectedDefaultQuantity;
  bool ledgerFixedDecimals = false;

  @override
  Future<void> init() async {}
  @override
  String get defaultUnit => selectedDefaultUnit;
  @override
  set defaultUnit(String value) { selectedDefaultUnit = value; }
  @override
  double? get defaultQuantity => selectedDefaultQuantity;
  @override
  set defaultQuantity(double? value) { selectedDefaultQuantity = value; }
  @override
  List<String> get units => List<String>.from(unitList);
  @override
  set units(List<String> value) { unitList = List<String>.from(value); }
  @override
  Map<String, double> get unitStepIntervals => Map<String, double>.from(steps);
  @override
  set unitStepIntervals(Map<String, double> value) { steps = Map<String, double>.from(value); }
  @override
  double stepIntervalForUnit(String unit) => steps[unit] ?? 1;
  @override
  bool get showLedgerFixedDecimals => ledgerFixedDecimals;
  @override
  set showLedgerFixedDecimals(bool value) => ledgerFixedDecimals = value;
  @override
  Set<int> get collapsedCategoryIds => Set<int>.from(collapsed);
  @override
  Future<void> setCategoryCollapsed(int categoryId, bool value) async {
    value ? collapsed.add(categoryId) : collapsed.remove(categoryId);
  }
}

class _Database extends AppDatabase {
  final categories = <Category>[
    Category(id: 1, name: '其他支出', type: 'expense'),
    Category(id: 2, name: '餐饮', type: 'expense'),
    Category(
      id: 3,
      name: '交通',
      type: 'expense',
      defaultAmount: 88,
      defaultNote: '这是一条很长很长并且需要显示省略号的默认备注',
    ),
    Category(id: 4, name: '购物', type: 'expense'),
    Category(id: 5, name: '其他收入', type: 'income'),
  ];
  int? deletedId;
  int? movedToId;
  String? prependedNote;

  @override
  Future<int> transactionCountForCategory(int categoryId) async =>
      categoryId == 4 ? 7 : 0;

  @override
  Future<List<Category>> allCategories() async => List<Category>.from(categories);

  @override
  Future<int> deleteCategory(int id, {int? targetCategoryId, String? prependedNote}) async {
    deletedId = id;
    movedToId = targetCategoryId;
    this.prependedNote = prependedNote;
    categories.removeWhere((category) => category.id == id);
    return 1;
  }
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: const [
    AppTranslationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

void main() {
  testWidgets('save and return sits between title and add another', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(AddTransactionPage(
      db: _Database(),
      settings: _Settings(),
    )));
    await tester.pumpAndSettle();

    final title = find.byKey(const ValueKey('add-page-title'));
    final save = find.byKey(const ValueKey('save-return-button'));
    final addAnother = find.byKey(const ValueKey('add-another-button'));
    expect(save, findsOneWidget);
    expect(addAnother, findsOneWidget);
    expect(find.text('存&回'), findsOneWidget);
    expect(find.text('保存并返回'), findsNothing);
    expect(
      find.descendant(of: save, matching: find.byIcon(Icons.save)),
      findsOneWidget,
    );
    expect(tester.getSize(addAnother).width, lessThan(100));
    expect(AppTranslations(const Locale('en')).tr('add.save_return'), 'Save');
    expect(tester.getCenter(title).dx, lessThan(tester.getCenter(save).dx));
    expect(tester.getCenter(save).dx, lessThan(tester.getCenter(addAnother).dx));
    expect(
      tester.getCenter(save).dx,
      closeTo(
        (tester.getCenter(title).dx + tester.getCenter(addAnother).dx) / 2,
        0.1,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('category defaults only fill an amount the user has not entered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(AddTransactionPage(
      db: _Database(),
      settings: _Settings(),
    )));
    await tester.pumpAndSettle();

    final amountInput = find.byKey(const ValueKey('amount-input'));
    await tester.enterText(amountInput, '12');
    await tester.tap(find.text('交通'));
    await tester.pump();
    expect(tester.widget<TextField>(amountInput).controller!.text, '12');

    await tester.enterText(amountInput, '');
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    expect(tester.widget<TextField>(amountInput).controller!.text, isEmpty);
    await tester.tap(find.text('交通'));
    await tester.pump();
    expect(tester.widget<TextField>(amountInput).controller!.text, '88.0');
    await tester.tap(find.text('餐饮'));
    await tester.pump();
    expect(tester.widget<TextField>(amountInput).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category chip shows default note and amount indicators', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(AddTransactionPage(
      db: _Database(),
      settings: _Settings(),
    )));
    await tester.pumpAndSettle();

    final chip = find.byKey(const ValueKey('category-chip-3'));
    final note = find.byKey(const ValueKey('category-default-note-3'));
    final amount = find.byKey(const ValueKey('category-default-amount-3'));
    expect(chip, findsOneWidget);
    expect(note, findsOneWidget);
    expect(amount, findsOneWidget);
    expect(tester.getSize(chip).width, closeTo(60, 2));
    expect(tester.getSize(chip).height, 66);
    expect(
      tester.widget<Container>(chip).padding,
      const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('category-chip-2'))).height,
      tester.getSize(chip).height,
    );

    final noteText = tester.widget<Text>(find.descendant(
      of: note,
      matching: find.text('这是一条很长很长并且需要显示省略号的默认备注'),
    ));
    expect(noteText.overflow, TextOverflow.ellipsis);
    expect(noteText.maxLines, 1);
    expect(noteText.style!.fontSize, 10.5);
    expect(find.descendant(of: note, matching: find.byIcon(Icons.notes)), findsOneWidget);
    expect(find.descendant(of: amount, matching: find.byIcon(Icons.attach_money)), findsOneWidget);
    expect(find.descendant(of: amount, matching: find.text('88')), findsOneWidget);

    await tester.longPress(find.text('交通'));
    await tester.pumpAndSettle();
    final amountMenuTile = find.widgetWithText(ListTile, '默认金额');
    final noteMenuTile = find.widgetWithText(ListTile, '默认备注');
    final renameMenuTile = find.widgetWithText(ListTile, '重命名');
    expect(
      tester.widget<Icon>(find.descendant(
        of: amountMenuTile,
        matching: find.byIcon(Icons.attach_money),
      )).color,
      Colors.amber.shade700,
    );
    expect(
      tester.widget<Icon>(find.descendant(
        of: noteMenuTile,
        matching: find.byIcon(Icons.notes),
      )).color,
      Colors.blue,
    );
    expect(
      tester.widget<Icon>(find.descendant(
        of: renameMenuTile,
        matching: find.byIcon(Icons.edit),
      )).color,
      Colors.purple,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing an integer amount never adds decimals', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = _Database();
    final record = TransactionWithCategory(
      ExpenseRecord(
        id: 10,
        amount: -3,
        categoryId: 2,
        note: '',
        timestamp: DateTime(2024, 2, 1).millisecondsSinceEpoch ~/ 1000,
        createdAt: 0,
        updatedAt: 0,
      ),
      database.categories[1],
    );

    for (final showDecimals in [false, true]) {
      final settings = _Settings()..ledgerFixedDecimals = showDecimals;
      await tester.pumpWidget(_app(AddTransactionPage(
        db: database,
        settings: settings,
        editTxn: record,
      )));
      await tester.pumpAndSettle();
      final amount = tester.widget<TextField>(
        find.byKey(const ValueKey('amount-input')),
      );
      expect(amount.controller!.text, '3');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('each unit uses and edits its own step interval', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = _Settings();
    await tester.pumpWidget(_app(AddTransactionPage(
      db: _Database(), settings: settings,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('unit-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('箱').last);
    await tester.pumpAndSettle();
    final quantityInput = find.byKey(const ValueKey('quantity-input'));
    await tester.enterText(quantityInput, '2.5');
    await tester.tap(find.byKey(const ValueKey('quantity-minus')));
    await tester.pump();
    expect(tester.widget<TextField>(quantityInput).controller!.text, '0');
    await tester.tap(find.byKey(const ValueKey('quantity-plus')));
    await tester.pump();
    expect(tester.widget<TextField>(quantityInput).controller!.text, '6');

    await tester.longPress(find.text('长按此处进入默认个数和单位的设置'));
    await tester.pumpAndSettle();
    expect(find.text('步长：1'), findsOneWidget);
    expect(find.text('步长：6'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-unit-step-箱')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '2.5');
    await tester.tap(find.text('确认').last);
    await tester.pumpAndSettle();
    expect(find.text('步长：2.5'), findsOneWidget);
    await tester.tap(find.text('确认').last);
    await tester.pumpAndSettle();
    expect(settings.steps['箱'], 2.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('categories can be collapsed and expanded from the ellipsis button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = _Settings();
    await tester.pumpWidget(_app(AddTransactionPage(
      db: _Database(), settings: settings,
    )));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('交通'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放入折叠'));
    await tester.pumpAndSettle();

    expect(settings.collapsed, contains(3));
    expect(find.text('交通'), findsNothing);
    final ellipsis = find.byKey(const ValueKey('collapsed-categories-button'));
    expect(ellipsis, findsOneWidget);

    await tester.longPress(ellipsis);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(ellipsis);
    await tester.pumpAndSettle();
    expect(find.text('交通'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting a category moves its records to the selected category', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = _Database();
    await tester.pumpWidget(_app(AddTransactionPage(
      db: database, settings: _Settings(),
    )));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('购物'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('记录移动到'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    expect(find.text('其他收入'), findsNothing);
    await tester.tap(find.text('餐饮').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '添加到原备注前（可选）'),
      '历史分类',
    );
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();

    expect(database.deletedId, isNull);
    expect(find.byKey(const ValueKey('confirm-category-delete-dialog')), findsOneWidget);
    expect(find.text('待删除分类：购物'), findsOneWidget);
    expect(find.text('分类下的明细：7条'), findsOneWidget);
    expect(find.text('记录移动到：餐饮'), findsOneWidget);
    expect(find.text('新增备注：历史分类'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-category-delete-button')),
    );
    await tester.pumpAndSettle();

    expect(database.deletedId, 4);
    expect(database.movedToId, 2);
    expect(database.prependedNote, '历史分类');
    expect(find.text('购物'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
