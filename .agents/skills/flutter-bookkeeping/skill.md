---
name: flutter-bookkeeping
description: BookkeepingAgent Flutter 项目开发流程 — 构建、测试、APK 发布
---

# BookkeepingAgent 开发指南

## 项目结构
- `bookkeeping_app/lib/` — Flutter 源码
- `bookkeeping_app/integration_test/` — 集成测试
- `docs/requirements-list.md` — 完整需求清单（180+ 条）
- `build/app/outputs/flutter-apk/` — APK 输出目录

## 常用命令

```bash
# 运行集成测试（模拟器）
flutter test integration_test/ -d emulator-5554

# 构建 release APK（拆分架构，减小体积）
flutter build apk --release --split-per-abi

# 安装到真机
adb -s f966ea2c install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# 代码分析
flutter analyze

# 更新依赖
flutter pub get
```

## 版本管理
- 版本号在 `pubspec.yaml`：`version: x.y.z+build`
- `build` 版本码需要递增（Android 要求）
- 新功能合入后同步更新 `docs/requirements-list.md`

## 开发规范
- 数据库迁移用 `onUpgrade` 回调，不手动改表
- 金额用正负号区分收支（支出负、收入正）
- 中英文翻译统一放在 `translations.dart` 的 `_strings` map 中
- 内置分类名（其他支出/其他收入）翻译用 `trCategory()` 方法
- 集成测试用 `findsWidgets` 而非 `findsOneWidget`（PageView 预加载）
