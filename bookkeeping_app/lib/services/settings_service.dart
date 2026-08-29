/// 设置持久化服务 — 通过 SharedPreferences 存取所有用户配置。
/// 包括：主题、字体大小、语言、API 配置（含多预设）、背景图、软件名称、自定义图标。

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // SharedPreferences 键名常量
  static const _themeMode = 'theme_mode';
  static const _fontSize = 'font_size';
  static const _apiKey = 'ai_api_key';
  static const _apiEndpoint = 'ai_api_endpoint';
  static const _apiModel = 'ai_api_model';
  static const _appName = 'app_name';
  static const _apiConfigs = 'api_configs';
  static const _bgImage = 'background_image';
  static const _iconList = 'icon_list';
  static const _currentIcon = 'current_icon';
  static const _language = 'language';
  static const _stepInterval = 'step_interval';      // 数量增减步长
  static const _defaultUnit = 'default_unit';         // 默认单位
  static const _defaultQuantity = 'default_quantity'; // 默认数量
  static const _units = 'units_list';                 // 单位列表（有序）
  static const int maxIcons = 10;        // 最多保留 10 个自定义图标
  static const int maxApiConfigs = 10;   // 最多保留 10 个 API 配置预设

  late SharedPreferences _prefs;
  late String _iconsDir;  // 自定义图标和背景图的存储目录

  /// 初始化：加载 SharedPreferences + 创建图标目录
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    _iconsDir = '${dir.path}/custom_icons';
    await Directory(_iconsDir).create(recursive: true);
  }

  // ── 主题 ──
  String get themeMode => _prefs.getString(_themeMode) ?? 'system';
  set themeMode(String v) => _prefs.setString(_themeMode, v);

  // ── 字号（存储但当前未在 UI 中使用） ──
  String get fontSize => _prefs.getString(_fontSize) ?? 'medium';
  set fontSize(String v) => _prefs.setString(_fontSize, v);

  // ── 语言 ──
  String get language => _prefs.getString(_language) ?? 'zh';
  set language(String v) => _prefs.setString(_language, v);

  // ── 数量控件设置 ──
  double get stepInterval => _prefs.getDouble(_stepInterval) ?? 1.0;
  set stepInterval(double v) => _prefs.setDouble(_stepInterval, v);

  String get defaultUnit => _prefs.getString(_defaultUnit) ?? '个';
  set defaultUnit(String v) => _prefs.setString(_defaultUnit, v);

  /// 单位列表（有序，默认第一个为默认单位）
  List<String> get units {
    final raw = _prefs.getString(_units);
    if (raw == null) return ['个', '件', '斤', '份', '次', '包'];
    final list = (jsonDecode(raw) as List).cast<String>();
    return list.isEmpty ? ['个'] : list;
  }
  set units(List<String> v) => _prefs.setString(_units, jsonEncode(v));

  double? get defaultQuantity {
    final v = _prefs.getDouble(_defaultQuantity);
    return (v == null || v <= 0) ? null : v;
  }
  set defaultQuantity(double? v) {
    if (v == null || v <= 0) _prefs.remove(_defaultQuantity);
    else _prefs.setDouble(_defaultQuantity, v);
  }

  // ── API 配置（当前使用的值） ──
  String get apiKey => _prefs.getString(_apiKey) ?? '';
  set apiKey(String v) => _prefs.setString(_apiKey, v);

  String get apiEndpoint => _prefs.getString(_apiEndpoint) ?? 'https://api.deepseek.com';
  set apiEndpoint(String v) => _prefs.setString(_apiEndpoint, v);

  String get apiModel => _prefs.getString(_apiModel) ?? '';
  set apiModel(String v) => _prefs.setString(_apiModel, v);

  // ── 软件名称 ──
  String get appName => _prefs.getString(_appName) ?? '';
  set appName(String v) {
    if (v.length <= 30) _prefs.setString(_appName, v);
  }

  // ── API 配置预设管理 ──
  /// 获取所有已保存的 API 配置预设列表
  List<Map<String, String>> get apiConfigList {
    final raw = _prefs.getString(_apiConfigs);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map((m) =>
        m.map((k, v) => MapEntry(k, v as String))).toList();
  }

  /// 将当前 API 配置保存为预设（同名覆盖）
  Future<void> saveCurrentApiConfig(String name) async {
    final config = {
      'name': name,
      'key': apiKey,
      'endpoint': apiEndpoint,
      'model': apiModel,
    };
    var list = apiConfigList;
    list.removeWhere((c) => c['name'] == name);
    list.insert(0, config);  // 新配置放在最前面
    while (list.length > maxApiConfigs) list.removeLast();
    await _prefs.setString(_apiConfigs, jsonEncode(list));
  }

  /// 将预设配置的值加载到当前 API 配置中
  Future<void> loadApiConfig(Map<String, String> config) async {
    apiKey = config['key'] ?? '';
    apiEndpoint = config['endpoint'] ?? '';
    apiModel = config['model'] ?? '';
  }

  /// 删除指定名称的 API 配置预设
  Future<void> deleteApiConfig(String name) async {
    final list = apiConfigList;
    list.removeWhere((c) => c['name'] == name);
    await _prefs.setString(_apiConfigs, jsonEncode(list));
  }

  // ── 背景图 ──
  /// 当前背景图路径，不存在则返回 null
  String? get backgroundImagePath {
    final name = _prefs.getString(_bgImage);
    if (name == null) return null;
    final path = '$_iconsDir/$name';
    if (File(path).existsSync()) return path;
    return null;
  }

  /// 设置背景图（将所选图片复制到应用目录）
  Future<void> setBackgroundImage(String sourcePath) async {
    final name = 'bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = '$_iconsDir/$name';
    await File(sourcePath).copy(dest);
    await _prefs.setString(_bgImage, name);
  }

  /// 移除背景图
  Future<void> removeBackgroundImage() async {
    final name = _prefs.getString(_bgImage);
    if (name != null) {
      final file = File('$_iconsDir/$name');
      if (file.existsSync()) await file.delete();
    }
    await _prefs.remove(_bgImage);
  }

  // ── 自定义图标（当前 UI 中未使用） ──
  /// 已保存的图标文件路径列表，最新在前
  List<String> get iconList {
    final raw = _prefs.getString(_iconList);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  /// 当前使用的图标路径
  String? get currentIconPath {
    final name = _prefs.getString(_currentIcon);
    if (name == null) return null;
    final path = '$_iconsDir/$name';
    if (File(path).existsSync()) return path;
    return null;
  }

  /// 保存新图标（复制图片到图标目录，自动清理超出上限的旧图标）
  Future<String> saveIcon(String sourcePath) async {
    final name = 'icon_${DateTime.now().millisecondsSinceEpoch}.png';
    final dest = '$_iconsDir/$name';
    await File(sourcePath).copy(dest);

    final list = iconList;
    list.insert(0, dest);
    while (list.length > maxIcons) {
      final old = list.removeLast();
      await File(old).delete();
    }
    await _prefs.setString(_iconList, jsonEncode(list));
    await _prefs.setString(_currentIcon, name);
    return dest;
  }

  /// 选中某个图标作为当前图标
  Future<void> selectIcon(String filePath) async {
    final name = filePath.split('/').last;
    await _prefs.setString(_currentIcon, name);
  }

  /// 删除指定图标
  Future<void> deleteIcon(String filePath) async {
    await File(filePath).delete();
    final list = iconList;
    list.remove(filePath);
    await _prefs.setString(_iconList, jsonEncode(list));
  }
}
