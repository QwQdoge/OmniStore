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
  String get variant => 'バリアント';

  @override
  String get version => 'バージョン';

  @override
  String get ready => '準備完了';

  @override
  String resultsFound(int count) {
    return '$count 件の結果が見つかりました';
  }

  @override
  String get noResults => '結果が見つかりませんでした';

  @override
  String get searching => '検索中...';

  @override
  String get activity => 'アクティビティ';

  @override
  String get category => 'カテゴリー';

  @override
  String get packageManager => 'パッケージマネージャー';

  @override
  String get pacmanOfficial => 'Pacman (公式)';

  @override
  String get aurUser => 'AUR (ユーザー)';

  @override
  String get flatpak => 'Flatpak';

  @override
  String get appImage => 'AppImage';

  @override
  String get sourcePriority => 'ソースの優先順位 (ドラッグして並べ替え)';

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
  String get configSaved => '設定を保存しました';

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
  String get upToDate => 'すべてのアプリは最新です';

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
    return 'OmniStore: $count 件の更新があります';
  }

  @override
  String get trayTooltipUpToDate => 'OmniStore: 最新の状態です';

  @override
  String get updateReminders => '更新のリマインダー';

  @override
  String get maintenance => 'メンテナンス';

  @override
  String get updateAllPackages => 'すべてのパッケージを更新';

  @override
  String get includeAurUpdates => '「すべて更新」に AUR を含める';

  @override
  String get resetOnboarding => 'オンボーディングをリセット (ウェルカムページ)';

  @override
  String get resetOnboardingConfirm =>
      'オンボーディングをリセットしてもよろしいですか？次回起動時にウェルカムページが表示されます。';

  @override
  String get checkInterval => '更新確認の間隔 (時間)';

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
  String get allUpdated => 'すべてのアプリは最新です';

  @override
  String get update => '更新';

  @override
  String get enableSystemTray => 'システムトレイを有効にする';

  @override
  String get systemCleaning => 'システムクリーニング';

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
    return 'エクスポート成功: $count 個のパッケージ';
  }

  @override
  String exportFailed(String message) {
    return 'エクスポート失敗: $message';
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
  String get aiSettings => 'AI Assistant Settings';

  @override
  String get aiEnabled => 'Enable AI Assistant';

  @override
  String get aiProvider => 'AI Provider';

  @override
  String get aiEndpoint => 'API Endpoint';

  @override
  String get aiModel => 'Model Name';

  @override
  String get aiApiKey => 'API Key';

  @override
  String get aiProxy => 'Network Proxy (Optional)';

  @override
  String get aiTemperature => 'Temperature (Creativity)';

  @override
  String get aiMaxTokens => 'Max Response Tokens';

  @override
  String get aiTestButton => 'Test AI Connection';

  @override
  String get aiTestSuccess => 'AI connection successful!';

  @override
  String aiTestFailed(String error) {
    return 'AI connection failed: $error';
  }

  @override
  String get aiPromptExplain => 'Explain with AI';

  @override
  String get aiPromptRecommend => 'Ask AI for Recommendation';

  @override
  String get aiPromptError => 'Analyze Error with AI';
}
