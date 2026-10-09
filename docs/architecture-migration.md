# OmniStore architecture migration

OmniStore contains one current native desktop client, one current Python backend authority, and one retained legacy Flutter client. The repository layout now reflects those roles directly.

## Current direction

### Current
- `python/`: backend/daemon, source/plugin logic, install/update/search authority and backend tests.
- `src/native-ui/`: current Meo native client direction. New desktop product UI work lands here unless a task explicitly targets legacy compatibility.
- `plugins/sources/`: source manifests consumed by the backend.
- root packaging/release files: current packaging/release authority until they are deliberately reorganized.

### Legacy compatibility
- `legacy/flutter-ui/`: retained historical Flutter client. It remains buildable/testable only where compatibility or provenance still requires it; it is not the preferred target for OmniStore desktop product features and is not part of the normal MeoArch native release bundle.

### Shared/product-neutral boundaries
Reusable Meo controls/tokens/motion belong in MeoUI. Plasma/KWin/system shell behavior belongs in meo-kde. OmniStore consumes those boundaries rather than copying them.

## Repository shape

```text
src/
  native-ui/      # current Qt/QML + MeoUI client
python/            # current backend/daemon authority
legacy/
  flutter-ui/     # historical compatibility client
plugins/
  sources/
docs/
```

The Python backend remains at `python/` for now because its package/test/tooling boundary is already clear and moving it would create mechanical churn without resolving an active ownership ambiguity.

## Migration completed

The client-side structural migration moved:

- `NativeUI/` -> `src/native-ui/`
- `FlutterUI/` -> `legacy/flutter-ui/`

CI, release scripts, contract tests, developer documentation and compatibility localization tools must use the new paths. Do not recreate top-level compatibility copies to satisfy stale path assumptions; fix the stale consumer instead.

## Remaining migration work

1. Keep NativeUI as the default destination for new desktop UI work.
2. Keep release/package paths native-only.
3. Retain legacy Flutter quality checks only while the source remains intentionally maintained.
4. Remove legacy-only localization or build helpers when their supported use case disappears.
5. After at least one supported release train has no Flutter dependency and no maintained consumer remains, archive/delete `legacy/flutter-ui/` in a dedicated cleanup change.

## Parity gate before Flutter retirement

The native client must continue to cover the supported release contract for:

- browsing/searching sources;
- package details and install/remove/update flows;
- source enable/disable and error states;
- history/recommendations where still product requirements;
- accessibility, localization and keyboard operation;
- package/build integration used by MeoArch;
- real backend/daemon communication rather than preview-only data.

A successful native build is not proof of feature parity.

## No split authority

The Python backend remains the authority for store/source operations. Legacy Flutter and the current native client are clients; neither should grow a second package/source engine that diverges from the backend.
