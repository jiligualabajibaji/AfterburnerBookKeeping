import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../database/database.dart';
import '../services/ai_bridge.dart';
import '../services/settings_service.dart';
import '../services/translations.dart';
import '../widgets/confirm_dialog.dart';

/// AI 记账页面 — 用自然语言描述交易，支持规则引擎和 LLM 双模式解析。
class AiInputPage extends StatefulWidget {
  final AppDatabase db;
  final VoidCallback? onRequestSettings;  // 点击"去设置"时回调，让主页跳转到设置页
  const AiInputPage({super.key, required this.db, this.onRequestSettings});
  @override State<AiInputPage> createState() => _AiInputPageState();
}

class _AiInputPageState extends State<AiInputPage> {
  final _textCtrl = TextEditingController();  // 自然语言输入框
  final _settings = SettingsService();         // 读取 API 配置
  AiParseResult? _result;     // 解析结果
  bool _loading = false;      // 是否正在解析
  String _lastMode = '';      // 上次使用的解析模式（'rule' 或 'ai'）
  DateTime _lastSnackTime = DateTime(2000);
  http.Client? _activeClient;  // 保存 HTTP 客户端引用，用于取消请求

  /// 取消正在进行的 LLM 请求
  void _cancelRequest() {
    _activeClient?.close();
    _activeClient = null;
    if (mounted) setState(() { _loading = false; _result = null; });
  }

  @override void initState() {
    super.initState();
    _settings.init();
  }

  /// 在屏幕顶部显示提示消息
  void _showTopSnack(String msg, {bool isError = true}) {
    _lastSnackTime = DateTime.now();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (ctx) => Positioned(
      top: MediaQuery.of(ctx).padding.top + 10, left: 0, right: 0,
      child: Center(
        child: Material(
          elevation: 6, borderRadius: BorderRadius.circular(12),
          color: isError ? Colors.deepOrange : Colors.green.shade600,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            child: Text(msg, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      ),
    ));
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () { entry.remove(); });
  }

  /// 规则引擎解析 — 基于正则和关键词匹配
  Future<void> _parseRule() async {
    if (_textCtrl.text.trim().isEmpty) { _showTopSnack('请先输入记账内容'); return; }
    setState(() { _loading = true; _result = null; _lastMode = 'rule'; });
    final r = await AiBridgeService.parseRule(_textCtrl.text.trim());
    if (!r.isComplete) { _showTopSnack('无法解析'); setState(() { _loading = false; }); return; }
    setState(() { _result = r; _loading = false; });
  }

  /// LLM 大模型解析 — 调用 OpenAI 兼容 API
  Future<void> _parseAi() async {
    if (_textCtrl.text.trim().isEmpty) { _showTopSnack('请先输入记账内容'); return; }
    // 检查 API 是否已配置
    if (_settings.apiKey.isEmpty) {
      final at = AppTranslations.of(context);
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(at.tr('ai.no_api_title')),
          content: Text(at.tr('ai.no_api_body')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(at.tr('ai.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(at.tr('ai.no_api_go'))),
          ],
        ),
      );
      if (go == true && mounted) {
        widget.onRequestSettings?.call();  // 通知主页跳转到设置页
        Navigator.pop(context);
      }
      return;
    }
    setState(() { _loading = true; _result = null; _lastMode = 'ai'; });
    final r = await AiBridgeService.parseWithAi(
      _textCtrl.text.trim(),
      apiKey: _settings.apiKey,
      endpoint: _settings.apiEndpoint,
      model: _settings.apiModel,
    );
    // 错误处理
    if (r.error == 'network') { _showTopSnack('需要接入网络'); setState(() { _loading = false; }); return; }
    if (r.error != null && r.error!.startsWith('api:')) {
      final msg = r.error!.substring(4);
      _showTopSnack('API 错误: $msg'); setState(() { _loading = false; }); return;
    }
    if (r.error == 'api') { _showTopSnack('API配置不正确'); setState(() { _loading = false; }); return; }
    if (!r.isComplete) { _showTopSnack('无法解析'); setState(() { _loading = false; }); return; }
    setState(() { _result = r; _loading = false; });
  }

