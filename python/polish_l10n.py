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
    "variant": "Variantes",
    "taskError": "Error de tarea: {error}"
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
    "aiApiKeyHelper": "Ollama 可留空，OpenAI 填写 sk-xxx",
    "howToGetApiKeyDesc": "1. Ollama（本地）：下载并运行 Ollama，无需密钥；2. 云端（OpenAI）：前往服务商官网创建 API 密钥后在此填入。",
    "addCustomSourceDesc": "配置自定义 Flatpak 远程软件源、AppImage 订阅或 GitHub/Bitu 软件源",
    "aiPromptExplain": "AI 解析",
    "aiExplainUpdate": "AI 解析此更新",
    "aiOllamaNote": "注意：使用 Ollama 时，请确保其已运行且环境变量配置为 OLLAMA_ORIGINS=\"*\"。",
    "resetCacheConfirm": "此操作将清空您的搜索历史与本地推荐缓存。是否继续？",
    "noPluginsFound": "未找到软件源插件",
    "patHelperText": "请提供 GitHub Classic PAT 或细粒度 (Fine-grained) 令牌。",
    "importListSubtitle": "从列表导入常用软件包",
    "emptyTrendingMessage": "暂无热门数据；网络连接恢复后将自动更新。",
    "emptyRecommendationsMessage": "继续搜索或安装应用后，此处将显示个性化建议。",
    "aiPickFallbackMessage": "暂时无法生成个性化推荐。可浏览编辑精选或稍后重试。",
    "noActiveTasks": "暂无进行中的任务",
    "aiHealthSubtitle": "针对您 Arch Linux 的智能诊断",
    "signInSubtitle": "跨设备同步应用、设置和收藏",
    "errorNameUrlRequired": "名称和链接/软件源地址不能为空"
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
    "noPluginsFound": "未找到軟體源外掛程式",
    "patHelperText": "請提供 GitHub Classic PAT 或細粒度（Fine-grained）權標。",
    "repoOwnerRepo": "儲存庫地址（owner/repo）",
    "noGithubReposFound": "未找到 GitHub 程式碼儲存庫",
    "flatpakBetterDesc": "發現此應用程式有 Flatpak 軟體源，通常更穩定。",
    "forYou": "為您推薦",
    "aiThinking": "AI 正在思考...",
    "aiCorrection": "您是指？",
    "aiPromptExplain": "AI 解析",
    "aiExplainUpdate": "AI 解析此更新",
    "aiApiKeyHelper": "Ollama 可留空，OpenAI 填寫 sk-xxx",
    "howToGetApiKeyDesc": "1. Ollama（本地）：下載並執行 Ollama，無需金鑰；2. 雲端（OpenAI）：前往服務商官網建立 API 金鑰後在此填入。",
    "aiOllamaNote": "注意：使用 Ollama 時，請確保其已執行且環境變數設定為 OLLAMA_ORIGINS=\"*\"。",
    "resetCacheConfirm": "此操作將清空您的搜尋歷史與本地推薦快取。是否繼續？",
    "importListSubtitle": "從清單匯入常用套件",
    "emptyTrendingMessage": "暫無熱門資料；網路連線恢復後將自動更新。",
    "emptyRecommendationsMessage": "繼續搜尋或安裝應用程式後，此處將顯示個人化建議。",
    "aiPickFallbackMessage": "暫時無法產生個人化推薦。可瀏覽編輯精選或稍後重試。",
    "aurSecurityDesc": "AUR 是由社群維護的軟體源。由於任何人都可以上傳套件，其中可能包含不安全的程式碼。建議在安裝前仔細檢查 PKGBUILD。",
    "aurFull": "AUR（Arch 使用者軟體源）",
    "githubRepoType": "GitHub 倉庫（owner/repo）",
    "bituRepoType": "Bitu / Bitbucket（工作區/倉庫）",
    "errorNameUrlRequired": "名稱和連結/軟體源地址不能為空",
    "searchGithubHint": "搜尋 GitHub 倉庫...",
    "aiHealthSubtitle": "針對您 Arch Linux 的智慧診斷",
    "signInSubtitle": "跨裝置同步應用程式、設定與最愛"
})
