import json
import os

def check_missing(base_file, target_file):
    with open(base_file, 'r', encoding='utf-8') as f:
        base = json.load(f)
    with open(target_file, 'r', encoding='utf-8') as f:
        target = json.load(f)

    base_keys = set(k for k in base.keys() if not k.startswith('@'))
    target_keys = set(k for k in target.keys() if not k.startswith('@'))

    missing = base_keys - target_keys
    return missing

locales = ['zh', 'zh_Hant', 'ja', 'es']
for loc in locales:
    missing = check_missing('FlutterUI/lib/l10n/app_en.arb', f'FlutterUI/lib/l10n/app_{loc}.arb')
    if missing:
        print(f"Missing keys in {loc}: {missing}")
    else:
        print(f"No missing keys in {loc}")

