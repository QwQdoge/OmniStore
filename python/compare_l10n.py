import json


def check_missing(base_file, target_file):
    with open(base_file, 'r', encoding='utf-8') as f:
        base = json.load(f)
    with open(target_file, 'r', encoding='utf-8') as f:
        target = json.load(f)

    base_keys = {k for k in base if not k.startswith('@')}
    target_keys = {k for k in target if not k.startswith('@')}

    missing = base_keys - target_keys
    return missing


locales = ['zh', 'zh_Hant', 'ja', 'es']
for loc in locales:
    base_file = 'FlutterUI/lib/l10n/app_en.arb'
    target_file = f'FlutterUI/lib/l10n/app_{loc}.arb'
    missing = check_missing(base_file, target_file)
    if missing:
        print(f"Missing keys in {loc}: {missing}")
    else:
        print(f"No missing keys in {loc}")
