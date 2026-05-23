import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../database/database.dart';
import '../database/models.dart';
import '../services/ai_bridge.dart';
import '../services/settings_service.dart';
import '../widgets/confirm_dialog.dart';

class AiInputPage extends StatefulWidget {
  final AppDatabase db;
  final VoidCallback? onRequestSettings;
  const AiInputPage({super.key, required this.db, this.onRequestSettings});
  @override State<AiInputPage> createState() => _AiInputPageState();
}

class _AiInputPageState extends State<AiInputPage> {
  final _textCtrl = TextEditingController();
  final _settings = SettingsService();
  AiParseResult? _result;
  bool _loading = false;
  String _lastMode = '';
  DateTime _lastSnackTime = DateTime(2000);
  http.Client? _activeClient;

  void _cancelRequest() {
    _activeClient?.close();
    _activeClient = null;
    if (mounted) setState(() { _loading = false; _result = null; });
  }

  @override void initState() {
    super.initState();
    _settings.init();
  }

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

  Future<void> _parseRule() async {
    if (_textCtrl.text.trim().isEmpty) { _showTopSnack('请先输入记账内容'); return; }
    setState(() { _loading = true; _result = null; _lastMode = 'rule'; });
    final r = await AiBridgeService.parseRule(_textCtrl.text.trim());
    if (!r.isComplete) { _showTopSnack('无法解析'); setState(() { _loading = false; }); return; }
    setState(() { _result = r; _loading = false; });
  }

  Future<void> _parseAi() async {
    if (_textCtrl.text.trim().isEmpty) { _showTopSnack('请先输入记账内容'); return; }
    if (_settings.apiKey.isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('未配置 API'),
          content: const Text('大模型解析需要在设置中填写 API Key 和接口地址。是否前往设置？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去设置')),
          ],
        ),
      );
      if (go == true && mounted) {
        widget.onRequestSettings?.call();
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
    if (r.error == 'network') { _showTopSnack('需要接入网络'); setState(() { _loading = false; }); return; }
    if (r.error != null && r.error!.startsWith('api:')) {
      final msg = r.error!.substring(4);
      _showTopSnack('API 错误: $msg'); setState(() { _loading = false; }); return;
    }
    if (r.error == 'api') { _showTopSnack('API配置不正确'); setState(() { _loading = false; }); return; }
    if (!r.isComplete) { _showTopSnack('无法解析'); setState(() { _loading = false; }); return; }
    setState(() { _result = r; _loading = false; });
  }

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

  int _parseTimestamp(String ts) {
    if (ts.isEmpty) return DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try { return DateTime.parse(ts).millisecondsSinceEpoch ~/ 1000; }
    catch (_) { return DateTime.now().millisecondsSinceEpoch ~/ 1000; }
  }

  @override
  void dispose() { _textCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 记账')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _textCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '描述你的花销，例如：今天中午吃饭花了38',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 规则解析按钮
          SizedBox(
            width: double.infinity,
            child: _loading && _lastMode == 'rule'
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('规则解析'),
                  onPressed: _loading ? null : _parseRule,
                ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('适合简单的句子', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 12),

          // 大模型解析按钮
          SizedBox(
            width: double.infinity,
            child: _loading && _lastMode == 'ai'
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                    label: const Text('取消', style: TextStyle(color: Colors.red, fontSize: 13)),
                    onPressed: _cancelRequest,
                  ),
                ])
              : OutlinedButton.icon(
                  icon: const Icon(Icons.psychology),
                  label: const Text('大模型解析'),
                  onPressed: _loading ? null : _parseAi,
                ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('需要在设置中填写大模型API，支持复杂句记账',
              style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('注意：大模型解析容易解析错误',
              style: TextStyle(color: Colors.orange.shade700, fontSize: 11), textAlign: TextAlign.center),
          ),
          if (widget.onRequestSettings != null)
            TextButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('前往设置配置API', style: TextStyle(fontSize: 13)),
              onPressed: () {
                widget.onRequestSettings?.call();
                Navigator.pop(context);
              },
            ),

          const SizedBox(height: 20),
          if (_result != null)
            !_result!.isComplete
              ? ConfirmDialog(result: _result!, onConfirm: _confirm)
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Text('金额: ¥${_result!.amount!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18)),
                      Text('分类: ${_result!.category}'),
                      Text('日期: ${_result!.timestamp.isEmpty ? DateTime.now().toString().split(' ')[0] : _result!.timestamp}'),
                      Text('备注: ${_result!.note}'),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        FilledButton(onPressed: () => _confirm(_result!.toJson()), child: const Text('确认保存')),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => ConfirmDialog(result: _result!, onConfirm: _confirm),
                          ),
                          child: const Text('修改')),
                      ]),
                    ]),
                  ),
                ),
        ]),
      ),
    );
  }
}
