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
    "meoArchAccount": "MeoArch Account",
    "signOut": "Sign Out",
    "syncStatus": "Sync Status",
    "syncStatusSubtitle": "Apps and settings are backed up",
    "manageAccount": "Manage Account",
    "manageAccountSubtitle": "Security, MFA, and sessions",
    "signInToMeoArch": "Sign In to MeoArch",
    "signInSubtitle": "Sync your apps, settings, and favorites across devices.",
    "email": "Email",
    "password": "Password",
    "signIn": "Sign In",
    "createAccount": "Create MeoArch Account",
    "continueWithGoogle": "Continue with Google",
    "continueWithGitHub": "Continue with GitHub",
    "enterEmailPassword": "Please enter email and password.",
    "signInFailed": "Sign in failed: {message}",
    "signInError": "Sign in error: {message}"
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
    "aiApiKeyHelper": "Ollama 无需密钥，OpenAI 需填写 sk-xxx",
    "howToGetApiKey": "如何获取 API 密钥？",
    "howToGetApiKeyDesc": "1. Ollama (本地)：直接运行，无需密钥。2. 云端 (OpenAI)：前往官网创建并填写密钥。",
    "gotIt": "知道了",
    "aiOllamaNote": "确保 Ollama 已在后台运行并启用了 OLLAMA_ORIGINS=\"*\" 环境变量。",
    "enterStore": "进入商店",
    "nextStep": "下一步",
    "resetCache": "重置缓存与历史记录",
    "resetCacheDesc": "清空搜索历史与本地推荐缓存",
    "resetCacheConfirm": "将清空搜索历史和推荐缓存。确认继续？",
    "resetting": "正在重置...",
    "resetSuccess": "缓存与历史记录已成功清空",
    "resetFailed": "重置失败: {error}",
    "ollamaLocal": "Ollama (本地)",
    "openaiCompatible": "OpenAI 兼容",
    "googleGemini": "Google Gemini",
    "installationDecisionTitle": "安装决策助手",
    "recommendedSource": "推荐来源：{source}",
    "preflightChecks": "安装前检查",
    "potentialRisks": "风险提示",
    "continueInstallation": "继续安装",
    "meoArchAccount": "MeoArch 账户",
    "signOut": "退出登录",
    "syncStatus": "同步状态",
    "syncStatusSubtitle": "应用和设置已备份",
    "manageAccount": "管理账户",
    "manageAccountSubtitle": "安全、多因素认证（MFA）及会话管理",
    "signInToMeoArch": "登录 MeoArch 账户",
    "signInSubtitle": "跨设备同步您的应用、设置及收藏項目。",
    "email": "邮箱",
    "password": "密码",
    "signIn": "登录",
    "createAccount": "创建 MeoArch 账户",
    "continueWithGoogle": "使用 Google 登录",
    "continueWithGitHub": "使用 GitHub 登录",
    "enterEmailPassword": "请输入邮箱和密码。",
    "signInFailed": "登录失败: {message}",
    "signInError": "登录出错: {message}"
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
    "sourceConfigTitle": "軟體存放庫設定",
    "sourceConfigSubtitle": "選擇要啟用的軟體存放庫",
    "enableAur": "啟用 AUR (Arch User Repository)",
    "yayDesc": "啟用 AUR 需要安裝 yay 助手。",
    "aurWarning": "安全警告：AUR 套件由社群使用者貢獻，請確保信任其來源。",
    "bootstrapNote": "注意：配置過程可能需要多次輸入管理員密碼。",
    "feedbackDesc": "透過 GitHub 回報遇到的問題。",
    "aiAssistant": "AI 助手",
    "aiAssistantDesc": "啟用 AI 驅動的搜尋、應用程式解析及錯誤診斷",
    "aiProviderDesc": "選擇 AI 模型來源（本地或雲端）",
    "aiEndpointHelper": "Ollama 預設為 http://localhost:11434",
    "aiApiKeyHelper": "Ollama 無需金鑰，OpenAI 需填寫 sk-xxx",
    "howToGetApiKey": "如何獲取 API 金鑰？",
    "howToGetApiKeyDesc": "1. Ollama (本地)：直接執行，無需金鑰。2. 雲端 (OpenAI)：前往官網建立並填寫金鑰。",
    "gotIt": "知道了",
    "aiOllamaNote": "確保 Ollama 已在背景執行並啟用了 OLLAMA_ORIGINS=\"*\" 環境變數。",
    "enterStore": "進入商店",
    "nextStep": "下一步",
    "resetCache": "重置快取與歷史記錄",
    "resetCacheDesc": "清空搜尋歷史與本地推薦快取",
    "resetCacheConfirm": "將清空搜尋歷史與推薦快取。確認繼續？",
    "resetting": "正在重置...",
    "resetSuccess": "快取與歷史記錄已成功清空",
    "resetFailed": "重置失敗: {error}",
    "ollamaLocal": "Ollama (本地)",
    "openaiCompatible": "OpenAI 相容",
    "googleGemini": "Google Gemini",
    "installationDecisionTitle": "安裝決策助手",
    "recommendedSource": "推薦來源：{source}",
    "preflightChecks": "安裝前檢查",
    "potentialRisks": "風險提示",
    "continueInstallation": "繼續安裝",
    "meoArchAccount": "MeoArch 帳戶",
    "signOut": "登出",
    "syncStatus": "同步狀態",
    "syncStatusSubtitle": "應用程式與設定已備份",
    "manageAccount": "管理帳戶",
    "manageAccountSubtitle": "安全性、多因素驗證（MFA）與工作階段",
    "signInToMeoArch": "登入 MeoArch 帳戶",
    "signInSubtitle": "跨裝置同步您的應用程式、設定與收藏項目。",
    "email": "電子郵件",
    "password": "密碼",
    "signIn": "登入",
    "createAccount": "建立 MeoArch 帳戶",
    "continueWithGoogle": "使用 Google 登入",
    "continueWithGitHub": "使用 GitHub 登入",
    "enterEmailPassword": "請輸入電子郵件和密碼。",
    "signInFailed": "登入失敗: {message}",
    "signInError": "登入出錯: {message}"
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
    "meoArchAccount": "MeoArch アカウント",
    "signOut": "サインアウト",
    "syncStatus": "同期ステータス",
    "syncStatusSubtitle": "アプリと設定がバックアップされています",
    "manageAccount": "アカウント管理",
    "manageAccountSubtitle": "セキュリティ、MFA、セッション",
    "signInToMeoArch": "MeoArch にサインイン",
    "signInSubtitle": "デバイス間でアプリ、設定、お気に入りを同期します。",
    "email": "メールアドレス",
    "password": "パスワード",
    "signIn": "サインイン",
    "createAccount": "MeoArch アカウントを作成",
    "continueWithGoogle": "Google で続行",
    "continueWithGitHub": "GitHub で続行",
    "enterEmailPassword": "メールアドレスとパスワードを入力してください。",
    "signInFailed": "サインイン失敗: {message}",
    "signInError": "サインインエラー: {message}"
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
    "meoArchAccount": "Cuenta de MeoArch",
    "signOut": "Cerrar sesión",
    "syncStatus": "Estado de sincronización",
    "syncStatusSubtitle": "Las aplicaciones y ajustes están respaldados",
    "manageAccount": "Gestionar cuenta",
    "manageAccountSubtitle": "Seguridad, MFA y sesiones",
    "signInToMeoArch": "Iniciar sesión en MeoArch",
    "signInSubtitle": "Sincroniza tus aplicaciones, ajustes y favoritos en todos tus dispositivos.",
    "email": "Correo electrónico",
    "password": "Contraseña",
    "signIn": "Iniciar sesión",
    "createAccount": "Crear cuenta de MeoArch",
    "continueWithGoogle": "Continuar con Google",
    "continueWithGitHub": "Continuar con GitHub",
    "enterEmailPassword": "Por favor, introduce tu correo y contraseña.",
    "signInFailed": "Error al iniciar sesión: {message}",
    "signInError": "Error de inicio de sesión: {message}"
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
