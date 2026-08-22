import json
from collections import OrderedDict
import copy

# Define translations as module-level constants to avoid recreating them on each function call
NEW_KEYS_EN = {
    "welcomeTitle": "Welcome to OmniStore",
    "welcomeSubtitle": "Providing a simple and elegant software management experience for Arch Linux",
    "getStarted": "Get Started",
    "skip": "Skip",
    "envCheckTitle": "Environment Check",
    "envCheckSubtitle": "Ensuring your system is ready",
    "envFatalDesc": "Your system doesn't seem to be Arch-based. Most features will be unavailable.",
    "envWarningDesc": "Some necessary components are missing. We can configure them for you.",
    "envOkDesc": "Everything is ready! Your system is perfect.",
    "fixProblems": "Fix / Configure All",
    "continueAnyway": "Continue Anyway",
    "sourceConfigTitle": "Software Sources",
    "sourceConfigSubtitle": "Choose the sources you want to enable",
    "enableAur": "Enable AUR (Arch User Repository)",
    "yayDesc": "Enabling AUR requires installing the yay helper.",
    "aurWarning": "Security Warning: AUR packages are user-contributed. Ensure you trust the source.",
    "bootstrapNote": "Note: Setup may require entering your password multiple times.",
    "feedbackDesc": "If you encounter issues, please report them on GitHub.",
    "aiAssistant": "AI Assistant",
    "aiAssistantDesc": "Enable AI-powered search, app explanation, and error diagnosis.",
    "aiProviderDesc": "Select your AI model source (Local or Cloud)",
    "aiEndpointHelper": "Ollama defaults to http://localhost:11434",
    "aiApiKeyHelper": "Leave blank for Ollama, enter sk-xxx for OpenAI",
    "howToGetApiKey": "How to get an API key?",
    "howToGetApiKeyDesc": "1. Ollama (Local): Download and run Ollama, no key needed. 2. Cloud (OpenAI): Go to the provider's website, create an API Key, and enter it here.",
    "gotIt": "Got it",
    "aiOllamaNote": "Note: If using Ollama, ensure it's running with OLLAMA_ORIGINS=\"*\".",
    "enterStore": "Enter Store",
    "nextStep": "Next Step",
    "resetCache": "Reset Cache and History",
    "resetCacheDesc": "Clear search history and local recommendations cache",
    "resetCacheConfirm": "This will clear your search history and recommendations cache. Proceed?",
    "resetting": "Resetting...",
    "resetSuccess": "Cache and History cleared successfully",
    "resetFailed": "Reset failed: {error}",
    "ollamaLocal": "Ollama (Local)",
    "openaiCompatible": "OpenAI Compatible",
    "googleGemini": "Google Gemini",
    "installationDecisionTitle": "Installation Decision Helper",
    "recommendedSource": "Recommended Source: {source}",
    "preflightChecks": "Preflight Checks",
    "potentialRisks": "Potential Risks",
    "continueInstallation": "Continue",
    "githubIntegration": "GitHub Integration",
    "configurePat": "Configure Personal Access Token",
    "patHelperText": "Provide a GitHub Classic PAT or Fine-grained Token.",
    "featuredSubtitle": "Maintained by OmniStore, available even offline",
    "editorPicks": "Editor's Choice",
    "checkingEnvStatus": "Checking environment status...",
    "envDetailsFailed": "Failed to fetch environment details.",
    "bootstrapProgress": "Bootstrap progress:",
    "systemDetails": "System details:",
    "aiIntegrationDesc": "Enable intelligence integration features",
    "ollamaLocalOffline": "Ollama (Local / Offline)",
    "openaiCloud": "OpenAI API (Cloud)",
    "testConnection": "Test Connection",
    "githubSearchFailed": "GitHub search failed",
    "githubStoreUnavailable": "GitHub Store unavailable",
    "noGithubReposFound": "No GitHub repositories found",
    "pullToRefreshCategory": "Pull to refresh or try another category."
}

