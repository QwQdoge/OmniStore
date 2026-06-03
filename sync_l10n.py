import json
import os

def sync_locale(loc):
    base_file = 'FlutterUI/lib/l10n/app_en.arb'
    target_file = f'FlutterUI/lib/l10n/app_{loc}.arb'

    with open(base_file, 'r', encoding='utf-8') as f:
        base = json.load(f)
    with open(target_file, 'r', encoding='utf-8') as f:
        target = json.load(f)

    new_keys = {
        "advanced": {"zh": "高级", "zh_Hant": "進階", "ja": "詳細設定", "es": "Avanzado"},
        "general": {"zh": "常规", "zh_Hant": "一般", "ja": "全般", "es": "General"},
        "repositories": {"zh": "软件仓库", "zh_Hant": "軟體倉庫", "ja": "リポジトリ", "es": "Repositorios"},
        "aurFull": {"zh": "AUR (Arch 用户软件仓库)", "zh_Hant": "AUR (Arch 使用者軟體倉庫)", "ja": "AUR (Arch User Repository)", "es": "AUR (Arch User Repository)"},
        "flatpakFull": {"zh": "Flatpak (Flathub)", "zh_Hant": "Flatpak (Flathub)", "ja": "Flatpak (Flathub)", "es": "Flatpak (Flathub)"}
    }

    # Remove keys from target if not in base
    target_keys = list(target.keys())
    for k in target_keys:
        if k not in base:
            del target[k]

    # Add/Sync keys from base
    for k, v in base.items():
        if k not in target:
            if k in new_keys:
                target[k] = new_keys[k][loc]
            else:
                target[k] = v
        elif k.startswith('@') and k[1:] in new_keys:
             target[k] = v

    # Sort target according to base order
    synced = {}
    for k in base.keys():
        if k in target:
            synced[k] = target[k]
        else:
            # Should not happen if everything is synced
            pass

    with open(target_file, 'w', encoding='utf-8') as f:
        json.dump(synced, f, ensure_ascii=False, indent=2)

locales = ['zh', 'zh_Hant', 'ja', 'es']
for loc in locales:
    sync_locale(loc)
    print(f"Synced {loc}")
