## Workflow rules from the owner (override anything below)

- Commit directly on the repository's current/default branch (`main` unless the repo is deliberately on another working branch). Do not create feature branches or PR branches unless asked.
- After committing, push immediately. Do not ask for permission to commit or push, and do not leave finished work uncommitted or unpushed.
- Keep verification minimal: run only the quick check for the touched code (typecheck or the one relevant test). Do not run full suites or write extra tests unless asked.
- Do the whole task in one pass; do not stop to ask routine questions that have an obvious default.
- Never put secrets, tokens or credentials in code, logs or commits.

## MeoUI specification (read before UI work)

- People: https://meoarch.org/docs/ . Agents: https://meoarch.org/llms.txt , then the Markdown pages it lists; start with https://meoarch.org/docs/meoui/for-agents.md (decision tables and checklists).
- Window chrome and toolbar, where app settings live and their categories, About, and open-source credits: https://meoarch.org/docs/meoui/app-shell.md .
- The canonical source is MeoUI `docs/design/`; the site is generated from it. If they disagree, MeoUI wins. Propose rule changes there, not in this repository.

# OmniStore agent rules

## Start here

Work only in the owning layer for the task. Inspect `git status`, the affected files, and the nearest relevant tests/contracts before editing; do not scan the whole repository or read every document by default.

Read `docs/architecture-migration.md` before work that touches client architecture, directory layout, Flutter/Native parity, or packaging paths.

## Ownership

- `python/`: **current backend authority** for Python backend, source/plugin logic, daemon mode, and Python tests.
- `src/native-ui/`: **current desktop client direction**. New OmniStore desktop UI/product work should target the native client unless the task explicitly concerns legacy compatibility.
- `legacy/flutter-ui/`: **legacy compatibility client**. Keep it buildable where compatibility contracts still require it, but do not add new desktop product features here by default.
- `plugins/sources/`: source manifests. A manifest or toggle alone does not prove search/install/update support.
- `PKGBUILD`, `auto_build.py`, release/export scripts: packaging and release contracts.
- This repository has Python daemon code; it does **not** contain a Rust daemon/Cargo workspace. Do not invent or describe one.

Shared OS/Plasma UI belongs in MeoUI or meo-kde rather than being copied here.

The client layout has crossed the structural migration boundary: native code is under `src/`, legacy Flutter is under `legacy/`. Do not recreate top-level `NativeUI/` or `FlutterUI/` compatibility copies. If a maintained tool still references those paths, fix the tool instead of restoring duplicate trees.

## Validation matrix

Run the narrowest matching checks first.

- Flutter compatibility change:
  `cd legacy/flutter-ui && flutter pub get && flutter analyze && flutter test --reporter expanded`
  Add `flutter build linux --release` when Linux integration, dependencies, packaging, or compatibility behavior changed.
- Python/backend change:
  `cd python && python -m pytest -q`
  If dependencies changed, also install/check `requirements.txt` in an isolated environment.
- NativeUI change:
  mirror `.github/workflows/native-quality.yml`: configure `src/native-ui/` with CMake using a real MeoUI checkout, then build target `omnistore-native`.
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

## MeoArch documentation map

- Docs site: https://meoarch.org/docs/ (MeoUI specification: app shell, settings pattern, page types, dynamic color, API lifecycle, localization). Agent entry points: https://meoarch.org/llms.txt and https://meoarch.org/docs/meoui/for-agents.md. The canonical source is the MeoUI repository `docs/`; if they disagree, the repository wins.
- Packaging and releases: https://github.com/QwQdoge/meo-repo - read its `AGENTS.md`, `docs/MEOARCH_IMPLEMENTATION_RUNBOOK.md`, `manifests/{beta,stable}/` and the "MeoArch repository release" workflow (https://github.com/QwQdoge/meo-repo/actions/workflows/release.yml).
- Release approval: the `sign-and-publish` and AUR jobs wait on the protected `release` Environment. After the owner confirms in chat, agents approve with `gh api -X POST repos/QwQdoge/meo-repo/actions/runs/<run>/pending_deployments -F environment_ids[]=<id> -f state=approved` (details in meo-repo `AGENTS.md`); the owner can also use Actions -> "Review deployments" -> `release`.
- Before tagging a component for release: its source archive must extract cleanly (no tracked build output such as `target/`, no absolute symlinks) and its CI must be green; tag the newest green commit.
- Other repositories: MeoUI (design system), meo-kde (Plasma shell), meo-ai (Meo AI), meo-api (cloud API), MeoArch-account (account app), MeoSettings, MeoArch-os-workspace (ISO/installer/repair), OmniStore, meo-login-manager, meo-repo (packages), meoarch-site (meoarch.org).
