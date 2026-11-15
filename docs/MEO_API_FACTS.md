> 📚 [MeoArch 主文档 / Master Doc](https://github.com/QwQdoge/MeoArch-os-workspace/blob/main/docs/MEOARCH_MASTER.md)：全部仓库地图、操作手册、Cloudflare 清单、全部文档链接。<!-- meoarch-master -->

# Meo Account / Meo API: what OmniStore needs to know

The public contract lives on the MeoArch site. This page only records what it
means for OmniStore and what is still open. When this file and the site pages
disagree, the site pages and the running service win.

| Topic | Public page |
| --- | --- |
| Routes, scopes, errors, streaming format, models, plans and limits, backups, usage | [Meo Account API](https://meoarch.org/docs/guide/account-api.html) |
| Client manifest, getting a token, asking the broker to call the API, usage upload | [Native App Integration](https://meoarch.org/docs/guide/account-native-apps.html) |
| How the store should show AI errors and progress | [Store Feedback](https://meoarch.org/docs/meoui/store-feedback.html) |

## What applies to OmniStore

1. **No token reaches the app by itself.** The Meo Account broker never returns a
   token. OmniStore either asks the broker to make a call, or runs the broker's
   `authorize_client` flow to obtain its own token. See the Native App Integration page.
2. **OmniStore has no registered OAuth client yet.** Clients are registered by the
   Meo maintainers; there is no self-service. The `oauthClientId` in
   `data/meo-account/org.meo.OmniStore.json` is a placeholder. Until a client is
   registered, do not list `meo:read` / `meo:write` in that manifest: the authorize
   request would ask for scopes the client does not hold.
3. **`omnistore://auth/callback` is a valid redirect** under the broker's manifest
   rules (custom scheme, host `auth`, path `/callback`).
4. **Streaming needs an own token.** The broker's AI operations return a whole
   answer. `/v1/chat/stream` (server-sent events) is available only to an app that
   holds its own token. OmniStore's current use (package-metadata questions) does
   not need streaming.
5. **Models are the user's own.** The list comes from the user's model connection;
   Meo has no global model list and applies no per-plan model limit.
6. **No plan quota is enforced today.** Do not show a remaining-quota number. A
   provider rate limit (`ai_provider_rate_limited`) is the user's own provider, not
   a Meo limit.
7. **Usage events are AI token usage**, not installed applications. OmniStore has no
   AI token counters of its own, so it uploads nothing.
8. **Backups can carry an application inventory** (`id`, `sourceId`, optional
   `version`) but only inside a Meo Settings backup in the `org.meo.backup/v1`
   format. OmniStore settings are not accepted by that format. An inventory reveals
   what a user installs, so it is shared only on an explicit user choice.

## Open items for OmniStore

| Gap | Owner |
| --- | --- |
| A registered OAuth client id and the scopes OmniStore should hold | Meo maintainers |
| A broker method for streaming, or a decision to hold an own token | Meo Account |
| An OmniStore-specific backup/sync schema | Meo API |
| Public description of the realtime event payloads and `/v1/me` fields | Meo API |
| Per-plan quotas | not defined by the service |