NEW_KEYS_ZH = {
    "welcomeTitle": "欢迎来到 OmniStore",
    "welcomeSubtitle": "提供简单、优雅的 Arch Linux 应用管理体验",
    "getStarted": "开始使用",
    "skip": "跳过",
    "envCheckTitle": "环境检查",
    "envCheckSubtitle": "确保系统已准备就绪",
    "envFatalDesc": "当前系统不是 Arch Linux，核心功能受限。",
    "envWarningDesc": "缺少必要组件，将进行自动配置。",
    "envOkDesc": "系统状态良好，一切就绪！",
    "fixProblems": "一键修复/配置",
    "continueAnyway": "仍然继续",
    "sourceConfigTitle": "软件源配置",
    "sourceConfigSubtitle": "选择要启用的软件源",
    "enableAur": "启用 AUR (Arch User Repository)",
    "yayDesc": "启用 AUR 需要安装 yay 助手。",
    "aurWarning": "安全警告：AUR 软件包由社区用户贡献，请确保信任其来源。",
    "bootstrapNote": "注意：配置过程可能需要多次输入管理员密码。",
    "feedbackDesc": "通过 GitHub 反馈遇到的问题。",
    "aiAssistant": "AI 助手",
    "aiAssistantDesc": "启用 AI 驱动的搜索、应用解析及错误诊断",
    "aiProviderDesc": "选择 AI 模型来源（本地或云端）",
    "aiEndpointHelper": "Ollama 默认为 http://localhost:11434",
    "aiApiKeyHelper": "Ollama 可留空，OpenAI 填写 sk-xxx",
    "howToGetApiKey": "如何获取 API 密钥？",
    "howToGetApiKeyDesc": "1. Ollama（本地）：下载并运行 Ollama，无需密钥；2. 云端（OpenAI）：前往服务商官网创建 API 密钥后在此填入。",
    "gotIt": "知道了",
    "aiOllamaNote": "注意：使用 Ollama 时，请确保其已运行且环境变量配置为 OLLAMA_ORIGINS=\"*\"。",
    "enterStore": "进入商店",
    "nextStep": "下一步",
    "resetCache": "重置缓存与历史记录",
    "resetCacheDesc": "清空搜索历史与本地推荐缓存",
    "resetCacheConfirm": "此操作将清空您的搜索历史与本地推荐缓存。是否继续？",
    "resetting": "正在重置...",
    "resetSuccess": "缓存与历史记录已成功清空",
    "resetFailed": "重置失败: {error}",
    "ollamaLocal": "Ollama (本地)",
    "openaiCompatible": "OpenAI 兼容",
    "googleGemini": "Google Gemini",
    "installationDecisionTitle": "安装决策助手",
    "recommendedSource": "推荐软件源：{source}",
    "preflightChecks": "安装前检查",
    "potentialRisks": "风险提示",
    "continueInstallation": "继续安装",
    "githubIntegration": "GitHub 集成",
    "configurePat": "配置个人访问令牌 (PAT)",
    "patHelperText": "请提供 GitHub Classic PAT 或细粒度 (Fine-grained) 令牌。",
    "featuredSubtitle": "由 OmniStore 维护，离线时也始终可见",
    "editorPicks": "编辑推荐",
    "checkingEnvStatus": "正在检查环境状态...",
    "envDetailsFailed": "获取环境详情失败。",
    "bootstrapProgress": "环境配置进度：",
    "systemDetails": "系统详情：",
    "aiIntegrationDesc": "开启智能集成与辅助功能",
    "ollamaLocalOffline": "Ollama (本地 / 离线)",
    "openaiCloud": "OpenAI API (云端)",
    "testConnection": "测试连接",
    "githubSearchFailed": "GitHub 搜索失败",
    "githubStoreUnavailable": "GitHub 商店暂不可用",
    "noGithubReposFound": "未找到 GitHub 软件仓库",
    "pullToRefreshCategory": "下拉刷新或尝试其他分类。"
}

