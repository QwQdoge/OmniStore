import json
from collections import OrderedDict

def update_arb(lang):
    path = f'FlutterUI/lib/l10n/app_{lang}.arb'
    with open(path, 'r') as f:
        data = json.load(f)

    # New keys for English (Source of Truth)
    new_keys_en = {
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
        "googleGemini": "Google Gemini"
    }

    # Simplified Chinese (zh)
    new_keys_zh = {
        "welcomeTitle": "欢迎来到 OmniStore",
        "welcomeSubtitle": "为您提供简单、优雅的 Arch Linux 应用管理体验",
        "getStarted": "开始使用",
        "skip": "跳过",
        "envCheckTitle": "环境检查",
        "envCheckSubtitle": "我们需要确保您的系统已准备就绪",
        "envFatalDesc": "您的系统似乎不是基于 Arch 的，这会导致大部分功能不可用。",
        "envWarningDesc": "缺少一些必要的组件，我们可以为您自动配置。",
        "envOkDesc": "一切就绪！您的系统非常完美。",
        "fixProblems": "一键修复/配置",
        "continueAnyway": "仍然继续",
        "sourceConfigTitle": "应用源配置",
        "sourceConfigSubtitle": "选择您想要启用的应用来源",
        "enableAur": "启用 AUR (Arch User Repository)",
        "yayDesc": "启用 AUR 需要安装 yay 助手。",
        "aurWarning": "安全警告：AUR 包由用户上传，请确保您信任包的来源。",
        "bootstrapNote": "注意：配置过程可能需要多次输入管理员密码。",
        "feedbackDesc": "如果您遇到问题，请通过 GitHub 反馈给我们。",
        "aiAssistant": "AI 助手",
        "aiAssistantDesc": "开启 AI 辅助搜索、应用解释与错误诊断。",
        "aiProviderDesc": "选择您的 AI 模型来源 (本地或云端)",
        "aiEndpointHelper": "Ollama 默认为 http://localhost:11434",
        "aiApiKeyHelper": "如果是 Ollama 则留空，OpenAI 请填入 sk-xxx",
        "howToGetApiKey": "如何获取 API 密钥？",
        "howToGetApiKeyDesc": "1. Ollama (本地): 下载并运行 Ollama，无需密钥。2. 云端 (OpenAI): 前往服务商官网创建 API Key，然后填入此处。",
        "gotIt": "知道了",
        "aiOllamaNote": "提示：如果您使用 Ollama，请确保它已在后台运行并开启了 OLLAMA_ORIGINS=\"*\" 环境变量。",
        "enterStore": "进入商店",
        "nextStep": "下一步",
        "resetCache": "重置缓存与历史记录",
        "resetCacheDesc": "清空搜索历史与本地推荐缓存",
        "resetCacheConfirm": "这将清空您的搜索历史和推荐缓存。是否继续？",
        "resetting": "正在重置...",
        "resetSuccess": "缓存与历史记录已成功清空",
        "resetFailed": "重置失败: {error}",
        "ollamaLocal": "Ollama (本地)",
        "openaiCompatible": "OpenAI 兼容",
        "googleGemini": "Google Gemini"
    }

    # Traditional Chinese (zh_Hant)
    new_keys_zh_hant = {
        "welcomeTitle": "歡迎來到 OmniStore",
        "welcomeSubtitle": "為您提供簡單、優雅的 Arch Linux 應用程式管理體驗",
        "getStarted": "開始使用",
        "skip": "跳過",
        "envCheckTitle": "環境檢查",
        "envCheckSubtitle": "我們需要確保您的系統已準備就緒",
        "envFatalDesc": "您的系統似乎不是基於 Arch 的，這會導致大部分功能不可用。",
        "envWarningDesc": "缺少一些必要的組件，我們可以為您自動配置。",
        "envOkDesc": "一切就緒！您的系統非常完美。",
        "fixProblems": "一鍵修復/配置",
        "continueAnyway": "仍然繼續",
        "sourceConfigTitle": "應用程式來源配置",
        "sourceConfigSubtitle": "選擇您想要啟用的應用程式來源",
        "enableAur": "啟用 AUR (Arch User Repository)",
        "yayDesc": "啟用 AUR 需要安裝 yay 助手。",
        "aurWarning": "安全警告：AUR 套件由使用者上傳，請確保您信任套件的來源。",
        "bootstrapNote": "注意：配置過程可能需要多次輸入管理員密碼。",
        "feedbackDesc": "如果您遇到問題，請透過 GitHub 反饋給我們。",
        "aiAssistant": "AI 助手",
        "aiAssistantDesc": "開啟 AI 輔助搜尋、應用程式說明與錯誤診斷。",
        "aiProviderDesc": "選擇您的 AI 模型來源 (本地或雲端)",
        "aiEndpointHelper": "Ollama 預設為 http://localhost:11434",
        "aiApiKeyHelper": "如果是 Ollama 則留空，OpenAI 請填入 sk-xxx",
        "howToGetApiKey": "如何獲取 API 金鑰？",
        "howToGetApiKeyDesc": "1. Ollama (本地): 下載並執行 Ollama，無需金鑰。2. 雲端 (OpenAI): 前往服務商官網建立 API Key，然後填入此處。",
        "gotIt": "知道了",
        "aiOllamaNote": "提示：如果您使用 Ollama，請確保它已在背景執行並開啟了 OLLAMA_ORIGINS=\"*\" 環境變數。",
        "enterStore": "進入商店",
        "nextStep": "下一步",
        "resetCache": "重置快取與歷史記錄",
        "resetCacheDesc": "清空搜尋歷史與本地推薦快取",
        "resetCacheConfirm": "這將清空您的搜尋歷史和推薦快取。是否繼續？",
        "resetting": "正在重置...",
        "resetSuccess": "快取與歷史記錄已成功清空",
        "resetFailed": "重置失敗: {error}",
        "ollamaLocal": "Ollama (本地)",
        "openaiCompatible": "OpenAI 相容",
        "googleGemini": "Google Gemini"
    }

    # Japanese (ja)
    new_keys_ja = {
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
        "googleGemini": "Google Gemini"
    }

    # Spanish (es)
    new_keys_es = {
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
        "googleGemini": "Google Gemini"
    }

    mappings = {
        'en': new_keys_en,
        'zh': new_keys_zh,
        'zh_Hant': new_keys_zh_hant,
        'ja': new_keys_ja,
        'es': new_keys_es
    }

    new_keys = mappings[lang]

    # Update data with new keys
    for k, v in new_keys.items():
        data[k] = v
        # Add placeholder metadata for parameterized strings
        if '{count}' in v:
            data[f'@{k}'] = {"placeholders": {"count": {"type": "int"}}}
        elif '{name}' in v:
            data[f'@{k}'] = {"placeholders": {"name": {"type": "String"}}}
        elif '{message}' in v:
            data[f'@{k}'] = {"placeholders": {"message": {"type": "String"}}}
        elif '{error}' in v:
            data[f'@{k}'] = {"placeholders": {"error": {"type": "String"}}}
        else:
            data[f'@{k}'] = {"description": f"Description for {k}"}

    # Load English to get the final key order
    with open('FlutterUI/lib/l10n/app_en.arb', 'r') as f:
        en_data = json.load(f)

    # Ensure all new keys are in en_data for ordering (if we are updating en first)
    if lang == 'en':
        for k, v in new_keys.items():
            en_data[k] = v
            if f'@{k}' not in en_data:
                 if '{count}' in v:
                    en_data[f'@{k}'] = {"placeholders": {"count": {"type": "int"}}}
                 else:
                    en_data[f'@{k}'] = {"description": f"Description for {k}"}

    # Final sorted keys based on en_data (plus new keys)
    sorted_keys = list(en_data.keys())

    # Build the final ordered dict
    ordered_data = OrderedDict()
    for k in sorted_keys:
        if k in data:
            ordered_data[k] = data[k]
        elif k in en_data: # Fallback to English if missing in target
            ordered_data[k] = en_data[k]

    with open(path, 'w', encoding='utf-8') as f:
        json.dump(ordered_data, f, ensure_ascii=False, indent=2)

for l in ['en', 'zh', 'zh_Hant', 'ja', 'es']:
    update_arb(l)
