import 'package:flutter/material.dart';

enum Language { zh, en, ja, es, zhHant }

class L10nService {
  static final ValueNotifier<Language> language = ValueNotifier(Language.zh);

  static Future<void> init(Map<String, dynamic> config) async {
    final ui = config['ui'] ?? {};
    final langStr = ui['language'] as String?;
    switch (langStr) {
      case 'en':
      case 'en-US':
        language.value = Language.en;
        break;
      case 'ja':
      case 'ja-JP':
        language.value = Language.ja;
        break;
      case 'es':
      case 'es-ES':
        language.value = Language.es;
        break;
      case 'zh_Hant':
      case 'zh-TW':
        language.value = Language.zhHant;
        break;
      case 'zh':
      case 'zh-CN':
        language.value = Language.zh;
        break;
      default:
        language.value = Language.zh;
        break;
    }
  }

  static String s(String key, {List<String>? args}) {
    return key;
  }

  static void setLanguage(Language lang) {
    language.value = lang;
  }

  static String get languageCode {
    switch (language.value) {
      case Language.en:
        return 'en';
      case Language.ja:
        return 'ja';
      case Language.es:
        return 'es';
      case Language.zhHant:
        return 'zh_Hant';
      case Language.zh:
        return 'zh';
    }
  }
}