NEW_KEYS_ZH_HANT = {
    "welcomeTitle": "歡迎來到 OmniStore",
    "welcomeSubtitle": "提供簡單、優雅的 Arch Linux 應用程式管理體驗",
    "getStarted": "開始使用",
    "skip": "跳過",
    "envCheckTitle": "環境檢查",
    "envCheckSubtitle": "確保系統已準備就緒",
    "envFatalDesc": "系統不是 Arch Linux，核心功能受限。",
    "envWarningDesc": "缺少必要組件，將進行自動配置。",
    "envOkDesc": "系統狀態良好，一切就緒！",
    "fixProblems": "一鍵修復/配置",
    "continueAnyway": "仍然繼續",
    "sourceConfigTitle": "軟體源設定",
    "sourceConfigSubtitle": "選擇要啟用的軟體源",
    "enableAur": "啟用 AUR (Arch User Repository)",
    "yayDesc": "啟用 AUR 需要安裝 yay 助手。",
    "aurWarning": "安全警告：AUR 套件由社群使用者貢獻，請確保信任其來源。",
    "bootstrapNote": "注意：配置過程可能需要多次輸入管理員密碼。",
    "feedbackDesc": "透過 GitHub 回報遇到的問題。",
    "aiAssistant": "AI 助手",
    "aiAssistantDesc": "啟用 AI 驅動的搜尋、應用程式解析及錯誤診斷",
    "aiProviderDesc": "選擇 AI 模型來源（本地或雲端）",
    "aiEndpointHelper": "Ollama 預設為 http://localhost:11434",
    "aiApiKeyHelper": "Ollama 可留空，OpenAI 填寫 sk-xxx",
    "howToGetApiKey": "如何獲取 API 金鑰？",
    "howToGetApiKeyDesc": "1. Ollama（本地）：下載並執行 Ollama，無需金鑰；2. 雲端（OpenAI）：前往服務商官網建立 API 金鑰後在此填入。",
    "gotIt": "知道了",
    "aiOllamaNote": "注意：使用 Ollama 時，請確保其已執行且環境變數設定為 OLLAMA_ORIGINS=\"*\"。",
    "enterStore": "進入商店",
    "nextStep": "下一步",
    "resetCache": "重置快取與歷史記錄",
    "resetCacheDesc": "清空搜尋歷史與本地推薦快取",
    "resetCacheConfirm": "此操作將清空您的搜尋歷史與本地推薦快取。是否繼續？",
    "resetting": "正在重置...",
    "resetSuccess": "快取與歷史記錄已成功清空",
    "resetFailed": "重置失敗: {error}",
    "ollamaLocal": "Ollama (本地)",
    "openaiCompatible": "OpenAI 相容",
    "googleGemini": "Google Gemini",
    "installationDecisionTitle": "安裝決策助手",
    "recommendedSource": "推薦軟體源：{source}",
    "preflightChecks": "安裝前檢查",
    "potentialRisks": "風險提示",
    "continueInstallation": "繼續安裝",
    "githubIntegration": "GitHub 整合",
    "configurePat": "設定個人存取權標（PAT）",
    "patHelperText": "請提供 GitHub Classic PAT 或細粒度（Fine-grained）權標。",
    "featuredSubtitle": "由 OmniStore 維護，離線時也始終可見",
    "editorPicks": "編輯推薦",
    "checkingEnvStatus": "正在檢查環境狀態...",
    "envDetailsFailed": "取得環境詳細資訊失敗。",
    "bootstrapProgress": "環境設定進度：",
    "systemDetails": "系統詳細資訊：",
    "aiIntegrationDesc": "開啟智慧整合與輔助功能",
    "ollamaLocalOffline": "Ollama (本地 / 離線)",
    "openaiCloud": "OpenAI API (雲端)",
    "testConnection": "測試連線",
    "githubSearchFailed": "GitHub 搜尋失敗",
    "githubStoreUnavailable": "GitHub 商店暫不可用",
    "noGithubReposFound": "未找到 GitHub 程式碼儲存庫",
    "pullToRefreshCategory": "下拉重新整理或嘗試其他分類。"
}

