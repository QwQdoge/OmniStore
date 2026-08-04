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
        "repositories": {"zh": "软件源", "zh_Hant": "軟體存放庫", "ja": "リポジトリ", "es": "Repositorios"},
        "aurFull": {"zh": "AUR（Arch 用户软件源）", "zh_Hant": "AUR（Arch 使用者軟體存放庫）", "ja": "AUR (Arch User Repository)", "es": "AUR (Arch User Repository)"},
        "flatpakFull": {"zh": "Flatpak (Flathub)", "zh_Hant": "Flatpak (Flathub)", "ja": "Flatpak (Flathub)", "es": "Flatpak (Flathub)"},
        "quickStart": {
            "zh": "快速开始",
            "zh_Hant": "快速開始",
            "ja": "クイックスタート",
            "es": "Inicio rápido"
        },
        "importListSubtitle": {
            "zh": "从列表导入常用软件包",
            "zh_Hant": "從清單匯入常用套件",
            "ja": "リストからよく使うパッケージをインポート",
            "es": "Importa tus paquetes de uso frecuente desde una lista"
        },
        "emptyTrendingMessage": {
            "zh": "暂无热门数据；网络连接恢复后将自动更新。",
            "zh_Hant": "暫無熱門資料；網路連線恢復後將自動更新。",
            "ja": "トレンドデータがありません。ネットワーク接続が復旧すると自動的に更新されます。",
            "es": "No hay datos de tendencias disponibles; se actualizarán automáticamente cuando se restablezca la conexión."
        },
        "emptyRecommendationsMessage": {
            "zh": "继续搜索或安装应用后，此处将显示个性化建议。",
            "zh_Hant": "繼續搜尋或安裝應用程式後，此處將顯示個人化建議。",
            "ja": "アプリの検索やインストールを行うと、ここにパーソナライズされたおすすめが表示されます。",
            "es": "Las sugerencias personalizadas aparecerán aquí después de buscar o instalar aplicaciones."
        },
        "aiPickFallbackMessage": {
            "zh": "暂时无法生成个性化推荐。可浏览编辑精选或稍后重试。",
            "zh_Hant": "暫時無法產生個人化推薦。可瀏覽編輯精選或稍後重試。",
            "ja": "現在、パーソナライズされたおすすめ情報を生成できません。編集部のおすすめを閲覧するか、後ほどもう一度お試しください。",
            "es": "No se pueden generar recomendaciones personalizadas en este momento. Aún puedes explorar las selecciones de los editores o volver a intentarlo más tarde."
        }
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
