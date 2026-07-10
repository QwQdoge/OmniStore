import json
import os

def compare_arb(source_file, target_file):
    with open(source_file, 'r', encoding='utf-8') as f:
        source_data = json.load(f)
    with open(target_file, 'r', encoding='utf-8') as f:
        target_data = json.load(f)

    source_keys = set(k for k in source_data.keys() if not k.startswith('@'))
    target_keys = set(k for k in target_data.keys() if not k.startswith('@'))

    missing = source_keys - target_keys
    return missing

en_file = 'FlutterUI/lib/l10n/app_en.arb'
locales = ['zh', 'zh_Hant', 'es', 'ja']

for locale in locales:
    target_file = f'FlutterUI/lib/l10n/app_{locale}.arb'
    if os.path.exists(target_file):
        missing = compare_arb(en_file, target_file)
        if missing:
            print(f"Locale {locale} is missing keys: {missing}")
        else:
            print(f"Locale {locale} has all keys.")
    else:
        print(f"Locale {locale} file not found.")
