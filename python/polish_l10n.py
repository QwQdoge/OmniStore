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
    "activity": "任务动态",
    "source": "软件源",
    "variant": "分发版本",
    "loggingLevel": "日志级别",
    "license": "许可证",
    "dependenciesCount": "依赖项（{count}）",
    "recommendedSource": "推荐软件源：{source}",
    "aiPickDisclaimer": "条件可用。推荐基于您的使用习惯和当前配置生成，不会影响具体安装选项。",
    "aiApiKeyHelper": "Ollama 无需密钥，OpenAI 需填写 sk-xxx",
    "addCustomSourceDesc": "配置自定义 Flatpak 远程软件源、AppImage 订阅或 GitHub/Bitu 软件源",
    "aiPromptExplain": "AI 解析",
    "aiExplainUpdate": "AI 解析此更新",
    "aiOllamaNote": "确保 Ollama 已在后台运行并启用了 OLLAMA_ORIGINS=\"*\" 环境变量。",
    "importListSubtitle": "从列表导入常用软件包",
    "emptyTrendingMessage": "暂无热门数据；网络连接恢复后将自动更新。",
    "emptyRecommendationsMessage": "继续搜索或安装应用后，此处将显示个性化建议。",
    "aiPickFallbackMessage": "暂时无法生成个性化推荐。可浏览编辑精选或稍后重试。",
    "noActiveTasks": "暂无进行中的任务"
})

# Traditional Chinese Polishing (Consistency with zh)
polish('zh_Hant', {
    "activity": "任務動態",
    "source": "軟體源",
    "variant": "分發版本",
    "loggingLevel": "日誌級別",
    "license": "授權條款",
    "dependenciesCount": "依賴項（{count}）",
    "recommendedSource": "推薦軟體源：{source}",
    "aiPickDisclaimer": "條件可用。推薦基於您的使用習慣和當前配置生成，不會影響具體安裝選項。",
    "pacmanOfficial": "Pacman（官方軟體源）",
    "aurUser": "AUR（使用者軟體源）",
    "sourcePriority": "軟體源優先級（拖曳排序）",
    "repositories": "軟體源",
    "sourceConfigTitle": "軟體源設定",
    "sourceConfigSubtitle": "選擇要啟用的軟體源",
    "activeSources": "已啟用軟體源",
    "addCustomSource": "新增自訂軟體源",
    "addCustomSourceDesc": "設定自訂 Flatpak 遠端軟體源、AppImage 訂閱或 GitHub/Bitu 軟體源",
    "sourceType": "軟體源類型",
    "sourceName": "軟體源名稱",
    "addingCustomSource": "正在新增自訂軟體源...",
    "sourceAddSuccess": "軟體源新增成功！",
    "sourceAddFailed": "新增軟體源失敗。",
    "autoDetectingSources": "正在自動偵測系統中可用的軟體源...",
    "pluginsAndSources": "外掛程式與軟體源",
    "flatpakBetterDesc": "發現此應用程式有 Flatpak 軟體源，通常更穩定。",
    "forYou": "為您推薦",
    "aiThinking": "AI 正在思考...",
    "aiCorrection": "您是指？",
    "aiPromptExplain": "AI 解析",
    "aiExplainUpdate": "AI 解析此更新",
    "aiApiKeyHelper": "Ollama 無需金鑰，OpenAI 需填寫 sk-xxx",
    "aiOllamaNote": "確保 Ollama 已在背景執行並啟用了 OLLAMA_ORIGINS=\"*\" 環境變數。",
    "importListSubtitle": "從清單匯入常用套件",
    "emptyTrendingMessage": "暫無熱門資料；網路連線恢復後將自動更新。",
    "emptyRecommendationsMessage": "繼續搜尋或安裝應用程式後，此處將顯示個人化建議。",
    "aiPickFallbackMessage": "暫時無法產生個人化推薦。可瀏覽編輯精選或稍後重試。",
    # Traditional Chinese source & repository adjustments
    "pacmanOfficial": "Pacman（官方軟體源）",
    "aurUser": "AUR（使用者軟體源）",
    "sourcePriority": "軟體源優先級（拖曳排序）",
    "repositories": "軟體源",
    "sourceConfigTitle": "軟體源設定",
    "sourceConfigSubtitle": "選擇要啟用的軟體源",
    "flatpakBetterDesc": "發現此應用程式有 Flatpak 軟體源，通常更穩定。",
    "aurSecurityDesc": "AUR 是由社群維護的軟體源。由於任何人都可以上傳套件，其中可能包含不安全的程式碼。建議在安裝前仔細檢查 PKGBUILD。",
    "aurFull": "AUR（Arch 使用者軟體源）",
    "activeSources": "已啟用軟體源",
    "addCustomSource": "新增自訂軟體源",
    "addCustomSourceDesc": "設定自訂 Flatpak 遠端軟體源、AppImage 訂閱或 GitHub/Bitu 軟體源",
    "sourceType": "軟體源類型",
    "githubRepoType": "GitHub 倉庫（owner/repo）",
    "bituRepoType": "Bitu / Bitbucket（工作區/倉庫）",
    "sourceName": "軟體源名稱",
    "repoOwnerRepo": "軟體源地址（owner/repo）",
    "errorNameUrlRequired": "名稱和連結/軟體源地址不能為空",
    "addingCustomSource": "正在新增自訂軟體源...",
    "sourceAddSuccess": "軟體源新增成功！",
    "sourceAddFailed": "新增軟體源失敗。",
    "autoDetectingSources": "正在自動偵測系統中可用的軟體源...",
    "searchGithubHint": "搜尋 GitHub 倉庫...",
    "pluginsAndSources": "外掛程式與軟體源"
})
