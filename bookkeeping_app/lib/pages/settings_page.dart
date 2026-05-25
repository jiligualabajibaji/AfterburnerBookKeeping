import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database.dart';
import '../services/settings_service.dart';
import '../services/export_service.dart';
import '../services/translations.dart';

class SettingsPage extends StatefulWidget {
  final AppDatabase db;
  final SettingsService settings;
  final VoidCallback onThemeChanged;
  final bool apiExpanded;
  const SettingsPage({super.key, required this.db, required this.settings, required this.onThemeChanged, this.apiExpanded = false});
  @override State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _keyCtrl = TextEditingController();
  final _endpointCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _configNameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  List<Map<String, String>> _savedConfigs = [];
  late ExportService _export;
  bool _highlight = false;

  @override
  void initState() {
    super.initState();
    _keyCtrl.clear();
    _endpointCtrl.clear();
    _modelCtrl.clear();
    _nameCtrl.text = widget.settings.appName;
    _savedConfigs = widget.settings.apiConfigList;
    _export = ExportService(widget.db);
    if (widget.apiExpanded) {
      _highlight = true;
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _highlight = false);
      });
    }
  }

  @override
  void dispose() { _keyCtrl.dispose(); _endpointCtrl.dispose(); _modelCtrl.dispose(); _configNameCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _saveConfig() async {
    final name = _configNameCtrl.text.trim();
    if (name.isEmpty) return;
    await widget.settings.saveCurrentApiConfig(name);
    _savedConfigs = widget.settings.apiConfigList;
    _configNameCtrl.clear();
    _keyCtrl.clear();
    _endpointCtrl.clear();
    _modelCtrl.clear();
    setState(() {});
  }

  Future<void> _applyConfig(Map<String, String> cfg) async {
    widget.settings.apiKey = cfg['key'] ?? '';
    widget.settings.apiEndpoint = cfg['endpoint'] ?? '';
    widget.settings.apiModel = cfg['model'] ?? '';
    widget.onThemeChanged();
    setState(() {});
  }

  Future<void> _editConfig(Map<String, String> cfg) async {
    _configNameCtrl.text = cfg['name'] ?? '';
    _keyCtrl.text = cfg['key'] ?? '';
    _endpointCtrl.text = cfg['endpoint'] ?? '';
    _modelCtrl.text = cfg['model'] ?? '';
    setState(() {});
  }

  bool _isActiveConfig(Map<String, String> cfg) {
    return cfg['key'] == widget.settings.apiKey
        && cfg['endpoint'] == widget.settings.apiEndpoint
        && cfg['model'] == widget.settings.apiModel;
  }

  Future<void> _deleteConfig(String name) async {
    await widget.settings.deleteApiConfig(name);
    _savedConfigs = widget.settings.apiConfigList;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);

    return SafeArea(
      child: ListView(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t.tr('settings.title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),

        // API Configuration
        Container(
          color: _highlight ? Colors.amber.withAlpha(40) : null,
          child: ExpansionTile(
          initiallyExpanded: widget.apiExpanded,
          leading: const Icon(Icons.api),
          title: Text(t.tr('settings.api_config')),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _keyCtrl,
                  decoration: InputDecoration(labelText: t.tr('settings.api_key'), hintText: t.tr('settings.api_key_hint')),
                  onChanged: (v) => widget.settings.apiKey = v,
                ),
                const SizedBox(height: 4),
                Text(t.tr('settings.api_key_example'),
                  textAlign: TextAlign.left,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 8),
                TextField(
                  controller: _endpointCtrl,
                  decoration: InputDecoration(labelText: t.tr('settings.endpoint'), hintText: t.tr('settings.endpoint_hint')),
                  onChanged: (v) => widget.settings.apiEndpoint = v,
                ),
                const SizedBox(height: 4),
                Text(t.tr('settings.endpoint_example'),
                  textAlign: TextAlign.left,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 8),
                TextField(
                  controller: _modelCtrl,
                  decoration: InputDecoration(labelText: t.tr('settings.model'), hintText: t.tr('settings.model_hint')),
                  onChanged: (v) => widget.settings.apiModel = v,
                ),
                const SizedBox(height: 4),
                Text(t.tr('settings.model_example'),
                  textAlign: TextAlign.left,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _configNameCtrl,
                      decoration: InputDecoration(labelText: t.tr('settings.config_name'), hintText: t.tr('settings.config_name_hint')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveConfig,
                    child: Text(t.tr('settings.save')),
                  ),
                ]),
                const SizedBox(height: 12),
                if (_savedConfigs.isNotEmpty)
                  ..._savedConfigs.map((cfg) {
                    final active = _isActiveConfig(cfg);
                    return ListTile(
                    dense: true,
                    leading: Icon(active ? Icons.cloud_done : Icons.cloud, size: 20,
                      color: active ? Colors.teal : null),
                    title: Row(children: [
                      Text(cfg['name'] ?? '', style: TextStyle(fontSize: 14,
                        color: active ? Colors.teal : null, fontWeight: active ? FontWeight.bold : null)),
                      if (active) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(t.tr('settings.in_use'), style: const TextStyle(fontSize: 10, color: Colors.teal)),
                        ),
                      ],
                    ]),
                    subtitle: Text('${cfg['model'] ?? ''}', style: const TextStyle(fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (!active)
                        IconButton(
                          constraints: const BoxConstraints(maxWidth: 32),
                          icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.teal),
                          onPressed: () => _applyConfig(cfg),
                          tooltip: t.tr('settings.apply'),
                        ),
                      IconButton(
                        constraints: const BoxConstraints(maxWidth: 32),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () => _deleteConfig(cfg['name']!),
                        tooltip: t.tr('settings.delete'),
                      ),
                    ]),
                    onTap: () => _editConfig(cfg),
                  );
                  }),
              ]),
            ),
          ],
        ),
        ),

        // Background
        ExpansionTile(
          leading: const Icon(Icons.wallpaper),
          title: Text(t.tr('settings.background')),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                () {
                  final bg = widget.settings.backgroundImagePath;
                  if (bg != null) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(bg), height: 100, width: double.infinity, fit: BoxFit.cover),
                    );
                  }
                  return const Icon(Icons.image_outlined, size: 60, color: Colors.grey);
                }(),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add_photo_alternate, size: 16),
                    label: Text(t.tr('settings.select_image')),
                    onPressed: () async {
                      try {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          await widget.settings.setBackgroundImage(picked.path);
                          setState(() {});
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  if (widget.settings.backgroundImagePath != null)
                    OutlinedButton(
                      onPressed: () async {
                        await widget.settings.removeBackgroundImage();
                        setState(() {});
                      },
                      child: Text(t.tr('settings.remove_image'), style: const TextStyle(color: Colors.red)),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(t.tr('settings.background_hint'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
          ],
        ),

        // App name
        ExpansionTile(
          leading: const Icon(Icons.title),
          title: Text(t.tr('settings.app_name')),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(labelText: t.tr('settings.app_name_label'), hintText: t.tr('settings.app_name_hint')),
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () { _nameCtrl.clear(); setState(() {}); },
                    child: Text(t.tr('settings.clear')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final name = _nameCtrl.text.trim();
                      widget.settings.appName = name;
                      widget.onThemeChanged();
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(name.isEmpty ? t.tr('settings.name_restored') : t.tr('settings.name_changed', {'name': name}))),
                      );
                    },
                    child: Text(t.tr('settings.save_name')),
                  ),
                ]),
              ]),
            ),
          ],
        ),

        // Theme
        ExpansionTile(
          leading: const Icon(Icons.palette),
          title: Text(t.tr('settings.theme')),
          children: [
            RadioListTile<String>(
              title: Text(t.tr('settings.theme_light')), value: 'light',
              groupValue: widget.settings.themeMode,
              onChanged: (v) { widget.settings.themeMode = v!; widget.onThemeChanged(); },
            ),
            RadioListTile<String>(
              title: Text(t.tr('settings.theme_dark')), value: 'dark',
              groupValue: widget.settings.themeMode,
              onChanged: (v) { widget.settings.themeMode = v!; widget.onThemeChanged(); },
            ),
            RadioListTile<String>(
              title: Text(t.tr('settings.theme_system')), value: 'system',
              groupValue: widget.settings.themeMode,
              onChanged: (v) { widget.settings.themeMode = v!; widget.onThemeChanged(); },
            ),
          ],
        ),

        // Language
        ExpansionTile(
          leading: const Icon(Icons.language),
          title: Text(t.tr('settings.language')),
          children: [
            RadioListTile<String>(
              title: Text(t.tr('settings.language_zh')), value: 'zh',
              groupValue: widget.settings.language,
              onChanged: (v) { widget.settings.language = v!; widget.onThemeChanged(); },
            ),
            RadioListTile<String>(
              title: Text(t.tr('settings.language_en')), value: 'en',
              groupValue: widget.settings.language,
              onChanged: (v) { widget.settings.language = v!; widget.onThemeChanged(); },
            ),
          ],
        ),

        // Data management
        ExpansionTile(
          leading: const Icon(Icons.backup),
          title: Text(t.tr('settings.data')),
          children: [
            ListTile(
              leading: const Icon(Icons.upload),
              title: Text(t.tr('settings.export')),
              onTap: () async {
                await _export.exportToJson();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.tr('settings.export_success'))));
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(t.tr('settings.import')),
              onTap: () async {
                final r = await _export.importFromFile();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.tr('settings.import_result', {'imported': '${r['imported']}', 'skipped': '${r['skipped']}'}))));
                setState(() {});
              },
            ),
          ],
        ),

      ]),
    );
  }
}
