from pathlib import Path

WIDGET = Path("FlutterUI/lib/features/settings/presentation/widgets/meo_channel_card.dart")


def replace_once(old: str, new: str) -> None:
    text = WIDGET.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected one widget match, found {count}: {old[:100]!r}")
    WIDGET.write_text(text.replace(old, new, 1))


replace_once("title: Text(\n          'Switch to Stable',", "title: Text(\n          l10n.switchToStable,")
replace_once(
    "content: Text(\n          'The following official Meo packages need a Stable version. Arch and third-party packages will not be downgraded.\\n\\n$packages',\n        ),",
    "content: Text(l10n.downgradeNotice(packages)),",
)
replace_once("child: const Text('Switch to Stable'),", "child: Text(l10n.switchToStable),")
replace_once("'Meo update channel'", "l10n.meoChannelTitle")
replace_once("'Read from the active pacman repository order'", "l10n.meoChannelSubtitle")
replace_once(
    "? 'Beta receives newer Meo components before Stable. Arch system packages stay on their normal repositories.'\n                  : 'Stable receives fully tested MeoArch release trains.'",
    "? l10n.meoChannelBetaNotice\n                  : l10n.meoChannelStableNotice",
)
replace_once("'Repository priority: $repositories'", "l10n.repoPriority(repositories)")
replace_once(
    "'Beta is opt-in and is not recommended for critical systems. Stable remains the fallback repository.'",
    "l10n.betaWarningPanel",
)
replace_once(
    "'Stable is configured, but ${(state['downgrades'] as List).length} Meo package downgrade(s) still require review.'",
    "l10n.downgradeReviewPending((state['downgrades'] as List).length)",
)
replace_once("label: const Text('Review downgrades'),", "label: Text(l10n.reviewDowngrades),")
replace_once("label: const Text('Stable'),", "label: Text(l10n.channelStable),")
replace_once("label: const Text('Beta'),", "label: Text(l10n.channelBeta),")


def append_entries(filename: str, required_keys: list[str], block: str) -> None:
    path = Path(f"FlutterUI/lib/l10n/{filename}")
    text = path.read_text()
    for key in required_keys:
        if f'"{key}"' in text:
            raise SystemExit(f"{filename}: key already exists: {key}")
    marker = "\n}"
    idx = text.rfind(marker)
    if idx < 0:
        raise SystemExit(f"{filename}: root closing brace not found")
    path.write_text(text[:idx] + ",\n" + block + text[idx:])


keys = [
    "meoChannelTitle",
    "meoChannelSubtitle",
    "meoChannelBetaNotice",
    "meoChannelStableNotice",
    "repoPriority",
    "betaWarningPanel",
    "downgradeReviewPending",
    "reviewDowngrades",
    "switchToStable",
    "downgradeNotice",
    "channelStable",
    "channelBeta",
]

append_entries(
    "app_en.arb",
    keys,
    '''  "meoChannelTitle": "Meo Update Channel",\n  "meoChannelSubtitle": "Read from the active pacman repository order",\n  "meoChannelBetaNotice": "Beta receives newer Meo components before Stable. Arch system packages stay on their normal repositories.",\n  "meoChannelStableNotice": "Stable receives fully tested MeoArch release trains.",\n  "repoPriority": "Repository priority: {repos}",\n  "@repoPriority": {\n    "placeholders": {\n      "repos": {\n        "type": "String"\n      }\n    }\n  },\n  "betaWarningPanel": "Beta is opt-in and is not recommended for critical systems. Stable remains the fallback repository.",\n  "downgradeReviewPending": "{count, plural, =1{Stable is configured, but 1 Meo package downgrade still requires review.} other{Stable is configured, but {count} Meo package downgrades still require review.}}",\n  "@downgradeReviewPending": {\n    "placeholders": {\n      "count": {\n        "type": "int"\n      }\n    }\n  },\n  "reviewDowngrades": "Review Downgrades",\n  "switchToStable": "Switch to Stable",\n  "downgradeNotice": "The following official Meo packages need a Stable version. Arch and third-party packages will not be downgraded.\\n\\n{packages}",\n  "@downgradeNotice": {\n    "placeholders": {\n      "packages": {\n        "type": "String"\n      }\n    }\n  },\n  "channelStable": "Stable",\n  "channelBeta": "Beta"''',
)

