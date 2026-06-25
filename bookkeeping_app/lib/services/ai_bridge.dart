/// AI 解析桥接层 — 封装规则引擎和 LLM 解析的调用接口。
/// AiBridgeService 对外提供统一的 parseRule() 和 parseWithAi() 两个静态方法。
/// AiParseResult 是解析结果的数据模型。

import 'parser_rules.dart' as rules;

/// AI 解析结果模型
class AiParseResult {
  final double? amount;           // 解析出的金额
  final String? category;         // 解析出的分类名
  final String note;              // 解析出的备注
  final String timestamp;         // 解析出的时间戳（字符串形式）
  final String source;            // 解析来源：'rule' 规则引擎 / 'ai' 大模型
  final List<String> missingFields;  // 未能解析出的字段列表
  final String? error;            // 错误信息：'network' | 'api' | null

  AiParseResult({this.amount, this.category, this.note = '', this.timestamp = '',
    this.source = '', this.missingFields = const [], this.error});

  /// 是否解析完整（金额和分类都解析到了）
  bool get isComplete => amount != null && category != null;

  Map<String, dynamic> toJson() => {
    'amount': amount, 'category': category, 'note': note,
    'timestamp': timestamp, 'source': source, 'missing_fields': missingFields,
  };
}

class AiBridgeService {
  /// 规则引擎解析 — 基于正则和关键词匹配，适合简单句子
  static Future<AiParseResult> parseRule(String text) async {
    final result = rules.ParserRules.parse(text);
    return AiParseResult(
      amount: result.amount,
      category: result.category,
      note: result.note,
      timestamp: result.timestamp,
      source: result.source,
      missingFields: result.missingFields,
    );
  }

  /// 大模型解析 — 调用 OpenAI 兼容 API，适合复杂句子
  /// 需要配置 apiKey、endpoint、model
  static Future<AiParseResult> parseWithAi(String text, {String apiKey = '', String endpoint = '', String model = ''}) async {
    final result = await rules.ParserRules.parseWithAi(text, apiKey: apiKey, endpoint: endpoint, model: model);
    return AiParseResult(
      amount: result.amount,
      category: result.category,
      note: result.note,
      timestamp: result.timestamp,
      source: result.source,
      missingFields: result.missingFields,
      error: result.error,
    );
  }
}
