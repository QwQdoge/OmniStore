> 📚 [MeoArch 主文档 / Master Doc](https://github.com/QwQdoge/MeoArch-os-workspace/blob/main/docs/MEOARCH_MASTER.md)：全部仓库地图、操作手册、Cloudflare 清单、全部文档链接。<!-- meoarch-master -->

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

## Meo API (reference received; client not implemented)

Source: the meo-api Worker reference (`https://api.meoarch.org/v1`). When it and this
section disagree, the Worker code wins.

Facts that constrain OmniStore:

* Native clients authenticate with a Meo Account OAuth 2.1 bearer token (authorization
  code + S256 PKCE). `GET`/`HEAD` need scope `meo:read`; everything else `meo:write`.
  `data/meo-account/org.meo.OmniStore.json` currently lists only `openid profile email`
  and a placeholder `oauthClientId`, so it cannot obtain either scope yet.
* Errors are contracts by code (`unauthenticated`, `insufficient_scope`,
  `reauth_required`, `request_too_large` ...), not by message. Another user's IDs return
  404, never 403.
* Provider keys never leave the API: chat and images use a caller-owned `credentialId`
  and a `consent` object. Sensitive account actions need a fresh purpose-scoped
  reauthentication grant that OmniStore must not mint or cache.

Routes OmniStore could use, and what is still missing before using them:

| Need | Route | Status |
| --- | --- | --- |
| Settings backup / restore | `/v1/backups` (manifests, max 20) | Needs a manifest format and `meo:write`. Must exclude tokens and local paths. |
| Settings sync notice | `GET /v1/realtime` (`settings.changed`) | Needs `meo:read`. |
| Usage dashboard | `POST /v1/usage-events` (1–250 per batch, idempotent on `source`+`source_event_id`) | Could batch `org.meo.omnistore.installed-usage`; needs a source name and a privacy decision, because it uploads which apps are installed. |
| AI | `POST /v1/chat/prepare`, `/v1/chat/stream` | Already reachable through the Meo Account broker. Direct use only if the broker cannot cover a case. |
| Identity | `GET /v1/me` | Display only. |

## Decision: stay on the D-Bus broker (2026-11-14)

OmniStore does **not** call meo-api directly and holds no Meo token. All Meo identity
and AI traffic goes through the Meo Account broker (`org.meo.Accounts1`).

Why:

* The third-party OAuth registration is not public. Without a real `oauthClientId` and
  the `meo:read` / `meo:write` scopes, a direct call cannot authenticate at all.
* The broker already keeps provider keys, consent grants and tokens out of OmniStore
  (see "Meo Account AI"). A direct client would need its own PKCE flow, token storage
  in KWallet, refresh and revocation handling, all duplicating what the broker owns.
* The AI routes need a caller-owned `credentialId` and a `consent` object. The broker
  already produces both; OmniStore would have to reimplement the consent UI.

Answers to the previous open questions:

1. **Tokens:** OmniStore never runs its own PKCE flow. If a non-AI route is ever needed,
   OmniStore asks the broker for a short-lived, scope-limited access token. That broker
   method is **Not defined**; it must be specified by the Meo Account owner first.
2. **Usage events:** not implemented, and off by default when it is. OmniStore must not
   upload which apps are installed. A `source` name and event schema need the meo-api
   owner and an explicit privacy decision before any code is written.
3. **API vs broker:** the broker is the primary path, not a fallback. The API stays a
   possible second path only for non-AI routes (backup, realtime notice), and only
   after question 1 is answered.

Revisit this decision when all of these are true: a client id is registered for
`org.meo.OmniStore` with exact redirect `omnistore://auth/callback`; the Account owner
defines the broker token method (or approves OmniStore's own PKCE); and a concrete
feature needs a route the broker does not cover.

`data/meo-account/org.meo.OmniStore.json` keeps its placeholder `oauthClientId` and
scopes `openid profile email` until then. Do not add `meo:read` / `meo:write` there
before registration exists: the file would claim authority the client does not have.

## Facts missing from the meo-api reference

The reference received so far does not contain the following. They are **Not defined**
for OmniStore; do not infer them from other clients, and do not hard-code guesses.
Read them from the Worker code or ask its owner.

| Missing | Why OmniStore cares | Handling until defined |
| --- | --- | --- |
| Available model list (route, fields, per-plan differences) | Model picker for the AI assistant | The picker lists only what `ListAvailableLocalAiConnections` returns |
| `/v1/chat/stream` framing and event fields (SSE or chunked, delta, finish, error, usage) | Rendering streamed answers | Use the broker's `invoke` result; no direct stream parsing |
| Per-plan quotas (requests, tokens, rate limits, reset time) | Showing remaining quota, handling `429` | Show "unknown"; surface the error code the broker returns, never an invented limit |

When the owner supplies them, record them in this file with the Worker commit they
were read from, and add the matching error-state wording to MeoUI `STORE_FEEDBACK.md`.

Billing, checkout and `/v1/sync` are not implemented on the API side either.

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