append_entries(
    "app_es.arb",
    keys,
    '''  "meoChannelTitle": "Canal de actualización de Meo",\n  "meoChannelSubtitle": "Leído desde el orden de repositorios activo de pacman",\n  "meoChannelBetaNotice": "Beta recibe componentes de Meo más recientes antes que Stable. Los paquetes del sistema Arch permanecen en sus repositorios habituales.",\n  "meoChannelStableNotice": "Stable recibe trenes de publicación de MeoArch totalmente probados.",\n  "repoPriority": "Prioridad de repositorios: {repos}",\n  "betaWarningPanel": "Beta es opcional y no se recomienda para sistemas críticos. Stable sigue siendo el repositorio de respaldo.",\n  "downgradeReviewPending": "Stable está configurado, pero {count} degradación(es) de paquetes Meo aún requieren revisión.",\n  "reviewDowngrades": "Revisar degradaciones",\n  "switchToStable": "Cambiar a Stable",\n  "downgradeNotice": "Los siguientes paquetes oficiales de Meo necesitan una versión Stable. Los paquetes de Arch y de terceros no se degradarán.\\n\\n{packages}",\n  "channelStable": "Stable",\n  "channelBeta": "Beta"''',
)

append_entries(
    "app_ja.arb",
    keys,
    '''  "meoChannelTitle": "Meo 更新チャンネル",\n  "meoChannelSubtitle": "アクティブな pacman リポジトリの順序から読み込み",\n  "meoChannelBetaNotice": "Beta は Stable よりも前に新しい Meo コンポーネントを受信します。Arch システムパッケージは通常のリポジトリに維持されます。",\n  "meoChannelStableNotice": "Stable は完全にテストされた MeoArch リリースを受信します。",\n  "repoPriority": "リポジトリの優先順位: {repos}",\n  "betaWarningPanel": "Beta はオプトインであり、クリティカルなシステムには推奨されません。Stable がフォールバックリポジトリとして機能します。",\n  "downgradeReviewPending": "Stable が設定されていますが、{count} 件の Meo パッケージのダウングレードに確認が必要です。",\n  "reviewDowngrades": "ダウングレードを確認",\n  "switchToStable": "Stable に切り替え",\n  "downgradeNotice": "以下の公式 Meo パッケージは Stable バージョンが必要です。Arch およびサードパーティパッケージはダウングレードされません。\\n\\n{packages}",\n  "channelStable": "Stable",\n  "channelBeta": "Beta"''',
)

append_entries(
    "app_zh.arb",
    keys,
    '''  "meoChannelTitle": "Meo 更新通道",\n  "meoChannelSubtitle": "从当前 pacman 软件源顺序读取",\n  "meoChannelBetaNotice": "Beta 通道可优先体验最新的 Meo 组件。Arch 系统软件包仍保持默认软件源。",\n  "meoChannelStableNotice": "Stable 通道接收经过完整测试的 MeoArch 稳定发布版本。",\n  "repoPriority": "软件源优先级：{repos}",\n  "betaWarningPanel": "Beta 为手动开启选项，不建议在生产环境或关键系统中使用。Stable 仍为后备软件源。",\n  "downgradeReviewPending": "已配置 Stable 通道，但仍有 {count} 个 Meo 软件包降级项需要审查。",\n  "reviewDowngrades": "审查降级项",\n  "switchToStable": "切换至稳定版",\n  "downgradeNotice": "以下官方 Meo 软件包需要降级至稳定版本。Arch 及第三方软件包不会被降级。\\n\\n{packages}",\n  "channelStable": "稳定版",\n  "channelBeta": "Beta 版"''',
)

append_entries(
    "app_zh_Hant.arb",
    keys,
    '''  "meoChannelTitle": "Meo 更新通道",\n  "meoChannelSubtitle": "從目前 pacman 軟體源順序讀取",\n  "meoChannelBetaNotice": "Beta 通道可優先體驗最新的 Meo 元件。Arch 系統套件仍保持預設軟體源。",\n  "meoChannelStableNotice": "Stable 通道接收經過完整測試的 MeoArch 穩定發行版本。",\n  "repoPriority": "軟體源優先級：{repos}",\n  "betaWarningPanel": "Beta 為手動開啟選項，不建議在生產環境或關鍵系統中使用。Stable 仍為後備軟體源。",\n  "downgradeReviewPending": "已設定 Stable 通道，但仍有 {count} 個 Meo 套件降級項需要審查。",\n  "reviewDowngrades": "審查降級項",\n  "switchToStable": "切換至穩定版",\n  "downgradeNotice": "以下官方 Meo 套件需要降級至穩定版本。Arch 及第三方套件不會被降級。\\n\\n{packages}",\n  "channelStable": "穩定版",\n  "channelBeta": "Beta 版"''',
)
