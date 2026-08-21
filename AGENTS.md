# OmniStore workspace guidance

This repository owns the OmniStore Flutter frontend, Python backend, source
plugins, packaging, and first-login provisioning consumer.

## Source paths

- Flutter application: `FlutterUI/`
- Python backend: `python/`
- Source plugin manifests: `plugins/sources/`
- Arch package recipe: `PKGBUILD`
- Release/ISO integration scripts: `scripts/`

Do not claim a source is supported unless search, details, install, uninstall,
update, error propagation, and platform gating are real. A plugin manifest and
UI toggle alone are not runtime acceptance. Pacman repository additions must
fail closed until signature/keyring enrollment is implemented.

## Generated material

- Flutter and Python build intermediates remain in their existing `build/`,
  `.dart_tool/`, `dist/`, or `build_cache/` directories.
- Distributable bundles go under `artifacts/releases/<platform>/`.
- Screenshots, install/update logs, and provisioning evidence go under
  `artifacts/validation/<run-id>/`.
- Do not write release bundles, screenshots, or logs into the repository root.

MeoArch ISO integration consumes a versioned release bundle from this project;
the ISO workspace must not copy an arbitrary development tree or virtualenv.
