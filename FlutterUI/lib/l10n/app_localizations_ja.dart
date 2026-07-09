// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get searchHint => 'アプリ、ゲーム、ツールを検索...';

  @override
  String get featured => 'おすすめ';

  @override
  String get forYou => 'あなたへのおすすめ';

  @override
  String get essentialTools => '必須ツール';

  @override
  String get hotApps => '注目のアプリ';

  @override
  String get explore => '探索';

  @override
  String get search => '検索';

  @override
  String get settings => '設定';

  @override
  String get downloads => 'ダウンロード';

  @override
  String get help => 'ヘルプ';

  @override
  String get userAccount => 'ユーザーアカウント';

  @override
  String get install => 'インストール';

  @override
  String get open => '開く';

  @override
  String get uninstall => 'アンインストール';

  @override
  String get launch => '起動';

  @override
  String get about => 'このアプリについて';

  @override
  String get details => '詳細';

  @override
  String get source => 'ソース';

  @override
  String get variant => '利用可能なバージョン';

  @override
  String get version => 'バージョン';

  @override
  String get ready => 'インストール済み';

  @override
  String resultsFound(int count) {
    return '$count 件の結果';
  }

  @override
  String get noResults => '検索結果が見つかりませんでした';

  @override
  String get searching => '検索中...';

  @override
  String get activity => 'タスク履歴';

  @override
  String get category => 'カテゴリー';

  @override
  String get packageManager => 'パッケージマネージャー';

  @override
  String get pacmanOfficial => 'Pacman（公式リポジトリ）';

  @override
  String get aurUser => 'AUR（ユーザーリポジトリ）';

  @override
  String get flatpak => 'Flatpak';

  @override
  String get appImage => 'AppImage';

  @override
  String get sourcePriority => 'ソースの優先順位（ドラッグして並べ替え）';

  @override
  String get maxResults => '最大結果数';

  @override
  String get appearance => '外観';

  @override
  String get themeColor => 'テーマカラー';

  @override
  String get followSystem => 'システムに従う';

  @override
  String get lightMode => 'ライトモード';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get loggingLevel => 'ログレベル';

  @override
  String get saveAndApply => '保存して適用';

  @override
  String get configSaved => '設定を保存しました。一部の変更は再起動後に有効になります';

  @override
  String get configSaveFailed => '設定の保存に失敗しました';

  @override
  String get confirmUninstall => 'アンインストールの確認';

  @override
  String get confirmInstall => 'インストールの確認';

  @override
  String confirmActionMsg(String name) {
    return '$name に対してこの操作を実行してもよろしいですか？';
  }

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String get terminalOutput => 'ターミナル出力';

  @override
  String get waitingForOutput => '出力を待機中...';

  @override
  String get screenshots => 'スクリーンショット';

  @override
  String get developer => '開発者';

  @override
  String get license => 'ライセンス';

  @override
  String get success => '成功';

  @override
  String get failed => '失敗';

  @override
  String get taskCancelled => 'タスクがキャンセルされました';

  @override
  String get catDevelopment => '開発';

  @override
  String get catMedia => 'メディア';

  @override
  String get catInternet => 'インターネット';

  @override
  String get catSystem => 'システム';

  @override
  String get catOffice => 'オフィス';

  @override
  String get catGames => 'ゲーム';

  @override
  String get catGraphics => 'グラフィックス';

  @override
  String get catUtility => 'ユーティリティ';

  @override
  String get systemAndWindow => 'システムとウィンドウ';

  @override
  String get visitWebsite => 'ウェブサイトにアクセス';

  @override
  String get updates => '更新';

  @override
  String get upToDate => 'すべてのアプリは最新バージョンです';

  @override
  String get checkUpdates => '更新を確認';

  @override
  String foundUpdates(int count) {
    return '$count 件の更新が見つかりました';
  }

  @override
  String get updateAll => 'すべて更新';

  @override
  String get notifications => '通知';

  @override
  String get enableNotifications => '通知を有効にする';

  @override
  String get progressNotifications => '進行状況の通知';

  @override
  String get completionNotifications => '完了通知';

  @override
  String get closeToTray => 'システムトレイに閉じる';

  @override
  String get useSystemTitleBar => 'システムのタイトルバーを使用';

  @override
  String get showWindow => 'ウィンドウを表示';

  @override
  String get exit => '終了';

  @override
  String trayTooltipUpdates(int count) {
    return 'OmniStore：$count 件の更新があります';
  }

  @override
  String get trayTooltipUpToDate => 'OmniStore：最新の状態です';

  @override
  String get updateReminders => '更新のリマインダー';

  @override
  String get maintenance => 'メンテナンス';

  @override
  String get updateAllPackages => 'すべてのパッケージを更新';

  @override
  String get includeAurUpdates => '「すべて更新」に AUR を含める';

  @override
  String get resetOnboarding => 'オンボーディングをリセット（ウェルカムページ）';

  @override
  String get resetOnboardingConfirm =>
      'オンボーディングをリセットしてもよろしいですか？次回起動時にウェルカムページが表示されます。';

  @override
  String get checkInterval => '更新確認の間隔（時間）';

  @override
  String get remindMeOfUpdates => '更新を通知する';

  @override
  String installingApp(String name) {
    return '$name をインストール中';
  }

  @override
  String uninstallingApp(String name) {
    return '$name をアンインストール中';
  }

  @override
  String get installSuccessTitle => 'インストールが成功しました';

  @override
  String get uninstallSuccessTitle => 'アンインストールが成功しました';

  @override
  String get installFailedTitle => 'インストールに失敗しました';

  @override
  String get uninstallFailedTitle => 'アンインストールに失敗しました';

  @override
  String get taskCompleted => 'タスクが完了しました';

  @override
  String get searchInstalledHint => 'インストール済みのアプリを検索...';

  @override
  String get refresh => '更新';

  @override
  String get noActiveTasks => 'アクティブなタスクはありません';

  @override
  String get currentTask => '現在のタスク';

  @override
  String get viewLogs => 'ログを表示';

  @override
  String get allUpdated => 'すべてのアプリは最新バージョンです';

  @override
  String get update => '更新';

  @override
  String get enableSystemTray => 'システムトレイを有効にする';

  @override
  String get systemCleaning => 'システムクリーニング';

  @override
  String get systemCleaningDesc => '孤立パッケージの削除と pacman キャッシュのクリーンアップ';

  @override
  String get systemCleaningSubtitle => '孤立したパッケージを削除し、pacman キャッシュをクリーンアップします';

  @override
  String get systemCleaningStarted => 'システムクリーニングタスクが開始されました';

  @override
  String get backupAndExport => 'バックアップとエクスポート';

  @override
  String get backupAndExportSubtitle =>
      '現在のインストール済みアプリリストをエクスポート、またはバックアップからインポート';

  @override
  String get export => 'エクスポート';

  @override
  String get import => 'インポート';

  @override
  String get selectExportLocation => 'エクスポート先を選択';

  @override
  String exportSuccess(int count) {
    return 'エクスポート成功：$count 個のパッケージ';
  }

  @override
  String exportFailed(String message) {
    return 'エクスポート失敗：$message';
  }

  @override
  String get importBackup => 'バックアップをインポート';

  @override
  String importBackupConfirm(int count) {
    return 'バックアップから $count 個のパッケージを読み込みました。一括復元を開始しますか？';
  }

  @override
  String get startRecovery => '復元を開始';

  @override
  String get mirrorListSaved => 'ミラーリストを保存しました';

  @override
  String get addMirror => 'ミラーを追加';

  @override
  String get serverUrl => 'サーバー URL';

  @override
  String get pacmanMirrorManagement => 'Pacman ミラー管理';

  @override
  String get save => '保存';

  @override
  String get add => '追加';

  @override
  String get general => '全般';

  @override
  String get advanced => '詳細設定';

  @override
  String get repositories => 'リポジトリ';

  @override
  String get aiSettings => 'AI アシスタント設定';

  @override
  String get aiEnabled => 'AI アシスタントを有効にする';

  @override
  String get aiEnabledDesc => 'AI を活用した検索、アプリの説明、エラー診断を有効にします。';

  @override
  String get aiProvider => 'AI プロバイダー';

  @override
  String get aiEndpoint => 'API エンドポイント';

  @override
  String get aiModel => 'モデル名';

  @override
  String get aiApiKey => 'API キー';

  @override
  String get aiProxy => 'ネットワークプロキシ（オプション）';

  @override
  String get aiTemperature => '温度（創造性）';

  @override
  String get aiMaxTokens => '最大トークン数';

  @override
  String get aiTestButton => 'AI 接続をテスト';

  @override
  String get aiTestSuccess => 'AI 接続に成功しました！';

  @override
  String aiTestFailed(String error) {
    return 'AI 接続に失敗しました：$error';
  }

  @override
  String get aiPromptExplain => '解析';

  @override
  String get aiPromptRecommend => 'AI おすすめ';

  @override
  String get aiPromptError => 'AI でエラーを分析';

  @override
  String get aiPickDay => '本日の一押し（AI）';

  @override
  String get aiPickDaySubtitle => 'OmniStore AI による提供';

  @override
  String get aiCompareTitle => 'AI バリアント比較';

  @override
  String get aiHealthTitle => 'AI システム健康診断レポート';

  @override
  String get aiHealthSubtitle => 'Arch Linux 向けインテリジェント診断';

  @override
  String get aiCorrection => 'もしかして：';

  @override
  String get aiThinking => 'AI が考え中...';

  @override
  String get magicSearch => 'スマート検索';

  @override
  String get aiChangelogTitle => 'AI 更新サマリー';

  @override
  String get aiCliTitle => 'AI コマンド生成';

  @override
  String get aiConflictTitle => 'AI 競合検出';

  @override
  String get aiCopyCommand => 'コマンドをコピー';

  @override
  String get aiCommandCopied => 'クリップボードにコピーしました';

  @override
  String get aiRefineSearch => 'AI で検索を絞り込む';

  @override
  String get aiExplainUpdate => 'この更新を解析';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '元に戻す';

  @override
  String get windowClose => '閉じる';

  @override
  String get omnistore => 'OmniStore';

  @override
  String get installedApps => 'インストール済みアプリ';

  @override
  String get githubStore => 'GitHub ストア';

  @override
  String get flatpakStore => 'Flatpak ストア';

  @override
  String get locateInstallation => 'インストール先を表示';

  @override
  String get delete => '削除';

  @override
  String get welcomeTitle => 'OmniStore へようこそ';

  @override
  String get welcomeSubtitle => 'Arch Linux のためのシンプルでエレガントなアプリ管理体験を提供します';

  @override
  String get getStarted => '始める';

  @override
  String get skip => 'スキップ';

  @override
  String get envCheckTitle => '環境チェック';

  @override
  String get envCheckSubtitle => 'システムの準備が整っていることを確認します';

  @override
  String get envFatalDesc => 'お使いのシステムは Arch ベースではないようです。ほとんどの機能が利用できなくなります。';

  @override
  String get envWarningDesc => 'いくつかの必要なコンポーネントが不足しています。自動的に設定できます。';

  @override
  String get envOkDesc => '準備完了です！お使いのシステムは完璧です。';

  @override
  String get fixProblems => 'すべて修正 / 設定';

  @override
  String get continueAnyway => 'とにかく続行';

  @override
  String get sourceConfigTitle => 'ソフトウェアソース';

  @override
  String get sourceConfigSubtitle => '有効にするソースを選択してください';

  @override
  String get enableAur => 'AUR（Arch User Repository） を有効にする';

  @override
  String get yayDesc => 'AUR を有効にするには yay ヘルパーのインストールが必要です。';

  @override
  String get aurWarning =>
      'セキュリティ警告：AUR パッケージはユーザーによって提供されています。ソースを信頼できることを確認してください。';

  @override
  String get bootstrapNote => '注意：セットアップにはパスワードの入力が数回必要な場合があります。';

  @override
  String get feedbackDesc => '問題が発生した場合は、GitHub で報告してください。';

  @override
  String get aiAssistant => 'AI アシスタント';

  @override
  String get aiAssistantDesc => 'AI による検索補助、アプリの説明、エラー診断を有効にします。';

  @override
  String get aiProviderDesc => 'AI モデルのソースを選択してください（ローカルまたはクラウド）';

  @override
  String get aiEndpointHelper => 'Ollama のデフォルトは http://localhost:11434 です';

  @override
  String get aiApiKeyHelper => 'Ollama の場合は空欄、OpenAI の場合は sk-xxx を入力してください';

  @override
  String get howToGetApiKey => 'API キーを取得するには？';

  @override
  String get howToGetApiKeyDesc =>
      '1. Ollama（ローカル）：Ollama をダウンロードして実行します。キーは不要です。2. クラウド（OpenAI）：プロバイダーのウェブサイトで API キーを作成し、ここに入力します。';

  @override
  String get gotIt => '了解';

  @override
  String get aiOllamaNote =>
      '注意：Ollama を使用する場合は、OLLAMA_ORIGINS=\"*\" で実行されていることを確認してください。';

  @override
  String get enterStore => 'ストアに入る';

  @override
  String get nextStep => '次へ';

  @override
  String get resetCache => 'キャッシュと履歴をリセット';

  @override
  String get resetCacheDesc => '検索履歴とローカルのおすすめキャッシュをクリアします';

  @override
  String get resetCacheConfirm => '検索履歴とおすすめキャッシュがクリアされます。続行しますか？';

  @override
  String get resetting => 'リセット中...';

  @override
  String get resetSuccess => 'キャッシュと履歴が正常にクリアされました';

  @override
  String resetFailed(String error) {
    return 'リセットに失敗しました：$error';
  }

  @override
  String get ollamaLocal => 'Ollama（ローカル）';

  @override
  String get openaiCompatible => 'OpenAI 互換';

  @override
  String get googleGemini => 'Google Gemini';

  @override
  String get importPackages => 'パッケージをインポート';

  @override
  String importPackagesConfirm(int count) {
    return 'ファイルから $count 個のパッケージを読み込みました。一括ダウンロードを開始しますか？';
  }

  @override
  String get allDownloads => 'すべてダウンロード';

  @override
  String get importList => 'リストをインポート';

  @override
  String get loadError => '推奨コンテンツの読み込みに失敗しました。バックエンドの状態を確認してください';

  @override
  String get community => 'コミュニティ';

  @override
  String get official => '公式';

  @override
  String get verified => '検証済み';

  @override
  String installingPkg(String name) {
    return '$name をインストール中...';
  }

  @override
  String get switchSource => '切り替え';

  @override
  String get flatpakBetterDesc =>
      'このアプリの Flatpak ソースが見つかりました。通常、こちらの方が安定しています。';

  @override
  String get aiAnalysisPrompt => 'エラーログが見つかりました。AI で分析しますか？';

  @override
  String get analyzeNow => '今すぐ分析';

  @override
  String get cleanOrphans => '未使用の依存関係を削除する（孤立したパッケージ）';

  @override
  String get securityWarning => 'セキュリティ警告';

  @override
  String get aurSecurityDesc =>
      'AUR（Arch User Repository） はコミュニティによって維持されているリポジトリです。パッケージはユーザーによって提供されており、安全でないコードが含まれている可能性があります。インストール前に PKGBUILD を確認することをお勧めします。';

  @override
  String get continueInstall => 'インストールを続行';

  @override
  String get installInfo => 'インストール情報';

  @override
  String get downloadSize => 'ダウンロードサイズ';

  @override
  String get installedSize => 'インストール後のサイズ';

  @override
  String dependenciesCount(int count) {
    return '依存関係（$count）';
  }

  @override
  String get runningInBackground =>
      'OmniStore はバックグラウンドで実行中です。トレイアイコンから開くことができます。';

  @override
  String get clearSearch => '検索をクリア';

  @override
  String get listView => 'リスト表示';

  @override
  String get gridView => 'グリッド表示';

  @override
  String get categories => 'カテゴリー';

  @override
  String get clearHistory => '履歴をクリア';

  @override
  String get clearHistoryShort => '履歴をクリア';

  @override
  String get confirmClearHistory => 'すべての履歴を消去してもよろしいですか？';

  @override
  String get viewMore => 'もっと見る';

  @override
  String get logDebug => 'デバッグ（DEBUG）';

  @override
  String get logInfo => '情報（INFO）';

  @override
  String get logWarning => '警告（WARNING）';

  @override
  String get logError => 'エラー（ERROR）';

  @override
  String get notificationTitle => 'アップデートが利用可能です';

  @override
  String notificationBody(int count) {
    return '$count 件のアプリが更新可能です';
  }

  @override
  String get preparingUpdate => '更新を準備中...';

  @override
  String get processing => '処理中';

  @override
  String get clear => 'クリア';

  @override
  String get retry => '再試行';

  @override
  String get aiResponseFailed => 'AI の応答に失敗しました。';

  @override
  String get aiAnalysisFailed => 'AI による分析に失敗しました。';

  @override
  String cannotConnectToBackend(String error) {
    return 'バックエンドサービスに接続できません：$error';
  }

  @override
  String get taskInitializing => 'タスクを初期化中...';

  @override
  String get taskStarting => '起動中...';

  @override
  String get taskSuccess => 'タスクが正常に完了しました';

  @override
  String taskFailedWithCode(int code) {
    return 'タスクが終了コード $code で失敗しました';
  }

  @override
  String get taskCancelledByUser => 'タスクがユーザーによってキャンセルされました';

  @override
  String taskError(String error) {
    return 'エラー：$error';
  }

  @override
  String get githubAuthTitle => 'GitHub 認証';

  @override
  String get githubPatSaved => 'GitHub PAT が正常に保存されました';

  @override
  String get saveToken => 'トークンを保存';

  @override
  String get back => '戻る';

  @override
  String get next => '次へ';

  @override
  String get aurFull => 'AUR（Arch User Repository）';

  @override
  String get flatpakFull => 'Flatpak（Flathub）';

  @override
  String get errorPackageNameRequired => 'エラー：パッケージ名は空にできません';

  @override
  String errorStartFailed(String error) {
    return '起動に失敗しました：$error';
  }

  @override
  String errorUpdateFailed(String error) {
    return '更新に失敗しました：$error';
  }

  @override
  String checkUpdateFailed(String error) {
    return '更新の確認に失敗しました：$error';
  }

  @override
  String errorCleanFailed(String error) {
    return 'クリーンアップに失敗しました：$error';
  }

  @override
  String errorFatalStream(String error) {
    return '致命的なデータストリームエラー：$error';
  }

  @override
  String errorProcessStart(String error) {
    return 'プロセスの起動に失敗しました。環境設定を確認してください：$error';
  }

  @override
  String get taskForcedTerminated => 'タスクが強制終了されました';

  @override
  String get aiTimeout => 'AI 接続がタイムアウトしました。後で再試行してください。';

  @override
  String get aiNoResponse => 'AI が有効な応答を返せませんでした。';

  @override
  String get aiParseFailed => 'AI 応答の解析に失敗しました：形式が正しくありません。';

  @override
  String aiCallFailed(String error) {
    return 'AI サービスの呼び出しに失敗しました：$error';
  }

  @override
  String errorUpdateAll(String error) {
    return '一括更新エラー：$error';
  }

  @override
  String get taskProcessing => '処理中';

  @override
  String get collapse => '折りたたむ';

  @override
  String get expand => '展開';

  @override
  String get all => 'すべて';

  @override
  String get relatedApps => '関連アプリ';

  @override
  String get activeSources => '有効なソース';

  @override
  String get autoDetect => '自動検出';

  @override
  String get addCustomSource => 'カスタムソースを追加';

  @override
  String get addCustomSourceDesc =>
      'カスタム Flatpak リモート、AppImage フィード、または GitHub/Bitu リポジトリを設定します';

  @override
  String get sourceType => 'ソースの種類';

  @override
  String get githubRepoType => 'GitHub リポジトリ（owner/repo）';

  @override
  String get bituRepoType => 'Bitu / Bitbucket（ワークスペース/リポジトリ）';

  @override
  String get flatpakRemoteType => 'Flatpak リモート';

  @override
  String get appImageFeedType => 'AppImage フィード URL';

  @override
  String get sourceName => 'ソース名';

  @override
  String get hintCustomAppName => '例：my-custom-app';

  @override
  String get repoOwnerRepo => 'リポジトリ（owner/repo）';

  @override
  String get sourceUrl => 'URL';

  @override
  String get hintRepoFormat => '例：flutter/flutter';

  @override
  String get hintFeedUrl => '例：https://example.com/feed.json';

  @override
  String get errorNameUrlRequired => '名前と URL/リポジトリは空にできません';

  @override
  String get addingCustomSource => 'カスタムソースを追加中...';

  @override
  String get sourceAddSuccess => 'ソースが正常に追加されました！';

  @override
  String get sourceAddFailed => 'ソースの追加に失敗しました。';

  @override
  String get autoDetectingSources => 'システムで利用可能なソースを自動検出中...';

  @override
  String get autoDetectSuccess => '自動検出が完了し、設定が保存されました！';

  @override
  String get autoDetectFailed => '自動検出設定の保存に失敗しました。';

  @override
  String get personalAccessToken => '個人用アクセストークン';

  @override
  String get copyName => '名前をコピー';

  @override
  String get copiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get tapToCopy => 'タップしてコピー';

  @override
  String get language => '表示言語';

  @override
  String get languageSubtitle => '再起動後に有効になります';

  @override
  String get restartTitleBar => 'タイトルバーの設定を適用するには再起動してください';

  @override
  String get enableDaemon => 'バックグラウンド更新を有効にする';

  @override
  String get enableDaemonDesc => 'バックグラウンドで定期的に更新を確認します';

  @override
  String get autoUpdate => 'サイレント自動更新';

  @override
  String get autoUpdateDesc => 'バックグラウンドでパッケージを自動的に更新します';

  @override
  String get checkIntervalTitle => '更新確認の間隔';

  @override
  String checkIntervalSubtitle(int hours) {
    return '$hours 時間ごとに確認';
  }

  @override
  String get typography => 'フォントとタイポグラフィ';

  @override
  String get fontFamily => 'フォントファミリー';

  @override
  String get fontScale => 'フォントの拡大率';

  @override
  String get systemDefault => 'システム既定';

  @override
  String hourValue(int count) {
    return '$count 時間';
  }

  @override
  String get langSimplifiedChinese => '中国語（簡体字）';

  @override
  String get langTraditionalChinese => '中国語（繁体字）';

  @override
  String get langEnglish => '英語';

  @override
  String get langJapanese => '日本語';

  @override
  String get langSpanish => 'スペイン語';

  @override
  String get taskInProgress => '別のタスクが既に実行中です';

  @override
  String get trayInitFailedDisabled => 'システムトレイの初期化に失敗しました。トレイに閉じる機能は無効になりました。';

  @override
  String get errorTitle => 'エラー';

  @override
  String get appDetailsNotFound => 'アプリの詳細が見つかりませんでした';

  @override
  String diskSpaceInfo(String free, String total) {
    return 'ディスク空間：$free GB 空き / $total GB 合計';
  }

  @override
  String cacheTypeInfo(String pacman, String flatpak, String custom) {
    return 'Pacman：$pacman MB | Flatpak：$flatpak MB | カスタム：$custom MB';
  }

  @override
  String get backSemanticsLabel => '戻る';

  @override
  String get backSemanticsHint => '前の画面に戻る';

  @override
  String categorySemantics(String name) {
    return 'カテゴリー：$name';
  }

  @override
  String get temperatureRangeError => '値は 0.0 から 2.0 の間である必要があります';

  @override
  String get enableSystemdService => 'systemd バックグラウンド更新サービスを有効にする';

  @override
  String get enableSystemdServiceDesc =>
      'アプリが閉じているときに更新をサイレントに確認するため、systemd タイマーの登録を許可します';

  @override
  String get taskHistory => 'タスク履歴';

  @override
  String get unknownApp => '不明なアプリ';

  @override
  String get taskSuccessMsg => 'タスクが正常に実行されました';

  @override
  String failureReason(String message) {
    return '失敗理由：$message';
  }

  @override
  String get noPackagesAvailable => '利用可能なパッケージがありません';

  @override
  String get noDescription => '説明はありません';

  @override
  String get viewDetails => '詳細を表示';

  @override
  String get ok => 'OK';

  @override
  String get checkNetwork => 'ネットワーク接続を確認して、もう一度お試しください';

  @override
  String get githubStoreSubtitle => 'GitHub リリースから直接アプリを見つけてダウンロード';

  @override
  String get searchGithubHint => 'GitHub リポジトリを検索...';

  @override
  String get recommended => 'おすすめ';

  @override
  String get rankings => 'ランキング';

  @override
  String get trending => 'トレンド';

  @override
  String get latestUpdates => '最新の更新';

  @override
  String get searchNoResultsSubtitle => '別のキーワードで検索してみてください';

  @override
  String get pluginsAndSources => 'プラグインとソース';

  @override
  String get refreshPlugins => 'プラグインを更新';

  @override
  String get noPluginsFound => 'プラグインが見つかりません';

  @override
  String get builtin => '組み込み';

  @override
  String get legacy => 'レガシー';

  @override
  String get pluginUpdated => 'プラグインを更新しました';

  @override
  String get pluginUpdateFailed => 'プラグインの更新に失敗しました';

  @override
  String get pluginRemoved => 'プラグインを削除しました';

  @override
  String get pluginRemovalFailed => 'プラグインの削除に失敗しました';

  @override
  String get removePlugin => 'プラグインを削除';

  @override
  String get managed => '管理対象';

  @override
  String get readOnly => '読み取り専用';
}
