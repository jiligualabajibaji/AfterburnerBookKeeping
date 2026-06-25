/// 规则解析引擎 + LLM 客户端 — 核心 AI 解析逻辑。
/// 规则引擎通过正则和关键词匹配从自然语言中提取金额、分类、日期、备注。
/// LLM 客户端通过 HTTP POST 调用 OpenAI 兼容 API 进行解析。

import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 解析结果数据模型
class ParseResult {
  final double? amount;
  final String? category;
  final String note;
  final String timestamp;
  final String source;              // 'rule' 或 'ai'
  final List<String> missingFields;
  final String? error;              // 'network'（网络错误）| 'api:...'（API 错误）| null

  ParseResult({
    this.amount, this.category, this.note = '', this.timestamp = '',
    this.source = 'rule', this.missingFields = const [], this.error,
  });

  bool get isComplete => amount != null && category != null;

  Map<String, dynamic> toJson() => {
    'amount': amount, 'category': category, 'note': note,
    'timestamp': timestamp, 'source': source, 'missing_fields': missingFields,
  };

  factory ParseResult.fromJson(Map<String, dynamic> json) => ParseResult(
    amount: (json['amount'] as num?)?.toDouble(),
    category: json['category'] as String?,
    note: json['note'] as String? ?? '',
    timestamp: json['timestamp'] as String? ?? '',
    source: json['source'] as String? ?? '',
    missingFields: (json['missing_fields'] as List?)?.cast<String>() ?? [],
  );
}

/// 规则解析引擎 — 纯正则+关键词匹配，不依赖网络。
/// ParserRules.parse(text) 为入口，返回 ParseResult。
class ParserRules {
  // ═══════════════════════════════════════
  //  金额匹配正则（阿拉伯数字）
  // ═══════════════════════════════════════
  // 按优先级从高到低排列，最后的兜底正则匹配任意数字
  static final List<RegExp> amountPatterns = [
    RegExp(r'花了?(\d+\.?\d*)\s*块'),
    RegExp(r'花了?(\d+\.?\d*)\s*元'),
    RegExp(r'花了?(\d+\.?\d*)'),
    RegExp(r'(\d+\.?\d*)\s*块钱'),
    RegExp(r'(\d+\.?\d*)\s*钱'),
    RegExp(r'付了?(\d+\.?\d*)'),
    RegExp(r'收入?了?(\d+\.?\d*)'),
    RegExp(r'赚了?(\d+\.?\d*)'),
    RegExp(r'发了?(\d+\.?\d*)'),
    RegExp(r'(\d+\.?\d*)\s*工资'),
    RegExp(r'(?<!\d)(\d+\.?\d*)(?!\d)'),  // 兜底：任意数字
  ];

  // ═══════════════════════════════════════
  //  分类关键词映射
  // ═══════════════════════════════════════
  static const Map<String, List<String>> categoryKeywords = {
    '餐饮': ['早餐', '午餐', '晚餐', '早', '中', '晚', '饭', '吃', '咖啡', '奶茶',
             '外卖', '餐厅', '食堂', '面', '粉', '小吃', '夜宵', '点餐'],
    '交通': ['地铁', '公交', '打车', '滴滴', '出租车', '加油', '停车', '高铁',
             '机票', '火车', '单车', '骑车', '出行'],
    '购物': ['买', '衣服', '鞋', '淘宝', '京东', '拼多多', '超市', '便利店', '日用', '数码'],
    '娱乐': ['电影', 'KTV', '游戏', '充值', '会员', '门票', '健身', '运动', '旅行'],
    '住房': ['房租', '水电', '物业', '燃气', '网费', '维修'],
    '医疗': ['医院', '药', '看病', '体检', '牙'],
    '工资收入': ['工资', '兼职', '奖金', '薪水', '月薪', '劳务', '提成'],
    '其他收入': ['红包', '退款', '利息', '理财', '中奖', '报销'],
  };

