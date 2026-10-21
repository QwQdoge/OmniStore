# OmniStore ↔ Meo integration contract

This describes what exists in this repository today. Items marked **Not defined**
have no contract in this repository and must be specified with the owning Meo
project before they are implemented here.

## Ownership

| Concern | Owner |
| --- | --- |
| Package sources, search, install, update, transactions | OmniStore (`python/`) |
| Store UI | OmniStore native client (`src/native-ui/`) on MeoUI |
| System AI connections, API keys, consent grants | Meo Account (`org.meo.Accounts1`), configured in Meo Settings |
| Meo update channel packages (`meo`, `meo-beta`) | `meo-release`; OmniStore only switches them via `meo-channel-*` |
| Shared Plasma / system settings UI | MeoUI / meo-kde, not copied here |

## Meo Account AI (implemented)

* Client id `org.meo.OmniStore`, registered by `data/meo-account/org.meo.OmniStore.json`
  with capability `local_ai`.
* The native client (`accountaibridge.cpp`) calls, on the session bus,
  `ListAvailableLocalAiConnections`, and `StartLocalAiOperation` with action
  `prepare_inference`, `invoke` or `revoke_catalog_consent`.
* OmniStore never receives an API key. Every request shows its destination and the
  data categories (`package_metadata`, `user_prompt`) first; a remembered grant is
  bound to client, provider, endpoint and model.
* The backend's own AI assistant is legacy: CLI `--ai-*` commands return
  `explicit_ai_consent_required`. `ai.api_key` is never written to `config.yaml`;
  `OMNISTORE_AI_API_KEY` is the only way to supply one to that legacy path.

## Meo API

**Not defined.** No endpoint, scope or capability for a "Meo API" exists in this
repository. Add the capability to `data/meo-account/org.meo.OmniStore.json` and a
bridge next to `accountaibridge.cpp` only once the API contract is published.

## Configuration

* OmniStore's own settings live in `$XDG_CONFIG_HOME/omnistore/config.yaml`
  (validated by `ConfigModel`, described by `config_schema.json`, templated by
  `python/config.yaml`; `tests/test_custom_sources.py` keeps the three aligned).
* Secrets are never stored there: AI keys come from Meo Account or
  `OMNISTORE_AI_API_KEY`; GitHub tokens from `OMNISTORE_GITHUB_TOKEN` / `GITHUB_TOKEN`.
* Appearance, language and accent colour are OmniStore keys today. **Not defined:**
  whether Meo Settings should own them and how OmniStore would read them.

## Background service and KDE

* `omnistore-update.timer` → `omnistore-update.service` runs `meo-update background`
  every 6 h; `omnistore --background-update-check` and `daemon_main.py` notify through
  `notify-send` with the hint `desktop-entry=org.meo.OmniStore`, so Plasma attributes
  them to the installed `org.meo.OmniStore.desktop` and applies the per-app settings in
  System Settings → Notifications.
* **Not defined:** a D-Bus service or KCM for the daemon, and Plasma task-manager
  progress. These need a contract with meo-kde.

## Custom repositories

`custom_repos.<source>` holds `{name, url}` entries for every source id. Flatpak,
Pacman and AppImage use their dedicated managers. Others use
`core/search/custom_sources.py`:

| Mode | Sources | Behaviour |
| --- | --- | --- |
| `apply` | brew, scoop, chocolatey, winget, fdroid | runs the source's own CLI; recorded only if it succeeds |
| `track` | apt, dnf, zypper, apk, snap | recorded only; root-owned files are never edited by OmniStore |
| `feed` | github, bitu | URL / `owner[/repo]` OmniStore reads itself |

`omnistore --list-custom-repos` returns every list plus a `capabilities` table.
`track` and `feed` entries are not evidence that the source searches them; that needs
the source implementation and tests.
