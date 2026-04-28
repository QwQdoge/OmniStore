import 'package:flutter/material.dart';

enum Language { zh, en }

class L10nService {
  static final ValueNotifier<Language> language = ValueNotifier(Language.zh);

  static Future<void> init(Map<String, dynamic> config) async {
    final ui = config['ui'] ?? {};
    final langStr = ui['language'] as String?;
    if (langStr == 'en') {
      language.value = Language.en;
    } else {
      language.value = Language.zh;
    }
  }

  static final Map<Language, Map<String, String>> _strings = {
    Language.zh: {
      'discover': '发现',
      'search': '搜索',
      'settings': '设置',
      'downloads': '下载',
      'search_hint': '搜索应用、游戏、工具...',
      'history': '搜索历史',
      'categories': '分类浏览',
      'clear_history': '清空历史记录',
      'confirm_clear_history': '确定要删除所有搜索历史吗？',
      'cancel': '取消',
      'clear': '清空',
      'no_history': '暂无搜索历史',
      'results_count': '{} 个结果',
      'not_found': '未找到相关应用',
      'searching': '正在寻找...',
      'install': '安装',
      'open': '打开',
      'ready': '已就绪',
      'uninstall': '卸载',
      'launch': '启动程序',
      'about': '关于此软件',
      'details': '详细参数',
      'source': '来源',
      'variants': '变体',
      'version': '版本',
      'package_manager': '包管理器',
      'priority': '结果优先级（权重）',
      'max_results': '最大结果数',
      'appearance': '界面个性化',
      'theme_color': '主题色种子',
      'appearance_mode': '外观模式',
      'system_mode': '跟随系统',
      'light_mode': '浅色模式',
      'dark_mode': '深色模式',
      'logging': '系统与日志',
      'log_level': '日志记录等级',
      'save_apply': '保存并应用',
      'save_success': '配置已保存，部分设置重启生效',
      'save_fail': '保存配置失败',
      'confirm': '确定',
      'language': '语言',
      'chinese': '中文',
      'english': 'English',
      'dev': '开发工具',
      'media': '影音娱乐',
      'web': '互联网',
      'sys': '系统工具',
      'work': '办公',
      'game': '游戏',
      'help_outline_rounded': '帮助',
      'user_profile': '用户个人资料',
      'clear_search': '清除搜索',
      'list_view': '列表视图',
      'grid_view': '网格视图',
      'more_options': '更多选项',
      'featured': '为你推荐',
      'popular': '热门应用',
      'no_recommendations': '暂无推荐',
      'search_failed': '搜索失败: {}',
      'installed': '已安装',
      'software_screenshots': '软件截图',
      'no_description': '暂无详细描述',
      'developer': '开发者',
      'license': '许可',
    },
    Language.en: {
      'discover': 'Discover',
      'search': 'Search',
      'settings': 'Settings',
      'downloads': 'Downloads',
      'search_hint': 'Search apps, games, tools...',
      'history': 'History',
      'categories': 'Categories',
      'clear_history': 'Clear History',
      'confirm_clear_history': 'Are you sure you want to clear all history?',
      'cancel': 'Cancel',
      'clear': 'Clear',
      'no_history': 'No search history',
      'results_count': '{} results',
      'not_found': 'No apps found',
      'searching': 'Searching...',
      'install': 'Install',
      'open': 'Open',
      'ready': 'Ready',
      'uninstall': 'Uninstall',
      'launch': 'Launch',
      'about': 'About',
      'details': 'Details',
      'source': 'Source',
      'variants': 'Variants',
      'version': 'Version',
      'package_manager': 'Package Manager',
      'priority': 'Result Priority',
      'max_results': 'Max Results',
      'appearance': 'Appearance',
      'theme_color': 'Theme Color',
      'appearance_mode': 'Appearance Mode',
      'system_mode': 'Follow System',
      'light_mode': 'Light Mode',
      'dark_mode': 'Dark Mode',
      'logging': 'System & Logs',
      'log_level': 'Log Level',
      'save_apply': 'Save & Apply',
      'save_success': 'Settings saved, some changes require restart',
      'save_fail': 'Failed to save settings',
      'confirm': 'Confirm',
      'language': 'Language',
      'chinese': 'Chinese',
      'english': 'English',
      'dev': 'Development',
      'media': 'Entertainment',
      'web': 'Internet',
      'sys': 'System',
      'work': 'Office',
      'game': 'Games',
      'help_outline_rounded': 'Help',
      'user_profile': 'User Profile',
      'clear_search': 'Clear Search',
      'list_view': 'List View',
      'grid_view': 'Grid View',
      'more_options': 'More Options',
      'featured': 'Featured',
      'popular': 'Popular',
      'no_recommendations': 'No recommendations',
      'search_failed': 'Search failed: {}',
      'installed': 'Installed',
      'software_screenshots': 'Screenshots',
      'no_description': 'No description available',
      'developer': 'Developer',
      'license': 'License',
    },
  };

  static String s(String key, {List<String>? args}) {
    String str = _strings[language.value]?[key] ?? key;
    if (args != null) {
      for (var arg in args) {
        str = str.replaceFirst('{}', arg);
      }
    }
    return str;
  }

  static void setLanguage(Language lang) {
    language.value = lang;
  }

  static String get languageCode => language.value == Language.en ? 'en' : 'zh';
}