NEW_KEYS_JA = {
    "welcomeTitle": "OmniStore へようこそ",
    "welcomeSubtitle": "Arch Linux のためのシンプルでエレガントなアプリ管理体験を提供します",
    "getStarted": "始める",
    "skip": "スキップ",
    "envCheckTitle": "環境チェック",
    "envCheckSubtitle": "システムの準備が整っていることを確認します",
    "envFatalDesc": "お使いのシステムは Arch ベースではないようです。ほとんどの機能が利用できなくなります。",
    "envWarningDesc": "いくつかの必要なコンポーネントが不足しています。自動的に設定できます。",
    "envOkDesc": "準備完了です！お使いのシステムは完璧です。",
    "fixProblems": "すべて修正 / 設定",
    "continueAnyway": "とにかく続行",
    "sourceConfigTitle": "ソフトウェアソース",
    "sourceConfigSubtitle": "有効にするソースを選択してください",
    "enableAur": "AUR (Arch User Repository) を有効にする",
    "yayDesc": "AUR を有効にするには yay ヘルパーのインストールが必要です。",
    "aurWarning": "セキュリティ警告: AUR パッケージはユーザーによって提供されています。ソースを信頼できることを確認してください。",
    "bootstrapNote": "注意: セットアップにはパスワードの入力が数回必要な場合があります。",
    "feedbackDesc": "問題が発生した場合は、GitHub で報告してください。",
    "aiAssistant": "AI アシスタント",
    "aiAssistantDesc": "AI による検索補助、アプリの説明、エラー診断を有効にします。",
    "aiProviderDesc": "AI モデルのソースを選択してください (ローカルまたはクラウド)",
    "aiEndpointHelper": "Ollama のデフォルトは http://localhost:11434 です",
    "aiApiKeyHelper": "Ollama の場合は空欄、OpenAI の場合は sk-xxx を入力してください",
    "howToGetApiKey": "API キーを取得するには？",
    "howToGetApiKeyDesc": "1. Ollama (ローカル): Ollama をダウンロードして実行します。キーは不要です。2. クラウド (OpenAI): プロバイダーのウェブサイトで API キーを作成し、ここに入力します。",
    "gotIt": "了解",
    "aiOllamaNote": "注意: Ollama を使用する場合は、OLLAMA_ORIGINS=\"*\" で実行されていることを確認してください。",
    "enterStore": "ストアに入る",
    "nextStep": "次へ",
    "resetCache": "キャッシュと履歴をリセット",
    "resetCacheDesc": "検索履歴とローカルのおすすめキャッシュをクリアします",
    "resetCacheConfirm": "検索履歴とおすすめキャッシュがクリアされます。続行しますか？",
    "resetting": "リセット中...",
    "resetSuccess": "キャッシュと履歴が正常にクリアされました",
    "resetFailed": "リセットに失敗しました: {error}",
    "ollamaLocal": "Ollama (ローカル)",
    "openaiCompatible": "OpenAI 互換",
    "googleGemini": "Google Gemini",
    "installationDecisionTitle": "インストール決定ヘルパー",
    "recommendedSource": "推奨ソース: {source}",
    "preflightChecks": "事前チェック",
    "potentialRisks": "潜在的なリスク",
    "continueInstallation": "インストールを続行",
    "githubIntegration": "GitHub 連携",
    "configurePat": "個人アクセストークンの設定",
    "patHelperText": "GitHub Classic PAT または Fine-grained トークンを入力してください。",
    "featuredSubtitle": "OmniStore が管理、オフラインでも常時表示",
    "editorPicks": "編集部のおすすめ",
    "checkingEnvStatus": "環境状態を確認中...",
    "envDetailsFailed": "環境の詳細情報の取得に失敗しました。",
    "bootstrapProgress": "セットアップ進捗：",
    "systemDetails": "システム詳細：",
    "aiIntegrationDesc": "AI 連携機能を有効化",
    "ollamaLocalOffline": "Ollama (ローカル / オフライン)",
    "openaiCloud": "OpenAI API (クラウド)",
    "testConnection": "接続テスト",
    "githubSearchFailed": "GitHub 検索に失敗しました",
    "githubStoreUnavailable": "GitHub ストアは利用できません",
    "noGithubReposFound": "GitHub リポジトリが見つかりません",
    "pullToRefreshCategory": "スワイプして更新するか、別のカテゴリーをお試しください。"
}

