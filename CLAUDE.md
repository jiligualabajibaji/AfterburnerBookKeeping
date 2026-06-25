# BookkeepingAgent — Flutter 记账 App

## Tech Stack
Flutter + sqflite（本地 SQLite，全离线），SharedPreferences（设置存储）

## Key Facts
- 数据库：`categories` 和 `transactions` 两张表，关联查询
- 金额：支出存负数（如 `-35.50`），收入存正数
- 版本：`pubspec.yaml` 里改，build 号需递增
- 测试：`integration_test/app_test.dart`，跑 `flutter test integration_test/ -d <device>`
- APK：`flutter build apk --release --split-per-abi`，手机装 `*-arm64-v8a-*`
- 需求清单：`docs/requirements-list.md`

## Conventions
- `findsOneWidget` 在集成测试中慎用（PageView 预加载 + IndexedStack 会有多个副本），优先用 `findsWidgets`
- 新增分类名翻译：在 `translations.dart` 的 `_categoryNames` map 中添加
- `ensureVisible` + `pumpAndSettle` + `tap` 三部曲用于滚动后点击
