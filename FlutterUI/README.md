# OmniStore Flutter UI

This directory is the OmniStore Flutter application. Run Flutter tooling from
this directory rather than from the repository root.

## Source map

| Path | Purpose |
| --- | --- |
| lib/app/ | Application bootstrap and top-level navigation. |
| lib/core/ | Shared app infrastructure and navigation/state helpers. |
| lib/data/ | Data-layer adapters, including the Python bridge. |
| lib/features/ | User-facing feature modules. |
| lib/services/ | Client-side services such as backend, update, history, and localization support. |
| lib/l10n/ | ARB source and generated localization output. |
| test/ | Flutter UI and integration-contract tests. |
| assets/ | Versioned Flutter assets. |

The package metadata currently names this Flutter package frontend. That is
package metadata, not a separate product; this directory is OmniStore's client.

## Normal workflow

Use Flutter commands from this directory: fetch dependencies, run targeted
tests, then run or build the platform explicitly requested by the task. Keep
generated Flutter intermediates tool-managed. Regenerate localized Dart output
from ARB source rather than hand-editing generated localization files.

Do not claim Linux/Wayland, package-management, AI-provider, account, or
daemon behavior from a widget-only result. Record the actual runtime and
integration boundary in the project validation record.

## Filing rule

- Client source, tests, and assets stay in their existing folders here.
- A client contract tied to source belongs in this component's documentation
  tree; project-wide contracts belong in the repository docs/ area when added.
- Plans, audits, decisions, and agent journals go to
  /home/shekong/Documents/Obsidian Vault/MeoArch/Projects/omni-store/.
- New build work, installs, validation evidence, packages, and temporary output
  go under /home/shekong/Projects/outputs/omni-store/ in build/, install/,
  validation/<UTC-run-id>/, packages/, and tmp/ respectively.

Use UTC identifiers in the form YYYY-MM-DDTHHMMSSZ-short-label for validation
runs. Do not create root-level plan files, screenshots, logs, or temporary
notes inside FlutterUI/.
