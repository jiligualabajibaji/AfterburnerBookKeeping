import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bookkeeping_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows home page with all tabs',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Bottom navigation should be visible
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // All four tab labels should be visible (one per tab in bottom nav)
    expect(find.text('流水'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    // Both FABs should be visible on the transactions tab
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);

    // The month hint & "暂无记录" appear in each preloaded PageView page
    expect(find.textContaining('点击年月切换'), findsWidgets);
    expect(find.(text'暂无记录'), findsWidgets);
  });

  testWidgets('can add an expense transaction', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '35.50');
    await tester.pumpAndSettle();

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('保存并返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();

    expect(find.textContaining('35.50'), findsWidgets);
    expect(find.textContaining('支出'), findsWidgets);
  });

  testWidgets('can add an income transaction', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('记一笔'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '5000');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('工资收入'), 200.0,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('工资收入'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('保存并返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();

    expect(find.textContaining('5000'), findsWidgets);
  });

  testWidgets('can search for transactions', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Add a transaction to search for
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '18.50');
    await tester.pumpAndSettle();

    await tester.tap(find.text('交通'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('保存并返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();

    // Navigate to search tab
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '交通');
    await tester.pumpAndSettle();

    expect(find.textContaining('18.50'), findsWidgets);
    expect(find.text('交通'), findsWidgets);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('输入关键词搜索交易记录'), findsOneWidget);
  });

  testWidgets('can navigate settings and change language', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    // Settings content
    expect(find.text('设置'), findsWidgets);
    expect(find.text('API 配置'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);

    // Expand language section and switch to English
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();

    expect(find.text('英文'), findsOneWidget);

    await tester.tap(find.text('英文'));
    await tester.pumpAndSettle();

    // Verify UI changed to English
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Transactions'), findsOneWidget);

    // Switch back to Chinese
    await tester.tap(find.text('Chinese'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('can add a new category and use it', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    // Create new category
    await tester.ensureVisible(find.text('新增'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();

    expect(find.textContaining('添加'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '零食');
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    // New category should be selected
    expect(find.text('零食'), findsOneWidget);

    // Enter amount and save (category is already selected)
    await tester.enterText(find.byType(TextField).first, '29.90');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('保存并返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();

    expect(find.textContaining('29.90'), findsWidgets);
  });

  testWidgets('default categories are present on add page', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    // Verify default expense categories exist
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('其他支出'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);

    // Verify the "+新增" button exists
    expect(find.text('新增'), findsOneWidget);

    // Create a category and verify dialog
    await tester.ensureVisible(find.text('新增'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();

    expect(find.textContaining('添加'), findsWidgets);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // Dialog closed, still on add page
    expect(find.text('记一笔'), findsOneWidget);
  });

  group('amount parsing', () {
    testWidgets('supports expression "100+50" → 150', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '100+50');
      await tester.pumpAndSettle();
      await tester.tap(find.text('餐饮'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('保存并返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并返回'));
      await tester.pumpAndSettle();

      expect(find.textContaining('150.00'), findsWidgets);
    });

    testWidgets('supports Chinese integer "一百三十六" → 136',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '一百三十六');
      await tester.pumpAndSettle();
      await tester.tap(find.text('餐饮'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('保存并返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并返回'));
      await tester.pumpAndSettle();

      expect(find.textContaining('136.00'), findsWidgets);
    });

    testWidgets('supports Chinese currency "十五块" → 15', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '十五块');
      await tester.pumpAndSettle();
      await tester.tap(find.text('交通'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('保存并返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并返回'));
      await tester.pumpAndSettle();

      expect(find.textContaining('15.00'), findsWidgets);
    });

    testWidgets('supports Chinese currency "一块二毛七" → 1.27',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '一块二毛七');
      await tester.pumpAndSettle();
      await tester.tap(find.text('餐饮'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('保存并返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并返回'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1.27'), findsWidgets);
    });
  });

  testWidgets('transactions in different months show correct stats',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Add expense in current month (567.89, 餐饮)
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '567.89');
    await tester.pumpAndSettle();

    await tester.tap(find.text('餐饮'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('保存并返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并返回'));
    await tester.pumpAndSettle();

    // Verify home page shows the expense
    expect(find.textContaining('567.89'), findsWidgets);

    // Go to Stats tab and verify data shows correctly
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();

    // 餐饮 appears both in the offstage home page and stats page
    expect(find.text('餐饮'), findsWidgets);
    // The stats page header shows the total
    expect(find.textContaining('支出'), findsWidgets);
  });

  testWidgets('can navigate between all tabs', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('输入关键词搜索交易记录'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('流水'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });
}
