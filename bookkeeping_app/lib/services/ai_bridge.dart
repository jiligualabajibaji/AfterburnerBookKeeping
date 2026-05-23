import 'parser_rules.dart' as rules;

class AiParseResult {
  final double? amount;
  final String? category;
  final String note;
  final String timestamp;
  final String source;
  final List<String> missingFields;
  final String? error;

  AiParseResult({this.amount, this.category, this.note = '', this.timestamp = '',
    this.source = '', this.missingFields = const [], this.error});

  bool get isComplete => amount != null && category != null;

  Map<String, dynamic> toJson() => {
    'amount': amount, 'category': category, 'note': note,
    'timestamp': timestamp, 'source': source, 'missing_fields': missingFields,
  };
}

class AiBridgeService {
  /// Parse using rule engine only (simple sentences)
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

  /// Parse using rule engine + optional AI API
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
