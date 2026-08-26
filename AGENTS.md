# OmniStore agent rules

This repository owns the OmniStore Flutter client, Python backend, source
plugin manifests, package recipe, and release/ISO integration inputs. Preserve
the source tree and make only evidence-backed capability claims.

## Source ownership and runtime facts

- Flutter work belongs in FlutterUI/. Run Flutter commands from that directory.
- Python backend and daemon-mode code belong in python/. This checkout has
  Python daemon-mode code; it does not contain a Rust daemon/Cargo workspace.
  Do not claim or scaffold a Rust daemon as though one already exists.
- Source manifests belong in plugins/sources/. A manifest or UI switch alone
  does not establish search/install/update support.
- PKGBUILD and release exporter checks are package-source contracts. Keep
  versioned release bundles separate from an arbitrary development checkout.

## Documentation and records

- Keep code-bound documentation with the owning component or in docs/ for a
  new root-wide contract.
- Do not create root-level plan files, architecture drafts, audits, PR journals,
  agent journals, screenshots, build logs, or temporary notes.
- Store plans, decisions, audits, and historical reports in
  /home/shekong/Documents/Obsidian Vault/MeoArch/Projects/omni-store/, using
  00-inbox, 01-overview, 02-decisions, 03-work, 04-validation, and 99-archive.
- Already-classified root records and historical Agent material live in the
  OmniStore Obsidian `99-archive/` with provenance preserved. Retained source,
  build/cache folders, and artifacts are not routine-cleanup targets.

## Output rules

New durable output belongs only under
/home/shekong/Projects/outputs/omni-store/:

| Kind | Path |
| --- | --- |
| Reproducible build work | build/ |
| Install or ISO handoff | install/ |
| Validation evidence | validation/<UTC-run-id>/ |
| Release bundles/packages | packages/ |
| Disposable work | tmp/ |

Use YYYY-MM-DDTHHMMSSZ-short-label for every validation run. Do not put generated
output in the repository root.

## Security and deployment boundary

- Never place user credentials, AI-provider secrets, API keys, or package
  signing material in source, output, or Obsidian notes.
- Do not add a local credential broker or account synchronization behavior
  without explicit, reviewed design and per-use consent.
- Do not publish packages, alter remote package sources, deploy a service, or
  modify a live machine/service without explicit user authorization.
- Avoid git reset, git clean, broad deletion, and unreviewed recursive
  commands. Preserve dirty work and state validation limits honestly.
