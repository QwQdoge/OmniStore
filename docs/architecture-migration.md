# OmniStore architecture migration

OmniStore currently contains three implementation generations in one repository. This document makes the intended direction explicit so maintenance does not accidentally treat all clients as equal product authorities.

## Current direction

### Current
- `python/`: backend/daemon, source/plugin logic, install/update/search authority and backend tests.
- `NativeUI/`: current Meo native client direction. New desktop product UI work should land here unless a task explicitly targets legacy compatibility.
- `plugins/sources/`: source manifests consumed by the backend.
- root packaging/release files: current packaging/release authority until they are deliberately reorganized.

### Legacy compatibility
- `FlutterUI/`: retained legacy client during NativeUI migration. It remains buildable/testable while required by release/compatibility contracts, but it is not the preferred target for new OmniStore desktop product features.

### Shared/product-neutral boundaries
Reusable Meo controls/tokens/motion belong in MeoUI. Plasma/KWin/system shell behavior belongs in meo-kde. OmniStore should consume those boundaries rather than copying them.

## Target repository shape

The intended end state is conceptually:

```text
src/
  backend/        # current python backend/daemon authority
  native-ui/      # current Qt/MeoUI client
legacy/
  flutter-ui/     # retained only while migration/release compatibility requires it
plugins/
  sources/
packaging/
  arch/
docs/
tests/
```

This document does **not** authorize an immediate path move. Current CI, PKGBUILD and developer commands refer directly to `python/`, `NativeUI/` and `FlutterUI/`; moving them before those contracts are prepared would create churn without product value.

## Migration sequence

1. Treat NativeUI as the default destination for new desktop UI work.
2. Track feature parity explicitly; do not infer parity from visual similarity.
3. Remove packaging/runtime dependence on FlutterUI where no longer needed.
4. Update CI and developer scripts so paths are not duplicated across many files.
5. Only then perform an atomic directory move to `src/` / `legacy/` and update build/package references in the same change.
6. After at least one release train no longer consumes FlutterUI, archive/delete it in a dedicated cleanup change if no supported consumer remains.

## Parity gate before Flutter retirement

NativeUI must cover the supported release contract for:

- browsing/searching sources;
- package details and install/remove/update flows;
- source enable/disable and error states;
- history/recommendations where still product requirements;
- accessibility, localization and keyboard operation;
- package/build integration used by MeoArch;
- real backend/daemon communication rather than preview-only data.

A successful NativeUI build is not proof of feature parity.

## No split authority

The Python backend remains the authority for store/source operations during this migration. FlutterUI and NativeUI are clients; neither should grow a second package/source engine that diverges from the backend.
