# Pull Request Description

## What
Refined localized translations for Simplified Chinese (`zh`) and Traditional Chinese (`zh_Hant`) in `app_zh.arb`, `app_zh_Hant.arb`, `polish_l10n.py`, and `update_arb.py`. Corrected stiff and literal translations, removed redudant filler expressions, unified critical terms across the application (e.g., standardizing repository/source to "软件源/軟體源", "仓库/倉庫"), and resolved pre-existing compiler / layout conflict issues.

## Localization Review Result

| 类别 (漏翻/优化/术语统一) | 原始文本 (Source) | 旧翻译 (Current) | 优化后翻译 (Optimized) | 修改原因 (Reason) |
| :--- | :--- | :--- | :--- | :--- |
| 术语统一 | repository / repositories | 软件存放库 | 软件源 | 统一软件源翻译，避免直翻“存放库”显得生硬、别扭。 |
| 术语统一 | recommendedSource | 推荐来源：{source} | 推荐软件源：{source} | 与软件源专有名词统一，使之更为精确、易懂。 |
| 术语统一 | recommendedSource (Hant) | 推薦來源：{source} | 推薦軟體源：{source} | 與繁體中文軟體源專有名詞相統一，維持全域術語一致性。 |
| 术语统一 | Github Repository (Hant) | GitHub 存放庫 | GitHub 倉庫 | 倉庫為繁體中文下對 GitHub repo 的標準/地道業界翻譯。 |
| 优化 | aiPickDisclaimer | 根据你的搜索、安装历史和当前可用软件源生成；不会影响安装选择。 | 条件可用。推荐基于您的使用习惯和当前配置生成，不会影响具体安装选项。 | 遵循 OmniStore 本地化術語標準，移除 stiff 句式，達到出版級流暢度。 |
| 优化 | aiPickDisclaimer (Hant) | 根據您的搜尋、安裝歷史和當前可用來源生成；不會影響安裝選擇。 | 條件可用。推薦基於您的使用習慣和當前配置生成，不會影響具體安裝選項。 | 遵循 OmniStore 本地化術語標準與繁體中文（使用標準字「後」），消除語義割裂。 |
| 优化 | envFatalDesc | 当前系统不是 Arch Linux，核心功能受限。 | 当前系统并非基于 Arch Linux，大部分功能将不可用。 | 精确匹配 isn't Arch-based 的原意，消除“似乎”等口语化填充词，字句更精炼、大气。 |
| 优化 | envFatalDesc (Hant) | 系統不是 Arch Linux，核心功能受限。 | 系統並非基於 Arch Linux，大部分功能將不可用。 | 消除直翻生硬感，準確傳達 Arch-based 原意。 |
| 优化 | envWarningDesc | 缺少必要组件，将进行自动配置。 | 缺少部分必要组件，我们可以为您进行自动配置。 | 精简多余表达，使语气更加亲切、专业。 |
| 优化 | envWarningDesc (Hant) | 缺少必要組件，將進行自動配置。 | 缺少部分必要組件，我們可以為您進行自動配置。 | 繁體中文語氣優化，增加親和力，消除僵硬的被動語氣。 |
| 漏翻/优化 | noActiveTasks | 暂无活动中的任务 | 暂无进行中的任务 | 纠正 stiff 直译，更符合“进行中任务”这一任务管理器的通用语境。 |

## Coverage
Covered Simplified Chinese and Traditional Chinese, verified by running `flutter gen-l10n` to successfully build localized Dart classes and compiling all UI features successfully.

## Result
Tests and Flutter analyze completed with zero errors and zero warnings.
