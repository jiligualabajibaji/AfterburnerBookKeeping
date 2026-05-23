import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
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
  static const int maxIcons = 10;
  static const int maxApiConfigs = 10;

  late SharedPreferences _prefs;
  late String _iconsDir;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    _iconsDir = '${dir.path}/custom_icons';
    await Directory(_iconsDir).create(recursive: true);
  }

  String get themeMode => _prefs.getString(_themeMode) ?? 'system';
  set themeMode(String v) => _prefs.setString(_themeMode, v);

  String get fontSize => _prefs.getString(_fontSize) ?? 'medium';
  set fontSize(String v) => _prefs.setString(_fontSize, v);

  String get apiKey => _prefs.getString(_apiKey) ?? '';
  set apiKey(String v) => _prefs.setString(_apiKey, v);

  String get apiEndpoint => _prefs.getString(_apiEndpoint) ?? 'https://api.deepseek.com';
  set apiEndpoint(String v) => _prefs.setString(_apiEndpoint, v);

  String get apiModel => _prefs.getString(_apiModel) ?? '';
  set apiModel(String v) => _prefs.setString(_apiModel, v);

  String get appName => _prefs.getString(_appName) ?? '';
  set appName(String v) {
    if (v.length <= 30) _prefs.setString(_appName, v);
  }

  // API configs management
  List<Map<String, String>> get apiConfigList {
    final raw = _prefs.getString(_apiConfigs);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map((m) =>
        m.map((k, v) => MapEntry(k, v as String))).toList();
  }

  Future<void> saveCurrentApiConfig(String name) async {
    final config = {
      'name': name,
      'key': apiKey,
      'endpoint': apiEndpoint,
      'model': apiModel,
    };
    var list = apiConfigList;
    // Remove existing config with same name
    list.removeWhere((c) => c['name'] == name);
    list.insert(0, config);
    while (list.length > maxApiConfigs) list.removeLast();
    await _prefs.setString(_apiConfigs, jsonEncode(list));
  }

  Future<void> loadApiConfig(Map<String, String> config) async {
    apiKey = config['key'] ?? '';
    apiEndpoint = config['endpoint'] ?? '';
    apiModel = config['model'] ?? '';
  }

  Future<void> deleteApiConfig(String name) async {
    final list = apiConfigList;
    list.removeWhere((c) => c['name'] == name);
    await _prefs.setString(_apiConfigs, jsonEncode(list));
  }

  String? get backgroundImagePath {
    final name = _prefs.getString(_bgImage);
    if (name == null) return null;
    final path = '$_iconsDir/$name';
    if (File(path).existsSync()) return path;
    return null;
  }

  Future<void> setBackgroundImage(String sourcePath) async {
    final name = 'bg_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = '$_iconsDir/$name';
    await File(sourcePath).copy(dest);
    await _prefs.setString(_bgImage, name);
  }

  Future<void> removeBackgroundImage() async {
    final name = _prefs.getString(_bgImage);
    if (name != null) {
      final file = File('$_iconsDir/$name');
      if (file.existsSync()) await file.delete();
    }
    await _prefs.remove(_bgImage);
  }

  /// List of saved icon file paths, most recent first
  List<String> get iconList {
    final raw = _prefs.getString(_iconList);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  String? get currentIconPath {
    final name = _prefs.getString(_currentIcon);
    if (name == null) return null;
    final path = '$_iconsDir/$name';
    if (File(path).existsSync()) return path;
    return null;
  }

  Future<String> saveIcon(String sourcePath) async {
    final name = 'icon_${DateTime.now().millisecondsSinceEpoch}.png';
    final dest = '$_iconsDir/$name';
    await File(sourcePath).copy(dest);

    // Update list, newest first, max 10
    final list = iconList;
    list.insert(0, dest);
    while (list.length > maxIcons) {
      final old = list.removeLast();
      await File(old).delete();
    }
    await _prefs.setString(_iconList, jsonEncode(list));

    // Auto-select as current
    await _prefs.setString(_currentIcon, name);
    return dest;
  }

  Future<void> selectIcon(String filePath) async {
    final name = filePath.split('/').last;
    await _prefs.setString(_currentIcon, name);
  }

  Future<void> deleteIcon(String filePath) async {
    await File(filePath).delete();
    final list = iconList;
    list.remove(filePath);
    await _prefs.setString(_iconList, jsonEncode(list));
  }
}