  // ═══════════════════════════════════════
  //  中文数字金额正则
  // ═══════════════════════════════════════
  static final List<RegExp> chineseAmountPatterns = [
    RegExp(r'花了?([一二三四五六七八九十百千万零\d]+)\s*块'),
    RegExp(r'花了?([一二三四五六七八九十百千万零\d]+)\s*元'),
    RegExp(r'花了?([一二三四五六七八九十百千万零\d]+)'),
    RegExp(r'([一二三四五六七八九十百千万零\d]+)\s*块钱'),
    RegExp(r'([一二三四五六七八九十百千万零\d]+)\s*钱'),
    RegExp(r'付了?([一二三四五六七八九十百千万零\d]+)'),
    RegExp(r'吃了?([一二三四五六七八九十百千万零\d]+)'),
    RegExp(r'用了?([一二三四五六七八九十百千万零\d]+)'),
    RegExp(r'交了?([一二三四五六七八九十百千万零\d]+)'),
    RegExp(r'给了?([一二三四五六七八九十百千万零\d]+)'),
    RegExp(r'收入?了?([一二三四五六七八九十百千万零\d]+)'),
    RegExp(r'赚了?([一二三四五六七八九十百千万零\d]+)'),
    RegExp(r'发了?([一二三四五六七八九十百千万零\d]+)'),
    RegExp(r'([一二三四五六七八九十百千万零\d]+)\s*工资'),
    RegExp(r'(?<!\d)([一二三四五六七八九十百千万零]+)(?!\d)'),  // 兜底：任意中文数字
  ];

  /// 将中文数字字符串转换为整数，如 "三十八" → 38, "一百二十三" → 123
  static int? chineseToNumber(String ch) {
    const Map<String, int> digits = {
      '零': 0, '一': 1, '二': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
    };
    const Map<String, int> scales = {
      '十': 10, '百': 100, '千': 1000, '万': 10000,
    };

    ch = ch.trim();
    // 如果已经是纯数字字符串，直接解析
    final digitOnly = int.tryParse(ch);
    if (digitOnly != null) return digitOnly;

    int result = 0;
    int current = 0;
    for (int i = 0; i < ch.length; i++) {
      final c = ch[i];
      if (digits.containsKey(c)) {
        current = digits[c]!;
      } else if (scales.containsKey(c)) {
        final scale = scales[c]!;
        if (current == 0) current = 1;  // "十二" → "十" 是开头，current 为 1
        result += current * scale;
        current = 0;
      }
    }
    result += current;
    return result > 0 ? result : null;
  }

  /// 去除常见中文/英文标点符号
  static String _stripPunct(String s) {
    return s.replaceAll(RegExp(r'[，。！？、；：""''（）\[\]【】《》〈〉\s,\.!\?;:\'\"\(\)\[\]]'), '');
  }

  /// 提取金额：先尝试阿拉伯数字匹配，再尝试中文数字匹配
  static double? extractAmount(String text) {
    text = _stripPunct(text);
    for (final pat in amountPatterns) {
      final m = pat.firstMatch(text);
      if (m != null) {
        final v = double.tryParse(m.group(1)!);
        if (v != null) return v;
      }
    }
    for (final pat in chineseAmountPatterns) {
      final m = pat.firstMatch(text);
      if (m != null) {
        final v = chineseToNumber(m.group(1)!);
        if (v != null) return v.toDouble();
      }
    }
    return null;
  }

  /// 根据关键词匹配分类，返回 (最匹配的分类, 所有匹配的分类列表)
  static (String?, List<String>) classifyCategory(String text) {
    final matched = <String>[];
    for (final entry in categoryKeywords.entries) {
      for (final kw in entry.value) {
        if (text.contains(kw)) {
          matched.add(entry.key);
          break;
        }
      }
    }
    if (matched.length == 1) {
      return (matched.first, matched);
    }
    return (null, matched);
  }

  /// 判断是否收入型描述（包含工资、收入、赚等关键词）
  static bool detectIncome(String text) {
    const incomeKw = ['工资', '收入', '赚', '发', '兼职', '奖金', '红包', '退款', '报销', '收钱', '收款', '进账', '挣', '盈利'];
    return incomeKw.any((kw) => text.contains(kw));
  }

