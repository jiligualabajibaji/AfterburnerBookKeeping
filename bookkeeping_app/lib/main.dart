import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'database/database.dart';
import 'services/settings_service.dart';
import 'services/translations.dart';
import 'pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter错误: ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('平台错误: $error\n$stack');
    return true;
  };
  runApp(const BookkeepingApp());
}

class BookkeepingApp extends StatefulWidget {
  const BookkeepingApp({super.key});
  @override State<BookkeepingApp> createState() => _BookkeepingAppState();
}

class _BookkeepingAppState extends State<BookkeepingApp> {
  AppDatabase? _db;
  SettingsService? _settings;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await initializeDateFormatting('zh_CN');
    final db = AppDatabase();
    final settings = SettingsService();
    await settings.init();
    setState(() { _db = db; _settings = settings; _ready = true; });
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(colorSchemeSeed: Colors.teal, brightness: brightness, useMaterial3: true);
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
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
      locale: _settings == null ? const Locale('zh') : Locale(_settings!.language),
      localizationsDelegates: const [
        AppTranslationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: _ready
        ? HomePage(db: _db!, settings: _settings!, onThemeChanged: _onThemeChanged, appName: _settings!.appName)
        : const Scaffold(
            backgroundColor: Color(0xFF009688),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
    );
  }
}
