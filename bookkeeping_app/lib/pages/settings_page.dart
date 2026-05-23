import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../database/database.dart';
import '../services/settings_service.dart';
import '../services/export_service.dart';

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
    // Always start with empty fields
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
    // Clear all fields after save
    _configNameCtrl.clear();
    _keyCtrl.clear();
    _endpointCtrl.clear();
    _modelCtrl.clear();
    setState(() {});
  }

  Future<void> _applyConfig(Map<String, String> cfg) async {
    // Apply config immediately to settings
    widget.settings.apiKey = cfg['key'] ?? '';
    widget.settings.apiEndpoint = cfg['endpoint'] ?? '';
    widget.settings.apiModel = cfg['model'] ?? '';
    // Don't fill form fields - keep them empty for new input
    widget.onThemeChanged();
    setState(() {});
  }

  Future<void> _editConfig(Map<String, String> cfg) async {
    // Load config values into form fields for editing
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

    return SafeArea(
      child: ListView(children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),

        // API 配置
        Container(
          color: _highlight ? Colors.amber.withAlpha(40) : null,
          child: ExpansionTile(
          initiallyExpanded: widget.apiExpanded,
          leading: const Icon(Icons.api),
          title: const Text('API 配置'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _keyCtrl,
                  decoration: const InputDecoration(labelText: 'API Key', hintText: '输入 API Key'),
                  onChanged: (v) => widget.settings.apiKey = v,
                ),
                const SizedBox(height: 4),
                const Text('例如 DeepSeek 的 API 格式: sk-...',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 8),
                TextField(
                  controller: _endpointCtrl,
                  decoration: const InputDecoration(labelText: '接口地址', hintText: 'https://api.deepseek.com'),
                  onChanged: (v) => widget.settings.apiEndpoint = v,
                ),
                const SizedBox(height: 4),
                const Text('DeepSeek 接口地址: https://api.deepseek.com/chat/completions',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 8),
                TextField(
                  controller: _modelCtrl,
                  decoration: const InputDecoration(labelText: '模型', hintText: 'deepseek-v4-flash'),
                  onChanged: (v) => widget.settings.apiModel = v,
                ),
                const SizedBox(height: 4),
                const Text('例如 deepseek-v4-flash 或 deepseek-v4-pro',
                  textAlign: TextAlign.left,
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 12),
                // Save button
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _configNameCtrl,
                      decoration: const InputDecoration(labelText: '配置名称', hintText: '例如: DeepSeek'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveConfig,
                    child: const Text('保存'),
                  ),
                ]),
                const SizedBox(height: 12),
                // Saved configs list
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
                          child: const Text('使用中', style: TextStyle(fontSize: 10, color: Colors.teal)),
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
                          tooltip: '应用',
                        ),
                      IconButton(
                        constraints: const BoxConstraints(maxWidth: 32),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () => _deleteConfig(cfg['name']!),
                        tooltip: '删除',
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

        // 背景图
        ExpansionTile(
          leading: const Icon(Icons.wallpaper),
          title: const Text('背景图'),
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
                    label: const Text('选择图片'),
                    onPressed: () async {
                      try {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          await widget.settings.setBackgroundImage(picked.path);
                          setState(() {});
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('选择失败: $e')));
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
                      child: const Text('移除', style: TextStyle(color: Colors.red)),
                    ),
                ]),
              ]),
            ),
          ],
        ),

        // 更改软件名称
        ExpansionTile(
          leading: const Icon(Icons.title),
          title: const Text('更改软件名称'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: '新名称（30字内）', hintText: '极速记账'),
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () { _nameCtrl.clear(); setState(() {}); },
                    child: const Text('清空'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final name = _nameCtrl.text.trim();
                      widget.settings.appName = name;
                      widget.onThemeChanged();
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(name.isEmpty ? '已恢复默认名称' : '名称已更改为: $name')),
                      );
                    },
                    child: const Text('保存'),
                  ),
                ]),
              ]),
            ),
          ],
        ),

        // 主题
        ExpansionTile(
          leading: const Icon(Icons.palette),
          title: const Text('主题'),
          children: [
            RadioListTile<String>(
              title: const Text('浅色'), value: 'light',
              groupValue: widget.settings.themeMode,
              onChanged: (v) { widget.settings.themeMode = v!; widget.onThemeChanged(); },
            ),
            RadioListTile<String>(
              title: const Text('深色'), value: 'dark',
              groupValue: widget.settings.themeMode,
              onChanged: (v) { widget.settings.themeMode = v!; widget.onThemeChanged(); },
            ),
            RadioListTile<String>(
              title: const Text('跟随系统'), value: 'system',
              groupValue: widget.settings.themeMode,
              onChanged: (v) { widget.settings.themeMode = v!; widget.onThemeChanged(); },
            ),
          ],
        ),

        // 数据管理
        ExpansionTile(
          leading: const Icon(Icons.backup),
          title: const Text('数据管理'),
          children: [
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('导出数据'),
              onTap: () async {
                await _export.exportToJson();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('导出成功')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导入数据'),
              onTap: () async {
                final r = await _export.importFromFile();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('导入完成: ${r['imported']} 条新记录, ${r['skipped']} 条跳过')));
                setState(() {});
              },
            ),
          ],
        ),

        // 教程
        ExpansionTile(
          leading: const Icon(Icons.help_outline),
          title: const Text('使用教程'),
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📱 基本操作', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('• 点击记录 → 编辑该条记录'),
                Text('• 左滑记录 → 删除'),
                Text('• 选择模式 → 点击顶部🗑→勾选记录→确认删除'),
                Text('• 全选：本月/本月支出/本月收入，也可按天勾选'),
                Text('• 点击日期后的 + → 添加当天记录'),
                Text('• 左右滑动页面 → 切换月份'),
                Text('• 点击年月文字 → 跳转到指定月份'),
                Text('• 切换标签页再回来 → 保留之前浏览的月份'),
                Text('• 点击日期右侧的日历图标 → 展开时间选择（精确到分钟）'),
                SizedBox(height: 12),
                Text('💰 记账', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('• 绿色 + → 记一笔收入'),
                Text('• 红色 - → 记一笔支出'),
                Text('• AI 图标 → 自然语言记账'),
                Text('• 右上角"再记一笔" → 连续记账'),
                Text('• 金额支持算式（如 100+50）'),
                Text('• 不填金额/填负数/非数字 → 顶部提示'),
                SizedBox(height: 12),
                Text('🗂️ 分类', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('• 记一笔时可直接选择/新增分类'),
                Text('• 删除分类后账单归入"其他支出"'),
                SizedBox(height: 12),
                Text('📊 统计', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('• 月/年切换查看'),
                Text('• 饼图展示分类占比'),
                Text('• 点击日期可弹出选择器'),
                SizedBox(height: 12),
                Text('🎨 主题', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('• 主题：浅色/深色/跟随系统'),
                Text('• 设置背景图：设置→背景图'),
                Text('• 更改软件名称：设置→更改软件名称'),
                SizedBox(height: 12),
                Text('💾 数据管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('• 导出全部数据为 JSON 文件'),
                Text('• 从 JSON 文件导入（自动去重）'),
                SizedBox(height: 12),
                Text('🤖 AI 记账', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('• 规则解析 → 适合简单句子（离线）'),
                Text('• 大模型解析 → 支持复杂句（需配 API）'),
                Text('• 支持汉字数字（如"三十八"）'),
                Text('• API 地址示例：DeepSeek / OpenAI 兼容'),
              ]),
            ),
          ],
        ),
      ]),
    );
  }
}
