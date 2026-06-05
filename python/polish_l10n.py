import json

def polish(loc, updates):
    path = f'FlutterUI/lib/l10n/app_{loc}.arb'
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    for k, v in updates.items():
        if k in data:
            data[k] = v

    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

# Japanese Polishing
polish('ja', {
    "ready": "インストール済み",
    "noResults": "検索結果が見つかりませんでした",
    "aiThinking": "AI が考え中...",
    "aiCorrection": "もしかして："
})

# Spanish Polishing
polish('es', {
    "upToDate": "Todas las aplicaciones están actualizadas",
    "confirmActionMsg": "¿Confirmas que deseas realizar esta acción en {name}?",
    "variant": "Fuente de instalación"
})

# Traditional Chinese Polishing (Consistency with zh)
polish('zh_Hant', {
    "forYou": "為您推薦",
    "aiThinking": "AI 正在思考...",
    "aiCorrection": "您是指？"
})
