# OmniStore agent rules

## Start here

Work only in the owning layer for the task. Inspect `git status`, the affected files, and the nearest relevant tests/contracts before editing; do not scan the whole repository or read every document by default.

Read `docs/architecture-migration.md` before work that touches client architecture, directory layout, Flutter/Native parity, or packaging paths.

## Ownership

- `python/`: **current backend authority** for Python backend, source/plugin logic, daemon mode, and Python tests.
- `NativeUI/`: **current desktop client direction**. New OmniStore desktop UI/product work should target NativeUI unless the task explicitly concerns legacy compatibility.
- `FlutterUI/`: **legacy compatibility client during migration**. Keep it buildable where release/compatibility contracts still require it, but do not add new desktop product features here by default.
- `plugins/sources/`: source manifests. A manifest or toggle alone does not prove search/install/update support.
- `PKGBUILD`, `auto_build.py`, release/export scripts: packaging and release contracts.
- This repository has Python daemon code; it does **not** contain a Rust daemon/Cargo workspace. Do not invent or describe one.

Shared OS/Plasma UI belongs in MeoUI or meo-kde rather than being copied here.

Do not perform a broad `FlutterUI/`/`NativeUI/` path move as incidental cleanup. The target `src/` + `legacy/` layout and migration gates are defined in `docs/architecture-migration.md`; an actual move must update CI, packaging and developer paths atomically.

## Validation matrix

Run the narrowest matching checks first.

- Flutter compatibility change:
  `cd FlutterUI && flutter pub get && flutter analyze && flutter test --reporter expanded`
  Add `flutter build linux --release` when Linux integration, dependencies, packaging, or release behavior changed.
- Python/backend change:
  `cd python && python -m pytest -q`
  If dependencies changed, also install/check `requirements.txt` in an isolated environment.
- NativeUI change:
  mirror `.github/workflows/native-quality.yml`: configure with CMake using a real MeoUI checkout, then build target `omnistore-native`.
- Plugin/source-manifest change: run the directly related Python/plugin tests and verify the claimed operations actually exist.
- Packaging/release change: run the repository's existing contract/export checks; a successful package build is not proof of install/update behavior.

Do not broaden validation to unrelated layers unless the change crosses that boundary.

## Claims and security

Keep capability claims evidence-based. Distinguish source/static tests, local runtime, package build, real installation, and live service behavior.

Never commit credentials, provider secrets, signing material, service-role keys, tokens, or user data. Do not publish packages, change remote package sources, deploy services, or modify a live machine without explicit authorization.

## Files and generated output

Keep source and code-bound contracts in their owning directories. Do not create loose plans, audits, screenshots, logs, or journals in the repository root.

Use `$MEO_DOCS_ROOT/Projects/omni-store/` for project records. Existing tools/CI may use their normal ephemeral build/cache directories; retained logs, evidence, install handoffs, and packages belong under `$MEO_OUTPUT_ROOT/omni-store/{build,install,validation,packages,tmp}/`. If these variables are unset, do not invent machine-specific absolute paths.

Preserve unrelated dirty work. Never use `git reset`, `git clean`, or broad deletion as routine cleanup.
