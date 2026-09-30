# OmniStore NativeUI

`NativeUI/` is the Linux/MeoArch frontend for OmniStore. It uses Qt 6 + QML and the shared `MeoUI 1.0` design-system module. It does **not** reimplement package managers, source plugins, update rules, privilege handling, or AI policy.

## Ownership boundary

NativeUI owns presentation and local UI state:

- adaptive MeoUI navigation and pages;
- search, recommendations, installed-app, updates, task, settings, and details surfaces;
- explicit confirmation dialogs for install, remove, and update actions;
- parsing the existing backend's JSON responses and `[CALLBACK]` task stream;
- cancellation of the frontend-owned backend process.

The existing Python backend remains authoritative for:

- source discovery and plugin manifests;
- package search metadata and variants;
- install, uninstall, update, launch, and package-manager authentication;
- unified update behavior and Meo channel policy;
- configuration validation and storage reporting;
- any AI or Account flow that requires its existing consent/security contract.

NativeUI invokes the backend with `QProcess` program/argument arrays. It never assembles a shell command from package metadata.

## Development build

Use a MeoUI checkout so the native target can validate against the same source used by MeoArch:

```bash
cmake --fresh -S NativeUI -B ../outputs/omni-store/native-ui-dev \
  -DCMAKE_BUILD_TYPE=Debug \
  -DMEOUI_SOURCE_DIR=/path/to/MeoUI
cmake --build ../outputs/omni-store/native-ui-dev --parallel
```

For a source-tree run, the bridge resolves `python/main.py` automatically. `OMNISTORE_PYTHON` can select another Python executable. A packaged run prefers `/opt/omnistore/backends/python_server`.

## Linux release bundle

The existing `auto_build.py` remains responsible for the backend and Flutter fallback. Build the MeoArch/Linux bundle through:

```bash
python NativeUI/build_linux_release.py \
  --meoui-source /path/to/MeoUI
```

The script first assembles the normal Linux release, then overlays `omnistore-native` and a `data/native-ui-v1` marker. It refuses to overlay a bundle missing the existing `frontend`, `backends/python_server`, or project license.

`PKGBUILD` prefers `/opt/omnistore/omnistore-native` when the shared `/usr/lib/qt6/qml/MeoUI/qmldir` module exists. Otherwise it executes the Flutter `frontend`. This fallback is intentional during migration and should not be removed until the native frontend reaches feature parity and end-to-end release validation.

## Current migration boundary

The native frontend currently covers the primary desktop workflow: Home/recommendations, Search, app details, Installed apps, Updates, live Tasks, package source toggles, and read-only backend/config status. Existing Flutter-only Account/AI and less-common repository-management surfaces remain fallback territory until their security and interaction contracts are ported explicitly.
