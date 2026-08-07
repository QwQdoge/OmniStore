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
    "aiCorrection": "もしかして：",
    "importListSubtitle": "リストからよく使うパッケージをインポート"
})

# Spanish Polishing
polish('es', {
    "upToDate": "Todas las aplicaciones están actualizadas",
    "confirmActionMsg": "¿Confirmas que deseas realizar esta acción en {name}?",
    "variant": "Variantes"
})

# Simplified Chinese Polishing
polish('zh', {
    "aiApiKeyHelper": "Ollama 无需密钥，OpenAI 需填写 sk-xxx",
    "aiOllamaNote": "确保 Ollama 已在后台运行并启用了 OLLAMA_ORIGINS=\"*\" 环境变量。",
    "importListSubtitle": "从列表导入常用软件包",
    "emptyTrendingMessage": "暂无热门数据；网络连接恢复后将自动更新。",
    "emptyRecommendationsMessage": "继续搜索或安装应用后，此处将显示个性化建议。",
    "aiPickFallbackMessage": "暂时无法生成个性化推荐。可浏览编辑精选或稍后重试。",
    "activity": "任务动态",
    "source": "软件源",
    "variant": "分发版本",
    "loggingLevel": "日志级别",
    "license": "许可证",
    "dependenciesCount": "依赖项（{count}）",
    "noActiveTasks": "暂无进行中的任务",
    "recommendedSource": "推荐软件源：{source}",
    "aiPickDisclaimer": "根据你的搜索、安装历史和当前可用软件源生成；不会影响安装选择。"
})

# Traditional Chinese Polishing (Consistency with zh)
polish('zh_Hant', {
    "forYou": "為您推薦",
    "aiThinking": "AI 正在思考...",
    "aiCorrection": "您是指？",
    "aiApiKeyHelper": "Ollama 無需金鑰，OpenAI 需填寫 sk-xxx",
    "aiOllamaNote": "確保 Ollama 已在背景執行並啟用了 OLLAMA_ORIGINS=\"*\" 環境變數。",
    "importListSubtitle": "從清單匯入常用套件",
    "emptyTrendingMessage": "暫無熱門資料；網路連線恢復後將自動更新。",
    "emptyRecommendationsMessage": "繼續搜尋或安裝應用程式後，此處將顯示個人化建議。",
    "aiPickFallbackMessage": "暫時無法產生個人化推薦。可瀏覽編輯精選或稍後重試。",
    "activity": "任務動態",
    "source": "軟體源",
    "variant": "分發版本",
    "loggingLevel": "日誌級別",
    "license": "授權條款",
    "dependenciesCount": "依賴項（{count}）",
    "recommendedSource": "推薦軟體源：{source}",
    "aiPickDisclaimer": "根據您的搜尋、安裝歷史和當前可用軟體源生成；不會影響安裝選擇。"
})