  /// 确认保存解析结果到数据库
  Future<void> _confirm(Map<String, dynamic> data) async {
    try {
      final cats = await widget.db.allCategories();
      final cat = cats.firstWhere(
        (c) => c.name == data['category'],
        orElse: () { throw Exception('未找到分类: ${data['category']}'); });
      final ts = _parseTimestamp(data['timestamp'] as String? ?? '');
      final rawAmount = data['amount'];
      var amount = 0.0;
      if (rawAmount is String) amount = double.tryParse(rawAmount) ?? 0;
      else if (rawAmount is num) amount = rawAmount.toDouble();
      else amount = 0;
      amount = double.parse(amount.toStringAsFixed(2));
      // 根据类别类型自动转换金额正负
      if (cat.type == 'expense' && amount > 0) amount = -amount;
      if (cat.type == 'income' && amount < 0) amount = -amount;
      if (cat.id == null) { throw Exception('分类ID为空'); }
      final id = await widget.db.addTransaction(
        amount: amount,
        categoryId: cat.id!,
        note: data['note'] as String? ?? '',
        timestamp: ts,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存 (id=$id)'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
    }
  }

  /// 解析时间戳字符串，失败时返回当前时间
  int _parseTimestamp(String ts) {
    if (ts.isEmpty) return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try { return DateTime.parse(ts).millisecondsSinceEpoch ~/ 1000; }
    catch (_) { return DateTime.now().millisecondsSinceEpoch ~/ 1000; }
  }

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tr('ai.title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // 自然语言输入框
          TextField(
            controller: _textCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: t.tr('ai.hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 规则解析按钮（适合简单句子）
          SizedBox(
            width: double.infinity,
            child: _loading && _lastMode == 'rule'
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(t.tr('ai.rule_parse')),
                  onPressed: _loading ? null : _parseRule,
                ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(t.tr('ai.rule_desc'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 12),

          // 大模型解析按钮（支持取消）
          SizedBox(
            width: double.infinity,
            child: _loading && _lastMode == 'ai'
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                    label: Text(t.tr('ai.cancel'), style: const TextStyle(color: Colors.red, fontSize: 13)),
                    onPressed: _cancelRequest,
                  ),
                ])
              : OutlinedButton.icon(
                  icon: const Icon(Icons.psychology),
                  label: Text(t.tr('ai.llm_parse')),
                  onPressed: _loading ? null : _parseAi,
                ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(t.tr('ai.llm_desc'),
              style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(t.tr('ai.llm_warning'),
              style: TextStyle(color: Colors.orange.shade700, fontSize: 11), textAlign: TextAlign.center),
          ),
          // "前往设置配置API" 按钮（从主页进入时显示）
          if (widget.onRequestSettings != null)
            TextButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: Text(t.tr('ai.go_settings'), style: const TextStyle(fontSize: 13)),
              onPressed: () {
                widget.onRequestSettings?.call();
                Navigator.pop(context);
              },
            ),

          const SizedBox(height: 20),
          // 显示解析结果
          if (_result != null)
            !_result!.isComplete
              ? ConfirmDialog(result: _result!, onConfirm: _confirm)
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Text('${t.tr('ai.amount')}: ¥${_result!.amount!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
                      Text('${t.tr('ai.category')}: ${_result!.category}'),
                      Text('${t.tr('ai.date')}: ${_result!.timestamp.isEmpty ? DateTime.now().toString().split(' ')[0] : _result!.timestamp}'),
                      Text('${t.tr('ai.note')}: ${_result!.note}'),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        FilledButton(onPressed: () => _confirm(_result!.toJson()), child: Text(t.tr('ai.confirm_save'))),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => ConfirmDialog(result: _result!, onConfirm: _confirm),
                          ),
                          child: Text(t.tr('ai.edit'))),
                      ]),
                    ]),
                  ),
                ),
        ]),
      ),
    );
  }
}