NEW_KEYS_ES = {
    "welcomeTitle": "Bienvenido a OmniStore",
    "welcomeSubtitle": "Ofreciendo una experiencia de gestión de aplicaciones simple y elegante para Arch Linux",
    "getStarted": "Comenzar",
    "skip": "Omitir",
    "envCheckTitle": "Comprobación del entorno",
    "envCheckSubtitle": "Asegurando que su sistema esté listo",
    "envFatalDesc": "Su sistema no parece estar basado en Arch. La mayoría de las funciones no estarán disponibles.",
    "envWarningDesc": "Faltan algunos componentes necesarios. Podemos configurarlos por usted.",
    "envOkDesc": "¡Todo listo! Su sistema es perfecto.",
    "fixProblems": "Corregir / Configurar todo",
    "continueAnyway": "Continuar de todos modos",
    "sourceConfigTitle": "Fuentes de software",
    "sourceConfigSubtitle": "Elija las fuentes que desea habilitar",
    "enableAur": "Activar AUR (Arch User Repository)",
    "yayDesc": "Activar AUR requiere instalar el asistente yay.",
    "aurWarning": "Advertencia de seguridad: Los paquetes AUR son contribuciones de usuarios. Asegúrese de confiar en la fuente.",
    "bootstrapNote": "Nota: La configuración puede requerir introducir su contraseña varias veces.",
    "feedbackDesc": "Si encuentra problemas, por favor infórmenos en GitHub.",
    "aiAssistant": "Asistente de IA",
    "aiAssistantDesc": "Activar búsqueda asistida por IA, explicación de aplicaciones y diagnóstico de errores.",
    "aiProviderDesc": "Seleccione su fuente de modelo de IA (Local o Nube)",
    "aiEndpointHelper": "Ollama por defecto es http://localhost:11434",
    "aiApiKeyHelper": "Dejar en blanco para Ollama, introducir sk-xxx para OpenAI",
    "howToGetApiKey": "¿Cómo obtener una clave API?",
    "howToGetApiKeyDesc": "1. Ollama (Local): Descargue y ejecute Ollama, no se necesita clave. 2. Nube (OpenAI): Vaya al sitio web del proveedor, cree una clave API e introdúzcala aquí.",
    "gotIt": "Entendido",
    "aiOllamaNote": "Nota: Si usa Ollama, asegúrese de que se esté ejecutando con OLLAMA_ORIGINS=\"*\".",
    "enterStore": "Entrar a la tienda",
    "nextStep": "Siguiente paso",
    "resetCache": "Restablecer caché e historial",
    "resetCacheDesc": "Limpiar el historial de búsqueda y el caché de recomendaciones locales",
    "resetCacheConfirm": "Esto borrará su historial de búsqueda y el caché de recomendaciones. ¿Continuar?",
    "resetting": "Restableciendo...",
    "resetSuccess": "Caché e historial borrados con éxito",
    "resetFailed": "Error al restablecer: {error}",
    "ollamaLocal": "Ollama (Local)",
    "openaiCompatible": "Compatible con OpenAI",
    "googleGemini": "Google Gemini",
    "installationDecisionTitle": "Asistente de Decisión de Instalación",
    "recommendedSource": "Fuente Recomendada: {source}",
    "preflightChecks": "Comprobaciones Previas",
    "potentialRisks": "Riesgos Potenciales",
    "continueInstallation": "Continuar Instalación",
    "githubIntegration": "Integración con GitHub",
    "configurePat": "Configurar Token de Acceso Personal",
    "patHelperText": "Proporcione un PAT clásico de GitHub o un Token de grano fino.",
    "featuredSubtitle": "Mantenido por OmniStore, disponible incluso sin conexión",
    "editorPicks": "Selección del editor",
    "checkingEnvStatus": "Comprobando el estado del entorno...",
    "envDetailsFailed": "Error al obtener los detalles del entorno.",
    "bootstrapProgress": "Progreso de configuración:",
    "systemDetails": "Detalles del sistema:",
    "aiIntegrationDesc": "Habilitar funciones de integración inteligente",
    "ollamaLocalOffline": "Ollama (Local / Sin conexión)",
    "openaiCloud": "OpenAI API (Nube)",
    "testConnection": "Probar conexión",
    "githubSearchFailed": "Error en la búsqueda de GitHub",
    "githubStoreUnavailable": "Tienda de GitHub no disponible",
    "noGithubReposFound": "No se encontraron repositorios de GitHub",
    "pullToRefreshCategory": "Deslice hacia abajo para actualizar o pruebe otra categoría."
}

