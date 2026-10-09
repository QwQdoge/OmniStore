# OmniStore NativeUI

`src/native-ui/` is the canonical Linux/MeoArch frontend for OmniStore. It uses Qt 6 + QML and the shared `MeoUI 1.0` design-system module. It does **not** reimplement package managers, source plugins, update rules, privilege handling, or AI policy.

The long-term MeoArch product direction is defined in:

- `docs/NATIVE_MEOUI_FRONTEND.md`
- `docs/TRANSACTION_RELEASE_CONTRACT.md`

The historical Flutter client now lives under `legacy/flutter-ui/` for compatibility/provenance only. New MeoArch UI work must target this native client rather than adding new Flutter-only product features.

## Ownership boundary

NativeUI owns presentation and local UI state:

- adaptive MeoUI navigation and pages;
- search, recommendations, installed-app, updates, task, settings, and details surfaces;
- explicit confirmation dialogs for install, remove, and update actions;
- parsing the existing backend's structured responses and task stream;
- frontend orchestration of the persistent transaction client/service contract.

The existing Python backend remains authoritative for:

- source discovery and plugin manifests;
- package search metadata and variants;
- install, uninstall, update, launch, and package-manager authentication;
- unified update behavior and Meo channel policy;
- configuration validation and storage reporting;
- package/source security boundaries.

NativeUI invokes the backend with `QProcess` program/argument arrays. It never assembles a shell command from package metadata.

Package mutations are owned by the persistent transaction service rather than the graphical process. Closing and reopening the UI must not silently become package-operation ownership.

## Development build

Use a MeoUI checkout so the native target can validate against the same source used by MeoArch:

```bash
cmake --fresh -S src/native-ui -B ../outputs/omni-store/native-ui-dev \
  -DCMAKE_BUILD_TYPE=Debug \
  -DMEOUI_SOURCE_DIR=/path/to/MeoUI \
  -DOMNISTORE_RELEASE_VERSION=development
cmake --build ../outputs/omni-store/native-ui-dev --parallel
```

For a source-tree run, the bridge resolves `python/main.py` automatically. `OMNISTORE_PYTHON` can select another Python executable. A packaged run prefers `/opt/omnistore/backends/python_server`.

## Linux release bundle

Build the native-only release bundle through:

```bash
python src/native-ui/build_linux_release.py \
  --meoui-source /path/to/MeoUI \
  --version <release-version>
```

`--version` (or `OMNISTORE_VERSION`) is injected into the native executable. Development builds deliberately report `development` instead of carrying a stale hard-coded product version.

The MeoArch release bundle must contain `omnistore-native` and must not contain a Flutter runtime fallback. The legacy Flutter source tree is not copied into the release bundle.

## Current migration boundary

The native frontend covers the primary desktop workflow: Home/recommendations, Search, app details, Installed apps, Updates, live Tasks, package source controls, repository/channel surfaces, and backend/config status.

The UI is a Meo product rather than a one-for-one copy of the historical Flutter information architecture. Runtime source availability/trust/capabilities are read from the backend registry; unavailable platform-specific providers must not be shown as normal working sources.

Flutter-only Account/AI behavior should not automatically be ported. Account behavior should move only where its contract remains relevant, and AI software actions should use the Meo system AI router plus typed OmniStore capabilities rather than creating a second app-local AI architecture.
