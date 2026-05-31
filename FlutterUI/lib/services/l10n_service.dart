import 'package:flutter/material.dart';

enum Language { zh, en, ja, es, zhHant }

class L10nService {
  static final ValueNotifier<Language> language = ValueNotifier(Language.zh);

  static Future<void> init(Map<String, dynamic> config) async {
    final ui = config['ui'] ?? {};
    final langStr = ui['language'] as String?;
    switch (langStr) {
      case 'en':
        language.value = Language.en;
        break;
      case 'ja':
        language.value = Language.ja;
        break;
      case 'es':
        language.value = Language.es;
        break;
      case 'zh_Hant':
        language.value = Language.zhHant;
        break;
      case 'zh':
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
