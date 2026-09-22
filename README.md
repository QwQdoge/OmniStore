# OmniStore

OmniStore is a cross-platform software-store project with a Flutter desktop/web
client, a Python backend, source-plugin manifests, packaging inputs, and
MeoArch integration support. It manages software-source discovery and package
operations; a source toggle or manifest is not proof that every runtime action
is supported.

## License

OmniStore is licensed under the GNU General Public License v3.0 only
(`GPL-3.0-only`). See [LICENSE](LICENSE). Bundled dependencies and assets retain
their own upstream licenses.

## What is in this repository

| Path | Purpose |
| --- | --- |
| FlutterUI/ | Flutter client, platforms, assets, localization, tests, and Flutter-specific documentation. |
| python/ | Python backend, source/plugin logic, packaging assembly, tests, and daemon-mode code. |
| plugins/sources/ | Source-plugin manifests. |
| scripts/ | Maintenance and localization helpers. |
| PKGBUILD | Arch package recipe for the distributable project. |
| config_schema.json | Versioned configuration schema. |
| verify_release_exporter_contract.py | Release-bundle contract check for the Meo Settings usage export. |

The packaged update integration is documented in
[`docs/UNIFIED_UPDATES.md`](docs/UNIFIED_UPDATES.md). `meo-update` is the
shared, versioned entry point used by OmniStore, Meo Settings, and the
package-owned systemd user timer.

The checked-out source contains Python daemon-mode/update code in python/main.py
and python/daemon_main.py. It does not contain a Rust daemon source directory
or a Cargo manifest, so this project must not be described as shipping a Rust
daemon. Treat claims in older material as historical until they are verified
against the current source.

## Working boundary

Run Flutter tooling from FlutterUI/, and keep Python backend work under
python/. Keep code-bound component documentation with its component; a new
root-wide implementation or deployment contract belongs in docs/ when one is
needed. The root README and AGENTS files are orientation only.

Already-classified root notes and historical Agent material belong in the
external OmniStore archive with their provenance preserved. Retained source,
package configuration, build/cache directories, and artifacts are not an
invitation to add more root-level plans, architecture drafts, audit reports,
Agent journals, screenshots, logs, or release notes. Any further migration or
removal needs a separate, recoverable task.

## Capability and integration discipline

- Do not claim a package source works until search, details, install, uninstall,
  update, platform gating, and error behavior are implemented and tested as
  applicable.
- Meo Settings consumes the versioned installed-app usage export, not private
  daemon traffic. Keep that boundary explicit.
- Account and AI-provider credentials require explicit user consent and must
  not be copied into a custom backend, source file, or report.
- The MeoArch ISO consumes a versioned release bundle, never an arbitrary
  development tree or virtual environment.

## Filing rule for new material

Never assume a developer username, home directory, checkout location, or
Obsidian vault path. Resolve external project records from `$MEO_DOCS_ROOT` and
generated artifacts from `$MEO_OUTPUT_ROOT`.

| Material | Required location |
| --- | --- |
| Flutter, Python, plugin, script, package, and schema source | Their existing owning directory. |
| Contract tied to code, packaging, or deployment | The owning component documentation directory or docs/. |
| Plans, audits, decisions, agent journals, and historical reports | `$MEO_DOCS_ROOT/Projects/omni-store/` |
| Reproducible build work | `$MEO_OUTPUT_ROOT/omni-store/build/` |
| Install/ISO handoff material | `$MEO_OUTPUT_ROOT/omni-store/install/` |
| Validation evidence | `$MEO_OUTPUT_ROOT/omni-store/validation/<UTC-run-id>/` |
| Release bundles and package candidates | `$MEO_OUTPUT_ROOT/omni-store/packages/` |
| Disposable generated work | `$MEO_OUTPUT_ROOT/omni-store/tmp/` |

Use a UTC run identifier in the form YYYY-MM-DDTHHMMSSZ-short-label, such as
2026-08-26T143015Z-linux-smoke. Use the numbered folders in the external
project directory: 00-inbox, 01-overview, 02-decisions, 03-work,
04-validation, and 99-archive.

`python3 auto_build.py --all` puts PyInstaller spec, work, and interim binary
trees under the configured OmniStore build root, and its assembled bundle under
the configured package root. `--output-dir` is the explicit assembled-bundle
target and takes priority; `--output-root` (or `MEO_OUTPUT_ROOT`) changes the
shared root, while `--build-dir` changes only the PyInstaller build tree. This
avoids generated output in the source checkout.

## Meo Account AI release configuration

Every normal Flutter release build must embed the public Account client
configuration, otherwise the app cannot authenticate or reach the Account AI
broker. Before `python3 auto_build.py --all`, provide
`MEO_ACCOUNT_SUPABASE_URL` and `MEO_ACCOUNT_SUPABASE_PUBLISHABLE_KEY` in the
build environment. They are public client settings, never an AI provider key,
service-role key, or user credential. The build deliberately stops if either
value is missing. An offline developer build may opt out explicitly with
`--allow-account-disabled`; it must not be presented as Account-capable.

## Safety and release boundary

- Preserve existing source, plugin manifests, package sources, build/cache
  directories, artifacts, and dirty worktrees. Do not use destructive cleanup.
- Do not publish a package, deploy an integration, alter a system package
  source, or change a live daemon/service without explicit authorization.
- A local test, release build, screenshot, or contract verifier is only the
  evidence it actually provides; record the boundary rather than claiming an
  unperformed end-to-end result.
