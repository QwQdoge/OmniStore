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

## Meo API

Everything known about the API, the OAuth flow and the broker is in
[`MEO_API_FACTS.md`](MEO_API_FACTS.md), read from the `meo-api` Worker (`8c75994`) and
`MeoArch-account` (`bb38df3`) source. When it and this file disagree, the source wins.

Constraints that shape OmniStore:

* Native clients authenticate with a Meo Account OAuth 2.1 bearer token (authorization
  code + S256 PKCE, 15-minute access token). `GET`/`HEAD` need `meo:read`; every other
  method needs `meo:write`.
* The broker **never returns a token to an app**. An app either asks the broker to make
  a call, or runs its own PKCE flow through the broker's `authorize_client` dialog.
* Errors are contracts by code (`{"error":{"code":"…"}}`), not by message. Another
  user's IDs return `404`, never `403`.
* Provider keys never leave the API. Chat and images use a caller-owned `credentialId`
  and a `consent` record bound to the OAuth client. Sensitive account actions need a
  fresh purpose-scoped reauthentication grant that OmniStore must not mint or cache.

## Decision: stay on the D-Bus broker (2026-11-14, revised)

OmniStore does **not** call meo-api directly and holds no Meo token. Meo identity, AI
and (later) backup traffic go through the Meo Account broker (`org.meo.Accounts1`).

Why:

* **No client is registered.** `meo-api` has native clients for Meo Account Desktop,
  Meo Settings, Meo AI Desktop, Meo AI Android and Meo AI Web. None is OmniStore, and
  clients are added by SQL migration only. Without a real `oauthClientId` the broker's
  `authorize_client` flow cannot start, so a direct call cannot authenticate at all.
* The broker already holds the system session in KWallet and keeps provider keys,
  consent records and tokens away from OmniStore. A direct client would duplicate PKCE,
  token storage, refresh, revocation and the consent UI.
* What OmniStore actually uses today (non-streaming package-metadata questions) is
  fully covered by `StartLocalAiOperation`.

Answers to the earlier open questions:

1. **Tokens.** Meo Account does *not* hand tokens to apps over `org.meo.Accounts1`; no
   method returns one. If a feature ever needs a token of OmniStore's own, the route is
   the broker's `RequestAuthentication(..., "authorize_client", {state, codeChallenge})`
   with OmniStore's own PKCE, then `RegisterClientSession`. That needs the
   registration in `MEO_API_FACTS.md` §1.5 and a matching manifest. OmniStore must not
   run its own browser/PKCE flow outside the broker.
2. **Usage events.** `/v1/usage-events` carries **AI token usage**, not installed
   applications. OmniStore has no AI token counters of its own, so it sends nothing.
   If that changes, it goes through the broker's `/org/meo/Accounts1/Usage` object with
   the `ai_usage_sync` capability, never directly. A `source` name is not chosen yet.
3. **API vs broker.** The broker is the primary path, not a fallback. The one thing it
   cannot do is stream: its cloud AI operations (`prepare_inference`, `invoke`) return a
   whole answer. `/v1/chat/stream` (SSE) is reachable only with a token OmniStore holds
   itself.

Revisit this when one of these becomes true: a feature needs streamed answers; or a
feature needs a route the broker has no method for; and, in both cases, a client id is
registered for OmniStore with exact redirect `omnistore://auth/callback`.

`data/meo-account/org.meo.OmniStore.json` keeps its placeholder `oauthClientId` and
scopes `openid profile email` until registration exists. Do not add `meo:read` /
`meo:write` there first: the broker would request scopes the client row does not grant,
and the authorize request fails.

## Backups and OmniStore's application list

`/v1/backups` accepts only the `org.meo.backup/v1` schema. Its `applications[]` is a list
of `{id, sourceId, version?}`, so an installed-application inventory can travel inside a
Meo Settings backup. Meo Settings builds that manifest; OmniStore may be asked for the
inventory but does not upload it. The privacy decision stays open: the inventory reveals
what a user installs, so any sharing needs an explicit user choice and `applicationsState`
`unavailable` when declined. OmniStore's own settings are **not** accepted by the schema.

## Facts the old reference was missing

These are now answered in `MEO_API_FACTS.md`:

| Question | Answer | Section |
| --- | --- | --- |
| `/v1/chat/stream` format | SSE; events `delta`, `truncated`, `tool_calls`, `mcp_tool_proposal`, `work_agent_proposal`, `done`, `error`; requires a prepared consent | §2 |
| Available models | The user's own provider catalogue per connection, up to 500, with `task` and modalities; no Meo-wide or per-plan list | §3 |
| Plan quotas | None enforced; `free`/`plus`/`pro` have empty entitlements and no prices | §4 |
| Client registration | Not registered; proposed SQL is given, not applied | §1.4, §1.5 |
| Token delivery over D-Bus | Never; own-token flow via `authorize_client` | §1 |

Still undefined (see `MEO_API_FACTS.md` §7): the final OmniStore client id and scopes, an
OmniStore backup schema, `/v1/me` and realtime payload fields, and a streaming broker
method.

Billing, checkout and `/v1/sync` are not implemented on the API side.

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
