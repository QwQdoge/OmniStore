# OmniStore app-management manifests

These manifests describe **verified app-scoped locations** that Meo Settings may
show and ask OmniStore to maintain. They are a safety boundary, not a heuristic
catalog.

## Rules

- Only relative paths are allowed. Absolute paths and `..` are rejected.
- Runtime containment checks and symlink checks still apply even when a manifest
  passes the JSON Schema.
- `config` means settings that an application can recreate from defaults.
  Do not put user-created documents, profiles, projects, save games, browser
  profiles, mail stores, or other irreplaceable data in `config`.
- `cache` must be disposable without changing user-visible settings or data.
- `data` and `state` may contain persistent app-local data. Their presence
  enables the destructive **Delete app data** action, so add them only when that
  behavior is correct and clearly scoped.
- Do not use wildcards. Enumerate narrowly scoped directories instead.
- Native-package manifests are trusted only from the packaged OmniStore/MeoArch
  installation roots. User-writable manifests are deliberately ignored.
- Flatpak applications do not normally need a manifest: OmniStore can derive
  their sandboxed `~/.var/app/<app-id>/{config,cache,data}` locations safely.

## Minimal example

```json
{
  "schema": "org.meo.omnistore.app-manifest",
  "version": 1,
  "match": {
    "names": ["foot"]
  },
  "storage": {
    "config": [
      {"root": "config", "path": "foot"}
    ]
  }
}
```

A `settings` object may advertise a trusted graphical configuration provider
or route, but it must not embed shell commands.

```json
{
  "settings": {
    "provider": "meo-settings-route",
    "label": "Desktop & shell",
    "route": "shell"
  }
}
```

The runtime parser remains authoritative; the schema exists to catch mistakes
before packaging.
