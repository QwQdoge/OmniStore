# OmniStore agent rules

## Scope

- `FlutterUI/` owns the Flutter client. Run Flutter commands there.
- `python/` owns the Python backend, source/plugin logic, tests, and daemon mode. There is no Rust daemon/Cargo workspace in this repository.
- `NativeUI/` is the native Qt client path; keep native-only work there.
- `plugins/sources/`, `PKGBUILD`, schemas, and release-exporter files are source/package contracts. A manifest or toggle is not proof that search/install/update works.

## Work sequence

1. Inspect `git status`, the files you will touch, and only the directly relevant contract/docs.
2. Change the owning subtree; do not copy an implementation between Flutter, Python, NativeUI, or another Meo repository.
3. Run the narrowest relevant check first, then the broader CI-equivalent check only when the changed surface warrants it.
4. Report what actually ran and what remains unverified.

## Validation

- Flutter: from `FlutterUI/`, run `flutter analyze` and `flutter test --reporter expanded`. Build Linux release only for build/release-sensitive changes.
- Python: from `python/`, run `python -m pytest -q`.
- NativeUI: mirror `.github/workflows/native-quality.yml` for configure/build checks.
- Packaging/source manifests: validate the specific recipe/export contract involved; do not infer runtime capability from static metadata.

## Boundaries

Use `$MEO_DOCS_ROOT/Projects/omni-store/` for plans/audits/decisions and `$MEO_OUTPUT_ROOT/omni-store/{build,install,validation,packages,tmp}/` for generated output. Never invent machine-specific absolute paths when those roots are unset. Keep generated files, screenshots, logs, and journals out of the repository root.

Never store credentials, provider secrets, signing material, or user data here. Do not publish packages, alter package sources, deploy services, or modify a live machine without explicit authorization. Preserve unrelated dirty work; do not use `git reset`, `git clean`, or broad deletion as cleanup.
