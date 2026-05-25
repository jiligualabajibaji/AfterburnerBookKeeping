import 'package:flutter/material.dart';

class AppTranslations {
  final Locale locale;
  AppTranslations(this.locale);

  static AppTranslations of(BuildContext context) {
    return Localizations.of<AppTranslations>(context, AppTranslations)!;
  }

  String tr(String key, [Map<String, String>? params]) {
    var str = _strings[key]?[locale.languageCode] ?? key;
    if (params != null) {
      params.forEach((k, v) => str = str.replaceAll('{$k}', v));
    }
    return str;
  }

  static const _strings = <String, Map<String, String>>{
    // 主页 - 底部导航
    'tab.transactions': {'zh': '流水', 'en': 'Transactions'},
    'tab.stats': {'zh': '统计', 'en': 'Stats'},
    'tab.search': {'zh': '搜索', 'en': 'Search'},
    'tab.settings': {'zh': '设置', 'en': 'Settings'},

    // 主页 - 流水
    'home.hint': {'zh': '点击年月切换 · 左右滑动 · 点击记录编辑', 'en': 'Tap year-month · Swipe · Tap to edit'},
    'home.no_records': {'zh': '暂无记录', 'en': 'No records'},
    'home.expense': {'zh': '支出', 'en': 'Expense'},
    'home.income': {'zh': '收入', 'en': 'Income'},
    'home.batch_delete': {'zh': '批量删除', 'en': 'Batch delete'},
    'home.select_all': {'zh': '全选', 'en': 'Select all'},
    'home.select_month': {'zh': '全选本月', 'en': 'Select all this month'},
    'home.select_expense': {'zh': '全选本月支出', 'en': 'Select all this month expense'},
    'home.select_income': {'zh': '全选本月收入', 'en': 'Select all this month income'},
    'home.confirm_delete_title': {'zh': '确认删除 {n} 条记录', 'en': 'Delete {n} records?'},
    'home.confirm_delete_body': {'zh': '确定要删除选中的 {n} 条记录吗？此操作不可撤销。', 'en': 'Delete {n} selected records? This cannot be undone.'},
    'home.cancel': {'zh': '取消', 'en': 'Cancel'},
    'home.confirm_delete': {'zh': '确认删除', 'en': 'Delete'},
    'home.cancel_select': {'zh': '取消', 'en': 'Cancel'},

    // 记一笔
    'add.title': {'zh': '记一笔', 'en': 'Add Transaction'},
    'add.add_another': {'zh': '再记一笔', 'en': 'Add another'},
    'add.save_return': {'zh': '保存并返回', 'en': 'Save & return'},
    'add.expense': {'zh': '支出', 'en': 'Expense'},
    'add.income': {'zh': '收入', 'en': 'Income'},
    'add.amount': {'zh': '金额', 'en': 'Amount'},
    'add.amount_hint': {'zh': '支持算式和中文数字，如 100+50、一百三十六', 'en': 'Expressions & Chinese numbers, e.g. 100+50'},
    'add.select_category': {'zh': '选择分类', 'en': 'Select category'},
    'add.date': {'zh': '日期', 'en': 'Date'},
    'add.note': {'zh': '备注', 'en': 'Note'},
    'add.note_hint': {'zh': '可选', 'en': 'Optional'},
    'add.new_category': {'zh': '新增', 'en': 'New'},
    'add.add_category_title': {'zh': '添加{type}分类', 'en': 'Add {type} category'},
    'add.category_name': {'zh': '分类名称', 'en': 'Category name'},
    'add.category_hint': {'zh': '输入新分类名称', 'en': 'Enter category name'},
    'add.confirm_add': {'zh': '添加', 'en': 'Add'},
    'add.error_amount_empty': {'zh': '请填写金额', 'en': 'Please enter an amount'},
    'add.error_amount_invalid': {'zh': '金额必须为数字或算式（如 100+50）', 'en': 'Amount must be a number or expression (e.g. 100+50)'},
    'add.error_amount_negative': {'zh': '金额不能小于0', 'en': 'Amount cannot be negative'},
    'add.error_no_category': {'zh': '请选择分类', 'en': 'Please select a category'},

    // AI 记账
    'ai.title': {'zh': 'AI 记账', 'en': 'AI Bookkeeping'},
    'ai.hint': {'zh': '描述你的花销，例如：今天中午吃饭花了38', 'en': 'Describe your expense, e.g.: lunch 38'},
    'ai.rule_parse': {'zh': '规则解析', 'en': 'Rule parse'},
    'ai.rule_desc': {'zh': '适合简单的句子', 'en': 'For simple sentences'},
    'ai.llm_parse': {'zh': '大模型解析', 'en': 'LLM parse'},
    'ai.llm_desc': {'zh': '需要在设置中填写大模型API，支持复杂句记账', 'en': 'Configure API in settings for complex sentences'},
    'ai.cancel': {'zh': '取消', 'en': 'Cancel'},
    'ai.go_settings': {'zh': '前往设置配置API', 'en': 'Go to settings to configure API'},
    'ai.no_api_title': {'zh': '未配置 API', 'en': 'API not configured'},
    'ai.no_api_body': {'zh': '大模型解析需要在设置中填写 API Key 和接口地址。是否前往设置？', 'en': 'LLM parsing requires API Key and endpoint in settings. Go to settings?'},
    'ai.no_api_go': {'zh': '去设置', 'en': 'Go to settings'},
    'ai.error_empty': {'zh': '请先输入记账内容', 'en': 'Please enter bookkeeping content first'},
    'ai.error_parse_failed': {'zh': '无法解析', 'en': 'Failed to parse'},
    'ai.error_network': {'zh': '需要接入网络', 'en': 'Network required'},
    'ai.error_api': {'zh': 'API配置不正确', 'en': 'Invalid API configuration'},
    'ai.error_api_prefix': {'zh': 'API 错误: {msg}', 'en': 'API error: {msg}'},
    'ai.saved': {'zh': '已保存 (id={id})', 'en': 'Saved (id={id})'},
    'ai.save_failed': {'zh': '保存失败: {msg}', 'en': 'Save failed: {msg}'},
    'ai.amount': {'zh': '金额', 'en': 'Amount'},
    'ai.category': {'zh': '分类', 'en': 'Category'},
    'ai.date': {'zh': '日期', 'en': 'Date'},
    'ai.note': {'zh': '备注', 'en': 'Note'},
    'ai.confirm_save': {'zh': '确认保存', 'en': 'Confirm & save'},
    'ai.edit': {'zh': '修改', 'en': 'Edit'},
    'ai.llm_warning': {'zh': '注意：大模型解析容易解析错误', 'en': 'Note: LLM parsing may have errors'},

    // 搜索
    'search.hint': {'zh': '搜索类别或备注...', 'en': 'Search category or note...'},
    'search.start_date': {'zh': '开始日期', 'en': 'Start date'},
    'search.end_date': {'zh': '结束日期', 'en': 'End date'},
    'search.all': {'zh': '全部', 'en': 'All'},
    'search.expense': {'zh': '支出', 'en': 'Expense'},
    'search.income': {'zh': '收入', 'en': 'Income'},
    'search.placeholder': {'zh': '输入关键词搜索交易记录', 'en': 'Enter keyword to search'},
    'search.no_results': {'zh': '未找到匹配的记录', 'en': 'No matching records found'},

    // 统计
    'stats.month': {'zh': '月', 'en': 'Month'},
    'stats.year': {'zh': '年', 'en': 'Year'},
    'stats.expense': {'zh': '支出', 'en': 'Expense'},
    'stats.income': {'zh': '收入', 'en': 'Income'},
    'stats.no_expense': {'zh': '暂无支出', 'en': 'No expenses'},
    'stats.no_income': {'zh': '暂无收入', 'en': 'No income'},
    'stats.total': {'zh': '{period} {type} 合计: ¥{total}', 'en': '{period} {type} total: ¥{total}'},

    // 通用
    'common.select_year': {'zh': '选择年份', 'en': 'Select year'},
    'common.select_month': {'zh': '选择月份', 'en': 'Select month'},
    'common.year_title': {'zh': '{year}年', 'en': '{year}'},

    // 设置
    'settings.title': {'zh': '设置', 'en': 'Settings'},
    'settings.api_config': {'zh': 'API 配置', 'en': 'API Configuration'},
    'settings.api_key': {'zh': 'API Key', 'en': 'API Key'},
    'settings.api_key_hint': {'zh': '输入 API Key', 'en': 'Enter API Key'},
    'settings.api_key_example': {'zh': '例如 DeepSeek 的 API 格式: sk-...', 'en': 'e.g. DeepSeek API format: sk-...'},
    'settings.endpoint': {'zh': '接口地址', 'en': 'Endpoint'},
    'settings.endpoint_hint': {'zh': 'https://api.deepseek.com', 'en': 'https://api.deepseek.com'},
    'settings.endpoint_example': {'zh': 'DeepSeek 接口地址: https://api.deepseek.com/chat/completions', 'en': 'DeepSeek endpoint: https://api.deepseek.com/chat/completions'},
    'settings.model': {'zh': '模型', 'en': 'Model'},
    'settings.model_hint': {'zh': 'deepseek-v4-flash', 'en': 'deepseek-v4-flash'},
    'settings.model_example': {'zh': '例如 deepseek-v4-flash 或 deepseek-v4-pro', 'en': 'e.g. deepseek-v4-flash or deepseek-v4-pro'},
    'settings.config_name': {'zh': '配置名称', 'en': 'Config name'},
    'settings.config_name_hint': {'zh': '例如: DeepSeek', 'en': 'e.g. DeepSeek'},
    'settings.save': {'zh': '保存', 'en': 'Save'},
    'settings.in_use': {'zh': '使用中', 'en': 'In use'},
    'settings.apply': {'zh': '应用', 'en': 'Apply'},
    'settings.delete': {'zh': '删除', 'en': 'Delete'},
    'settings.background': {'zh': '背景图', 'en': 'Background'},
    'settings.select_image': {'zh': '选择图片', 'en': 'Select image'},
    'settings.remove_image': {'zh': '移除', 'en': 'Remove'},
    'settings.background_hint': {'zh': '上传图片作为背景图片', 'en': 'Upload an image as background'},
    'settings.app_name': {'zh': '更改软件名称', 'en': 'App name'},
    'settings.app_name_label': {'zh': '新名称（30字内）', 'en': 'New name (max 30 chars)'},
    'settings.app_name_hint': {'zh': '极速记账', 'en': 'Quick Ledger'},
    'settings.clear': {'zh': '清空', 'en': 'Clear'},
    'settings.save_name': {'zh': '保存', 'en': 'Save'},
    'settings.name_restored': {'zh': '已恢复默认名称', 'en': 'Default name restored'},
    'settings.name_changed': {'zh': '名称已更改为: {name}', 'en': 'Name changed to: {name}'},
    'settings.theme': {'zh': '主题', 'en': 'Theme'},
    'settings.theme_light': {'zh': '浅色', 'en': 'Light'},
    'settings.theme_dark': {'zh': '深色', 'en': 'Dark'},
    'settings.theme_system': {'zh': '跟随系统', 'en': 'System'},
    'settings.data': {'zh': '数据管理', 'en': 'Data'},
    'settings.export': {'zh': '导出数据', 'en': 'Export data'},
    'settings.import': {'zh': '导入数据', 'en': 'Import data'},
    'settings.export_success': {'zh': '导出成功', 'en': 'Export successful'},
    'settings.import_result': {'zh': '导入完成: {imported} 条新记录, {skipped} 条跳过', 'en': 'Import done: {imported} new, {skipped} skipped'},
    'settings.language': {'zh': '语言', 'en': 'Language'},
    'settings.language_zh': {'zh': '中文', 'en': 'Chinese'},
    'settings.language_en': {'zh': 'English', 'en': 'English'},
    'settings.language_system': {'zh': '跟随系统', 'en': 'System'},

    // 分类相关
    'category.type_expense': {'zh': '支出', 'en': 'expense'},
    'category.type_income': {'zh': '收入', 'en': 'income'},

    // 确认对话框
    'dialog.save': {'zh': '确认保存', 'en': 'Confirm & save'},
    'dialog.edit': {'zh': '修改', 'en': 'Edit'},
    'dialog.amount': {'zh': '金额', 'en': 'Amount'},
    'dialog.category': {'zh': '分类', 'en': 'Category'},
    'dialog.date': {'zh': '日期', 'en': 'Date'},
    'dialog.note': {'zh': '备注', 'en': 'Note'},
  };
}

class AppTranslationsDelegate extends LocalizationsDelegate<AppTranslations> {
  const AppTranslationsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppTranslations> load(Locale locale) => Future.value(AppTranslations(locale));

  @override
  bool shouldReload(AppTranslationsDelegate old) => false;
}
