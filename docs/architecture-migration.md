> 📚 [MeoArch 主文档 / Master Doc](https://github.com/QwQdoge/MeoArch-os-workspace/blob/main/docs/MEOARCH_MASTER.md)：全部仓库地图、操作手册、Cloudflare 清单、全部文档链接。<!-- meoarch-master -->

# OmniStore architecture

OmniStore has one native desktop client and one Python backend. The Flutter client and its localization tooling have been removed.

- `python/`: backend/daemon, source/plugin logic, install/update/search authority and backend tests.
- `src/native-ui/`: the Qt/QML + MeoUI client.
- `plugins/sources/`: source manifests (see the sources page on https://meoarch.org/docs/ for the contract).
- root packaging/release files: `PKGBUILD`, `auto_build.py` (backend build helper only), release/export scripts.

Reusable Meo controls/tokens/motion belong in MeoUI. Plasma/KWin/system shell behavior belongs in meo-kde.

Do not recreate `legacy/`, `FlutterUI/` or `NativeUI/`.
