import 'package:bookkeeping_app/database/database.dart';
import 'package:bookkeeping_app/pages/add_transaction_page.dart';
import 'package:bookkeeping_app/pages/home_page.dart';
import 'package:bookkeeping_app/services/settings_service.dart';
import 'package:bookkeeping_app/services/translations.dart';
import 'package:bookkeeping_app/widgets/transaction_locator_list.dart';
import 'package:bookkeeping_app/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _Settings extends SettingsService {
  bool _showLedgerFixedDecimals = false;

  @override
  Future<void> init() async {}
  @override
  String get appName => '';
  @override
  String? get backgroundImagePath => null;
  @override
  List<Map<String, String>> get apiConfigList => [];
  @override
  String get themeMode => 'light';
  @override
  String get language => 'zh';
  @override
  bool get showLedgerFixedDecimals => _showLedgerFixedDecimals;
  @override
  set showLedgerFixedDecimals(bool value) => _showLedgerFixedDecimals = value;
  @override
  String get defaultUnit => '个';
  @override
  double? get defaultQuantity => null;
  @override
  List<String> get units => ['个'];
  @override
  double stepIntervalForUnit(String unit) => 1;
  @override
  Set<int> get collapsedCategoryIds => {};
}

class _Database extends AppDatabase {
  final records = List.generate(90, (i) {
    final date = DateTime(2024, 2, 28 - i ~/ 4);
    final income = i.isOdd;
    return TransactionWithCategory(
      ExpenseRecord(id: i + 1, amount: income ? 12 : -12, categoryId: income ? 2 : 1,
        note: '定位记录$i\n多行备注', timestamp: date.millisecondsSinceEpoch ~/ 1000,
        createdAt: 0, updatedAt: 0),
      Category(id: income ? 2 : 1, name: income ? '其他收入' : '其他支出', type: income ? 'income' : 'expense'),
    );
  });

  @override
  Future<List<TransactionWithCategory>> transactionsInMonth(DateTime month) async =>
      month.year == 2024 && month.month == 2 ? records : [];
  @override
  Future<Map<String, double>> monthlySummary(DateTime month) async => {};
  @override
  Future<List<TransactionWithCategory>> searchTransactions(String keyword, {
    Set<String>? searchFields, DateTime? startDate, DateTime? endDate, String? type,
  }) async => records.where((r) => r.transaction.note!.contains(keyword)).toList();
}

