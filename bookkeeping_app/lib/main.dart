/// 应用入口 — 初始化数据库和设置服务，创建 MaterialApp。
///
/// 启动流程：
/// 1. main() 注册全局错误处理器
/// 2. _BookkeepingAppState.initState() → _initAsync()
/// 3. _initAsync() 并行初始化：中文日期格式、AppDatabase、SettingsService
/// 4. 初始化完成后显示 HomePage，否则显示 teal 色启动加载页
///
/// MaterialApp 配置：
/// - 主题：teal 配色，Material3，支持浅色/深色切换
/// - 语言：支持 zh_CN 和 en_US，通过 SettingsService.language 控制
/// - 本地化：AppTranslations（自定义）+ Flutter 内置 Material/Cupertino 本地化

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'database/database.dart';
import 'services/settings_service.dart';
import 'services/translations.dart';
import 'pages/home_page.dart';

/// 应用入口。先初始化 Flutter 绑定，注册全局错误处理器，然后启动 BookkeepingApp。
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 捕获 Flutter 框架层未处理的错误
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter错误: ${details.exception}\n${details.stack}');
  };
  // 捕获平台层（引擎）未处理的错误
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('平台错误: $error\n$stack');
    return true;  // 已处理，不崩溃
  };
  runApp(const BookkeepingApp());
}

class BookkeepingApp extends StatefulWidget {
  const BookkeepingApp({super.key});
  @override State<BookkeepingApp> createState() => _BookkeepingAppState();
}

class _BookkeepingAppState extends State<BookkeepingApp> {
  AppDatabase? _db;              // 数据库实例（懒加载）
  SettingsService? _settings;    // 设置服务实例
  bool _ready = false;           // 初始化是否完成

  @override
  void initState() {
    super.initState();
    _initAsync();  // 异步初始化
  }

  /// 异步初始化：加载中文日期格式、创建数据库、创建设置服务
  Future<void> _initAsync() async {
    await initializeDateFormatting('zh_CN');  // 预加载中文日期格式化数据
    final db = AppDatabase();
    final settings = SettingsService();
    await settings.init();
    setState(() { _db = db; _settings = settings; _ready = true; });
  }

  /// 构建主题：teal 配色 + Material3
  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(colorSchemeSeed: Colors.teal, brightness: brightness, useMaterial3: true);
  }

  /// 主题或语言变更时重建整个 app（setState 触发 MaterialApp rebuild）
  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // 根据设置选择主题模式
    final themeMode = _settings == null
        ? ThemeMode.system
        : _settings!.themeMode == 'dark'
            ? ThemeMode.dark
            : _settings!.themeMode == 'light'
                ? ThemeMode.light
                : ThemeMode.system;

    return MaterialApp(
      title: _settings != null && _settings!.appName.isNotEmpty ? _settings!.appName : '极速记账',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: themeMode,
      // 根据设置的语言强制指定 locale（不由系统自动跟随）
      locale: _settings == null ? const Locale('zh') : Locale(_settings!.language),
      localizationsDelegates: const [
        AppTranslationsDelegate(),             // 自定义中英文翻译
        GlobalMaterialLocalizations.delegate,   // Material 组件本地化（日期选择器等）
        GlobalWidgetsLocalizations.delegate,    // widget 本地化（如文本方向）
        GlobalCupertinoLocalizations.delegate,  // Cupertino 组件本地化
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      // 初始化完成前显示 teal 色加载页
      home: _ready
        ? HomePage(db: _db!, settings: _settings!, onThemeChanged: _onThemeChanged, appName: _settings!.appName)
        : const Scaffold(
            backgroundColor: Color(0xFF009688),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
    );
  }
}