  /// 提取备注：从原文中去除金额相关文本后剩下的内容，最长 20 字
  static String extractNote(String text) {
    var cleaned = text;
    for (final pat in [
      RegExp(r'花了?\d+\.?\d*\s*(块|元)?'),
      RegExp(r'\d+\.?\d*\s*块钱?'),
      RegExp(r'付了?\d+\.?\d*'),
      RegExp(r'收入?了?\d+\.?\d*'),
      RegExp(r'赚了?\d+\.?\d*'),
      RegExp(r'发了?\d+\.?\d*'),
      RegExp(r'\d+\.?\d*\s*工资'),
      RegExp(r'花了?[一二三四五六七八九十百千万]+\s*(块|元)?'),
      RegExp(r'[一二三四五六七八九十百千万]+\s*块钱?'),
      RegExp(r'付了?[一二三四五六七八九十百千万]+'),
      RegExp(r'收入?了?[一二三四五六七八九十百千万]+'),
      RegExp(r'赚了?[一二三四五六七八九十百千万]+'),
      RegExp(r'发了?[一二三四五六七八九十百千万]+'),
      RegExp(r'[一二三四五六七八九十百千万]+\s*工资'),
    ]) {
      cleaned = cleaned.replaceAll(pat, '');
    }
    cleaned = cleaned.trim();
    while (cleaned.endsWith('，') || cleaned.endsWith('。') || cleaned.endsWith('！') ||
           cleaned.endsWith('？') || cleaned.endsWith(',') || cleaned.endsWith('!') ||
           cleaned.endsWith('?')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    return cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
  }

  /// 解析日期表达，如 "昨天"、"5月1日"、"2024年1月1日"。
  /// 返回 YYYY-MM-DD 格式字符串，未找到返回空字符串。
  static String _parseDate(String text) {
    final now = DateTime.now();
    // 相对日期（长字符串在前避免子串误匹配）
    if (text.contains('大前天')) {
      final d = now.subtract(const Duration(days: 3));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    if (text.contains('前天')) {
      final d = now.subtract(const Duration(days: 2));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    if (text.contains('昨天')) {
      final d = now.subtract(const Duration(days: 1));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    if (text.contains('今天') || text.contains('今日')) {
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    if (text.contains('大后天')) {
      final d = now.add(const Duration(days: 3));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    if (text.contains('后天')) {
      final d = now.add(const Duration(days: 2));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    if (text.contains('明天') || text.contains('明日')) {
      final d = now.add(const Duration(days: 1));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    // 模式 "5月1日" 或 "5月1号"
    final m = RegExp(r'(\d{1,2})月(\d{1,2})[日号]').firstMatch(text);
    if (m != null) {
      final month = int.parse(m.group(1)!);
      final day = int.parse(m.group(2)!);
      final d = DateTime(now.year, month, day);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    // 模式 "2024年1月1日"
    final y = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})[日号]?').firstMatch(text);
    if (y != null) {
      final d = DateTime(int.parse(y.group(1)!), int.parse(y.group(2)!), int.parse(y.group(3)!));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    return '';
  }

  // ═══════════════════════════════════════
  //  规则解析入口
  // ═══════════════════════════════════════

  /// 执行纯规则解析，不依赖网络
  static ParseResult parse(String text) {
    final amount = extractAmount(text);
    var (category, _) = classifyCategory(text);
    final note = extractNote(text);

    // 如果有金额但未识别出分类，根据收支关键词推断默认分类
    if (category == null && amount != null) {
      category = detectIncome(text) ? '其他收入' : '其他支出';
    }

    final dateStr = _parseDate(text);

    return ParseResult(
      amount: amount,
      category: category,
      note: note,
      timestamp: dateStr,
      source: 'rule',
    );
  }

  // ═══════════════════════════════════════
  //  LLM 解析（OpenAI 兼容 API）
  // ═══════════════════════════════════════

  /// 规则引擎 + 可选 AI 增强解析。
  /// 先执行规则解析作为兜底，然后在配置了 API 的情况下调用大模型。
  static Future<ParseResult> parseWithAi(String text, {String apiKey = '', String endpoint = '', String model = ''}) async {
    final ruleResult = parse(text);  // 规则引擎兜底

    // 未配置 API Key，直接返回规则结果
    if (apiKey.isEmpty) {
      final missing = <String>[];
      if (ruleResult.amount == null) missing.add('amount');
      if (ruleResult.category == null) missing.add('category');
      return ParseResult(amount: ruleResult.amount, category: ruleResult.category,
        note: ruleResult.note, source: ruleResult.source, missingFields: missing);
    }

    // 调用 LLM API
    var ep = endpoint.isNotEmpty ? endpoint : 'https://api.openai.com/v1/chat/completions';
    if (!ep.endsWith('/chat/completions')) ep = '${ep.replaceAll(RegExp(r'/+$'), '')}/chat/completions';
    final categories = categoryKeywords.keys.join(', ');
    // 构造 Prompt 要求 LLM 返回结构化 JSON
    final prompt = '''从以下记账描述中提取信息，返回纯JSON（不要其他文字）：
原文：$text
要求：
- amount: 数字，支出为负数，收入为正数
- category: 从 [$categories] 选最匹配的
- note: 简短备注（2-6字）
- timestamp: 如果有具体时间就返回 YYYY-MM-DD HH:mm，否则返回 YYYY-MM-DD''';

    try {
      final client = http.Client();
      try {
        final response = await client.post(
          Uri.parse(ep),
          headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model.isNotEmpty ? model : 'gpt-4o-mini',
            'messages': [{'role': 'user', 'content': prompt}],
            'temperature': 0.1,
          }),
        ).timeout(const Duration(seconds: 20));  // 20 秒超时

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final content = body['choices'][0]['message']['content'] as String;
          final aiData = jsonDecode(content) as Map<String, dynamic>;
          return ParseResult(
            amount: (aiData['amount'] as num?)?.toDouble() ?? ruleResult.amount,
            category: aiData['category'] as String? ?? ruleResult.category,
            note: aiData['note'] as String? ?? ruleResult.note,
            timestamp: aiData['timestamp'] as String? ?? '',
            source: 'ai',
          );
        }
        // 非 200 状态码 → API 配置错误，给出中文提示
        String apiError;
        try {
          final errBody = jsonDecode(response.body);
          apiError = errBody['error']?['message'] ?? errBody['message'] ?? 'HTTP ${response.statusCode}';
        } catch (_) {
          apiError = 'HTTP ${response.statusCode}';
        }
        if (response.statusCode == 401) apiError = 'API Key 不正确';
        else if (response.statusCode == 404) apiError = '接口地址或模型名不正确';
        else if (response.statusCode == 400) apiError = '请求参数错误，请检查模型名';
        else if (response.statusCode == 302) {
          try {
            final errBody = jsonDecode(response.body);
            apiError = errBody['error']?['message'] ?? '接口地址或模型名不正确';
          } catch (_) {
            apiError = '接口地址或模型名不正确';
          }
        }
        return ParseResult(error: 'api:$apiError', source: 'ai', missingFields: []);
      } on SocketException {
        return ParseResult(error: 'network', source: 'ai', missingFields: []);
      } on TimeoutException {
        return ParseResult(error: 'network', source: 'ai', missingFields: []);
      } catch (_) {
        return ParseResult(error: 'api:请求失败', source: 'ai', missingFields: []);
      } finally {
        client.close();
      }
    } catch (_) {}

    // 异常情况返回规则结果
    final missing = <String>[];
    if (ruleResult.amount == null) missing.add('amount');
    if (ruleResult.category == null) missing.add('category');
    return ParseResult(amount: ruleResult.amount, category: ruleResult.category,
      note: ruleResult.note, source: ruleResult.source, missingFields: missing);
  }
}