class _CurrentMonthDatabase extends _Database {
  @override
  Future<List<TransactionWithCategory>> transactionsInMonth(DateTime month) async {
    final now = DateTime.now();
    return month.year == now.year && month.month == now.month
        ? records.take(3).toList()
        : [];
  }
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('zh', 'CN'),
  supportedLocales: const [Locale('zh', 'CN')],
  localizationsDelegates: const [
    AppTranslationsDelegate(), GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

double _highlightAlpha(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(find.descendant(
    of: find.byType(TransactionHighlight), matching: find.byType(DecoratedBox)).first);
  return (box.decoration as BoxDecoration).color!.a;
}

void main() {
  setUpAll(() async => initializeDateFormatting('zh_CN'));

  testWidgets('invert this month toggles every current-month selection', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(HomePage(
      db: _CurrentMonthDatabase(),
      settings: _Settings(),
      onThemeChanged: () {},
    )));
    await tester.pumpAndSettle();

    final firstTile = find.byWidgetPredicate(
      (widget) => widget is TransactionTile && widget.id == 1,
    );
    expect(tester.widget<TransactionTile>(firstTile).compactLayout, isTrue);
    final firstCircle = find.descendant(
      of: firstTile,
      matching: find.byType(CircleAvatar),
    );
    expect(tester.widget<CircleAvatar>(firstCircle).radius, 17);
    expect(tester.getSize(firstCircle).width, 34);
    expect(
      tester.widget<Text>(find.descendant(
        of: firstTile,
        matching: find.text('-¥12'),
      )).style!.fontSize,
      13.6,
    );
    final dailySummary = find.byWidgetPredicate((widget) =>
      widget.key is ValueKey<String> &&
      (widget.key as ValueKey<String>).value.startsWith('daily-summary-'));
    expect(tester.getSize(dailySummary.first).height, closeTo(47.04, 0.1));

    await tester.tap(find.byIcon(Icons.delete_outline).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('当前已选择0条支出明细'), findsOneWidget);
    expect(find.text('当前已选择0条收入明细'), findsOneWidget);
    final noticeFinder = find.byKey(
      const ValueKey('selection-count-notice'),
    );
    final notice = tester.widget<Container>(noticeFinder);
    expect(
      (notice.decoration! as BoxDecoration).color,
      Colors.orange.withAlpha(153),
    );
    expect(
      tester.widget<Text>(find.text('当前已选择0条支出明细')).style!.color,
      Colors.white,
    );
    expect(
      tester.widget<Text>(find.text('当前已选择0条支出明细')).style!.fontSize,
      18,
    );
    expect(
      tester.widget<Text>(find.text('当前已选择0条支出明细')).style!.decoration,
      TextDecoration.none,
    );
    final noticeCenter = tester.getCenter(noticeFinder);
    expect(noticeCenter.dx, closeTo(215, 0.1));
    expect(noticeCenter.dy, closeTo(425, 0.1));
    final textWidth = tester.getSize(
      find.byKey(const ValueKey('selection-count-text')),
    ).width;
    final noticeWidth = tester.getSize(noticeFinder).width;
    expect(noticeWidth - textWidth, closeTo(24, 0.1));
    await tester.pump(const Duration(minutes: 10));
    expect(find.text('当前已选择0条支出明细'), findsOneWidget);
    expect(find.text('当前已选择0条收入明细'), findsOneWidget);
    Finder transaction(int id) => find.byWidgetPredicate(
      (widget) => widget is TransactionTile && widget.id == id,
    );
    await tester.tap(transaction(1).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('当前已选择1条支出明细'), findsOneWidget);
    expect(find.text('当前已选择0条收入明细'), findsOneWidget);
    expect(tester.widget<TransactionTile>(transaction(1)).isSelected, isTrue);
    expect(tester.widget<TransactionTile>(transaction(2)).isSelected, isFalse);
    expect(tester.widget<TransactionTile>(transaction(3)).isSelected, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('monthly-selection-menu')).hitTestable(),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('反选本月'));
    await tester.pumpAndSettle();

    expect(tester.widget<TransactionTile>(transaction(1)).isSelected, isFalse);
    expect(tester.widget<TransactionTile>(transaction(2)).isSelected, isTrue);
    expect(tester.widget<TransactionTile>(transaction(3)).isSelected, isTrue);
    expect(find.text('当前已选择1条支出明细'), findsOneWidget);
    expect(find.text('当前已选择1条收入明细'), findsOneWidget);
    await tester.tap(find.text('取消').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selection-count-notice')), findsNothing);

    await tester.tap(find.byIcon(Icons.delete_outline).hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selection-count-notice')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('income-floating-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AddTransactionPage), findsOneWidget);
    expect(find.byKey(const ValueKey('selection-count-notice')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('return to current month button navigates back from another month', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(HomePage(db: _Database(), settings: _Settings(), onThemeChanged: () {})));
    await tester.pumpAndSettle();

    Finder visibleButton() => find.ancestor(
      of: find.text('回到本月').hitTestable(),
      matching: find.byType(TextButton),
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('monthly-summary-row')),
        matching: find.text('回到本月'),
      ),
      findsWidgets,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('monthly-summary-row')).first).height,
      32,
    );
    expect(
      tester.getCenter(find.text('回到本月').hitTestable()).dx,
      greaterThan(tester.getCenter(find.textContaining('收入:').hitTestable()).dx),
    );
    expect(tester.widget<TextButton>(visibleButton()).onPressed, isNull);

    await tester.tap(find.byIcon(Icons.chevron_left).hitTestable());
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(visibleButton()).onPressed, isNotNull);

    await tester.tap(find.text('回到本月').hitTestable());
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(visibleButton()).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('search jumps across months to a distant record and can repeat', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(HomePage(db: _Database(), settings: _Settings(), onThemeChanged: () {})));
    await tester.pumpAndSettle();

    for (final index in [88, 89, 88]) {
      await tester.tap(find.text('搜索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '定位记录$index');
      await tester.pumpAndSettle();
      expect(find.text('点击跳转可跳转到流水中具体条目；点击其他部位可以进入编辑界面'), findsWidgets);
      await tester.tap(find.byKey(ValueKey('jump-transaction-${index + 1}')));
      await tester.pumpAndSettle();

      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 0);
      final target = find.descendant(of: find.byType(TransactionHighlight), matching: find.byType(TransactionTile));
      expect(target, findsWidgets);
      expect(tester.widget<TransactionTile>(target).id, index + 1);
      expect(target.hitTestable(), findsWidgets);
      expect(_highlightAlpha(tester), greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(_highlightAlpha(tester), 0);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('highlight holds two seconds then fades, and a repeat restarts it', (tester) async {
    final key = GlobalKey<TransactionHighlightState>();
    await tester.pumpWidget(_app(Scaffold(body: TransactionHighlight(
      key: key, color: Colors.red, child: const SizedBox(height: 60, width: 300),
    ))));
    await tester.pumpAndSettle();
    key.currentState!.flash();
    await tester.pump();
    final full = _highlightAlpha(tester);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(_highlightAlpha(tester), full);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_highlightAlpha(tester), allOf(greaterThan(0), lessThan(full)));
    key.currentState!.flash();
    await tester.pump();
    expect(_highlightAlpha(tester), full);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 800));
    expect(_highlightAlpha(tester), 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('center button has income/expense colors and does not trigger editing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final income in [false, true]) {
      var jumps = 0;
      var edits = 0;
      final color = income ? Colors.green : Colors.red;
      await tester.pumpWidget(_app(Scaffold(body: TransactionTile(
        id: 1, amount: income ? 12 : -12, categoryName: '测试分类', note: '备注',
        timestamp: 0, categoryType: income ? 'income' : 'expense',
        onTap: () => edits++, onJump: () => jumps++,
      ))));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('jump-transaction-1'));
      final style = tester.widget<TextButton>(button).style!;
      expect(style.backgroundColor!.resolve({}), color.shade50);
      expect(style.foregroundColor!.resolve({}), color.shade800);
      expect(tester.getCenter(button).dx, 180);
      await tester.tap(button);
      expect(jumps, 1);
      expect(edits, 0);
      await tester.tap(find.text('备注'));
      expect(edits, 1);
      expect(jumps, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('transaction amount can use compact formatting in the ledger', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: Column(children: [
      TransactionTile(id: 1, amount: -12, categoryName: '餐饮', note: '',
        timestamp: 0, categoryType: 'expense', compactAmount: true),
      TransactionTile(id: 2, amount: 12.5, categoryName: '工资收入', note: '',
        timestamp: 0, categoryType: 'income', compactAmount: true),
      TransactionTile(id: 3, amount: -12.34, categoryName: '购物', note: '',
        timestamp: 0, categoryType: 'expense', compactAmount: true),
      TransactionTile(id: 4, amount: 3, categoryName: '工资收入', note: '',
        timestamp: 0, categoryType: 'income', compactAmount: true,
        showFixedDecimals: true),
      TransactionTile(id: 5, amount: 3.9, categoryName: '工资收入', note: '',
        timestamp: 0, categoryType: 'income', compactAmount: true,
        showFixedDecimals: true),
    ]))));
    await tester.pumpAndSettle();

    expect(find.text('-¥12'), findsOneWidget);
    expect(find.text('+¥12.5'), findsOneWidget);
    expect(find.text('-¥12.34'), findsOneWidget);
    expect(find.text('+¥3.00'), findsOneWidget);
    expect(find.text('+¥3.90'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings switch controls ledger integer decimals', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final settings = _Settings();
    await tester.pumpWidget(_app(HomePage(
      db: _Database(), settings: settings, onThemeChanged: () {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();
    final switchFinder = find.byKey(
      const ValueKey('show-ledger-integer-decimals-switch'),
    );
    expect(switchFinder, findsOneWidget);
    expect(
      tester.getTopLeft(find.text('API 配置')).dy,
      lessThan(tester.getTopLeft(switchFinder).dy),
    );
    expect(
      tester.getTopLeft(switchFinder).dy,
      lessThan(tester.getTopLeft(find.text('背景图')).dy),
    );
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(settings.showLedgerFixedDecimals, isTrue);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    expect(tester.takeException(), isNull);
  });
}