MAPPINGS = {
    'en': NEW_KEYS_EN,
    'zh': NEW_KEYS_ZH,
    'zh_Hant': NEW_KEYS_ZH_HANT,
    'ja': NEW_KEYS_JA,
    'es': NEW_KEYS_ES
}

def load_arb_data(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_arb_data(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def add_placeholder_metadata(data, key, value):
    if '{count}' in value:
        data[f'@{key}'] = {"placeholders": {"count": {"type": "int"}}}
    elif '{name}' in value:
        data[f'@{key}'] = {"placeholders": {"name": {"type": "String"}}}
    elif '{source}' in value:
        data[f'@{key}'] = {"placeholders": {"source": {"type": "String"}}}
    elif '{message}' in value:
        data[f'@{key}'] = {"placeholders": {"message": {"type": "String"}}}
    elif '{error}' in value:
        data[f'@{key}'] = {"placeholders": {"error": {"type": "String"}}}
    else:
        data[f'@{key}'] = {"description": f"Description for {key}"}

def merge_new_keys(data, new_keys):
    for k, v in new_keys.items():
        data[k] = v
        add_placeholder_metadata(data, k, v)

def ensure_en_keys_have_metadata(en_data, new_keys):
    for k, v in new_keys.items():
        en_data[k] = v
        if f'@{k}' not in en_data:
             if '{count}' in v:
                en_data[f'@{k}'] = {"placeholders": {"count": {"type": "int"}}}
             elif '{source}' in v:
                en_data[f'@{k}'] = {"placeholders": {"source": {"type": "String"}}}
             else:
                en_data[f'@{k}'] = {"description": f"Description for {k}"}

def sort_keys_by_english(data, en_data):
    sorted_keys = list(en_data.keys())
    ordered_data = OrderedDict()
    for k in sorted_keys:
        if k in data:
            ordered_data[k] = data[k]
        elif k in en_data: # Fallback to English if missing in target
            ordered_data[k] = en_data[k]
    return ordered_data


def update_arb(lang):
    path = f'FlutterUI/lib/l10n/app_{lang}.arb'
    data = load_arb_data(path)

    # Use a copy so we don't accidentally modify the MAPPINGS constant
    new_keys = copy.deepcopy(MAPPINGS[lang])

    merge_new_keys(data, new_keys)

    # Load English to get the final key order
    en_data = load_arb_data('FlutterUI/lib/l10n/app_en.arb')

    # Ensure all new keys are in en_data for ordering (if we are updating en first)
    if lang == 'en':
        ensure_en_keys_have_metadata(en_data, new_keys)

    # Final sorted keys based on en_data (plus new keys)
    ordered_data = sort_keys_by_english(data, en_data)

    save_arb_data(path, ordered_data)

if __name__ == '__main__':
    for lang in ['en', 'zh', 'zh_Hant', 'ja', 'es']:
        update_arb(lang)
