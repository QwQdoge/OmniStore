> 📚 [MeoArch 主文档 / Master Doc](https://github.com/QwQdoge/MeoArch-os-workspace/blob/main/docs/MEOARCH_MASTER.md)：全部仓库地图、操作手册、Cloudflare 清单、全部文档链接。<!-- meoarch-master -->

# Meo Account / Meo API facts for OmniStore

Everything here was read from source on 2026-11-14, not inferred. Where a
fact is not in the source it is listed under "Not defined".

| Source | Commit | Used for |
| --- | --- | --- |
| `meo-api` (private Worker) | `8c75994` | routes, errors, SSE, plans, backups, usage |
| `MeoArch-account` `desktop/` | `bb38df3` | D-Bus broker, client manifests, token handling |

When this file and the code disagree, the code wins. Re-read the files named in
each section before relying on a detail. The contract OmniStore itself follows
is in `MEO_INTEGRATION.md`.

## 1. How a native app gets a token

### 1.1 What the broker does and does not do

`meo-accountd` (`org.meo.Accounts1`) keeps the system session in KWallet and
**never returns an access or refresh token to an app**. There is no D-Bus method
that hands a token over. An app therefore has exactly two ways to reach
meo-api:

1. **Ask the broker to make the call** (`StartAccountOperation`,
   `StartCloudAiOperation`, `StartLocalAiOperation`, `StartUsageOperation`).
   The broker attaches its own token. The app only sees a result.
2. **Get its own token** through the broker-mediated OAuth flow in 1.2. The app
   holds its own token; the system session is not shared.

### 1.2 Own-token flow (`authorize_client`)

1. Install a client manifest (1.3). It binds a registered OAuth client, exact
   redirect, scopes and the executable path.
2. The app generates an independent `state` (32–256 chars) and a PKCE S256
   challenge (43–128 chars), then calls
   `RequestAuthentication(clientId, "authorize_client", {state, codeChallenge})`.
   The broker checks the caller's `/proc/<pid>/exe` against the manifest.
3. The broker shows its native consent dialog (it never sees a password or
   token). On approval it opens the browser at
   `https://account.meoarch.org/v1/auth/oauth2/authorize` with `client_id`,
   `redirect_uri`, `response_type=code`, `resource=https://api.meoarch.org`,
   the manifest scopes, `state`, `code_challenge`, `code_challenge_method=S256`.
4. The browser returns the one-time code to the app's redirect URI. The app
   checks `state`, then exchanges the code itself at
   `POST https://account.meoarch.org/v1/auth/oauth2/token` with its verifier.
5. The app calls `RegisterClientSession(clientId, sessionId, accountId,
   logoutEpoch)` and `CompleteClientAuthorization`. The broker stores only
   `clientId`, `sessionId`, `accountId`, time and the logout generation, so a
   system sign-out can revoke the app's remote session and emit
   `clientSignOutRequested`.
6. Request states: `waiting_for_user` → `opening_browser` →
   `waiting_for_callback` → `completed` / `denied` / `failed` / `expired`.
   Requests expire after 5 minutes. Poll with `GetRequest` or watch the
   `requestChanged` signal.

Token facts (`meo-api/src/auth.ts`):

| Item | Value |
| --- | --- |
| Resource / audience | `https://api.meoarch.org` |
| Access token | JWT, `typ: at+jwt`, lifetime 900 s |
| Refresh token | only with `offline_access`, and only if the client's grant types include `refresh_token` |
| Scopes the provider knows | `openid profile email offline_access meo:read meo:write` |
| Allowed on the resource | `openid profile email meo:read meo:write` |
| Client auth | public client, `token_endpoint_auth_method=none`, PKCE required, no secret |
| Revocation | `POST /v1/auth/oauth2/revoke`; clearing KWallet does not revoke remotely |

Storage: an app that holds its own token must keep it in KWallet or the
platform keyring. Never in `config.yaml`, logs or the environment.

### 1.3 Client manifest

Installed by the app's own package at
`/usr/share/meo-account/clients/<name>.json` (`MeoArch-account/desktop/src/clientregistry.cpp`).
The broker silently rejects a manifest that fails any rule:

| Field | Rule |
| --- | --- |
| `id` | non-empty, ≤128 chars (`org.meo.OmniStore`) |
| `name` | non-empty, ≤160 chars |
| `oauthClientId` | non-empty, ≤256 chars; must be a client registered in meo-api |
| `redirectUri` | path exactly `/callback`; no query, fragment, user info or port; either `https://<host>/callback`, or `<custom-scheme>://auth/callback` (scheme not `http`, `https`, `file`, `data`, `javascript`) |
| `executables` | non-empty list of absolute paths; the caller's real exe must match one |
| `scopes` | non-empty subset of `openid profile email phone offline_access meo:read meo:write` |
| `capabilities` | subset of `local_ai`, `ai_usage_sync`, `ai_personalization`; never sent to the identity provider |

`omnistore://auth/callback` satisfies the redirect rule. The current manifest
(`data/meo-account/org.meo.OmniStore.json`) is otherwise valid except for the
placeholder `oauthClientId`.

### 1.4 Registered OAuth clients today

Registered by `meo-api/migrations/auth/0004…0007`. OmniStore is **not** in the
list.

| `client_id` | Product | Redirect | Scopes |
| --- | --- | --- | --- |
| `06beedbb-88ae-46bd-92ae-bd91f450ec27` | Meo Account Desktop | `http://127.0.0.1:43887/callback` | `openid profile email offline_access meo:read meo:write` |
| `org.meo.settings` | Meo Settings | `meo-settings://auth/callback` | `openid profile` |
| `meo-ai-native` | Meo AI Desktop | `meoai://auth/callback` | `openid profile email offline_access meo:read meo:write` |
| `org.meo.ai.android` | Meo AI Android | (migration 0004) | (migration 0004) |
| web client | Meo AI Web | (migration 0005) | (migration 0005) |

Clients are registered by SQL migration, not by self-service. There is no
public registration endpoint, so a third-party client cannot register itself.

### 1.5 What registering OmniStore requires

Done by the meo-api owner (a migration in `migrations/auth/`, same shape as
`0006_native_clients.sql`). This is a proposal; **it has not been applied**:

```sql
insert into oauth_client (
  id,client_id,client_secret,disabled,skip_consent,enable_end_session,
  scopes,name,uri,redirect_uris,post_logout_redirect_uris,
  token_endpoint_auth_method,application_type,grant_types,response_types,
  require_pkce,dpop_bound_access_tokens,created_at,updated_at
) values (
  gen_random_uuid(),'org.meo.omnistore',null,false,false,true,
  array['openid','profile','email','meo:read']::text[],   -- add 'meo:write' only with a feature that needs it
  'OmniStore','https://account.meoarch.org',
  array['omnistore://auth/callback']::text[],array[]::text[],
  'none','native',array['authorization_code']::text[],array['code']::text[],
  true,false,now(),now()
) on conflict(client_id) do nothing;

insert into oauth_client_resource(id,client_id,resource_id,created_at)
values (gen_random_uuid(),'org.meo.omnistore','https://api.meoarch.org',now())
on conflict(client_id,resource_id) do nothing;
```

Without the `oauth_client_resource` row the authorize request fails with
`invalid_target` (this broke Android once, see migration `0007`). The client id
string `org.meo.omnistore` is a suggestion that follows `org.meo.settings`; it
is not reserved anywhere yet.

Then, in OmniStore: put the same id in `oauthClientId`, list only the scopes
the client row grants, and ship the manifest with the package.

`meo:write` decides write access to AI chat, images, search, backups
(upload/delete), conversations, memories, projects. `meo:read` alone allows
only `GET`/`HEAD`. Grant the smallest set a feature needs.

### 1.6 OAuth client identity in AI calls

A token issued to a client carries its `clientId`. In
`ai-broker.ts`, an inference request whose body `clientId` differs from the
token's client is refused with `403 oauth_client_mismatch`. So OmniStore's
direct calls must send its own `clientId`, and its consent records are bound to
it.

## 2. Direct `POST /v1/chat/stream`

Source: `meo-api/src/chat.ts`, `src/ai-broker.ts` (`streamProvider`,
`sseFrame`), `src/realtime.ts` (`relayRun`).

### 2.1 Request

`POST https://api.meoarch.org/v1/chat/stream`, `Authorization: Bearer <token>`,
`Content-Type: application/json`. Needs `meo:write` (or a web cookie session).
Unknown keys are rejected with `400 invalid_request`.

| Field | Type | Rule |
| --- | --- | --- |
| `credentialId` | uuid | required; the caller's own provider connection |
| `model` | string ≤160 | required |
| `prompt` | string ≤35 000 | required; older context is trimmed first |
| `consent` | object | **required for stream** (`400 invalid_consent` if absent): `{requestId, payloadSha256, confirmationVersion: 1}` from a prior `/v1/chat/prepare` |
| `conversationId` | uuid \| null | loads stored context |
| `skillId`, `workAgentProjectId` | uuid \| null | optional |
| `mcpAuto`, `mcpContinuation` | boolean | optional |
| `webResults`, `images` | array | optional |
| `environment` | object | `{client: desktop\|web\|android, os, locale, timezone, device, role, thinking, webSearch, subagents, location}` |
| `tools`, `turns` | array | client-side native tool calling |

Two-step flow: `POST /v1/chat/prepare` (same body, no `consent`) returns

```json
{ "consent": {
  "requestId": "uuid", "credentialId": "uuid", "payloadSha256": "hex",
  "confirmationVersion": 1, "expiresAt": "ISO-8601",
  "provider": "…", "providerName": "…", "destination": "https://…",
  "model": "…", "clientId": "…", "purpose": "meo_ai_chat",
  "dataCategories": ["…"], "responseLanguage": null,
  "promptCharacters": 1234, "operation": "text_inference" } }
```

The user must approve what that record shows. Consent expires after 5 minutes.
The stream call is accepted only with the same `requestId`, a matching
`payloadSha256` and `confirmationVersion: 1`; the server rebuilds the prompt and
compares the hash, so the prompt must not change between the two calls (the
timestamp it embeds is day-granular for this reason). A used or mismatched
consent returns `409 consent_invalid_or_used` / `consent_request_mismatch`.

### 2.2 Response

`200`, `Content-Type: text/event-stream; charset=utf-8`,
`Cache-Control: no-store, no-transform`. Frames are

```text
event: <name>
data: <one JSON object>

```

| Event | `data` | Meaning |
| --- | --- | --- |
| `delta` | `{"text": "…"}` | next piece of answer text; append in order |
| `truncated` | `{}` | the answer hit the output limit; it is **not** complete |
| `tool_calls` | `{"calls": [{"id","name","arguments"}]}` | calls the model made to the client's declared `tools`; empty or absent = model is done |
| `mcp_tool_proposal` | proposal object | the model proposes an MCP tool call; needs approval |
| `work_agent_proposal` | `{"project_id","task"}` | proposed work for a device agent; never run automatically |
| `done` | `{"model": "…", "requestId": "uuid"}` | normal end; the last frame |
| `error` | `{"message": "…"}` | the stream broke after it started |

Notes:

- Ordering: many `delta`, then optionally `truncated`, `tool_calls`,
  `mcp_tool_proposal`, `work_agent_proposal`, then `done`. An `error` frame ends
  the stream (no `done`). A client must treat a stream that closes with
  neither `done` nor `error` as failed.
- `delta` carries only text. **No token counts, finish reason or usage are sent
  in the stream.**
- Gemini-style connections are not streamed upstream: the answer arrives as one
  `delta` then `done`.
- Provider limits: first byte within 180 s, then no more than 90 s of silence.
  An idle timeout produces `error` with
  `"AI provider stream failed: no data for too long"`.
- `error.message` is human text and is generic; do not parse it.
- A client disconnect cancels the upstream request and marks the consent as
  not completed.
- When a `conversationId` is given, text is also relayed to the user's other
  devices over `/v1/realtime` (`run.delta`, then a terminal event). That does
  not change the response body.

### 2.3 Errors before the stream starts

Plain JSON, not SSE: `{"error": {"code": "…"}}` (a `message` key is rare).
Read `code`, never the text.

| Status | `code` | Meaning |
| --- | --- | --- |
| 400 | `invalid_request`, `invalid_credential`, `invalid_conversation`, `invalid_json`, `invalid_consent`, `invalid_images`, `invalid_output_limit`, `invalid_temperature`, `invalid_data_categories`, `native_tools_not_supported` | bad input |
| 401 | `unauthenticated` | no valid token |
| 403 | `insufficient_scope` | token lacks `meo:write` |
| 403 | `oauth_client_mismatch` | body `clientId` ≠ token client |
| 403 | `custom_ai_endpoint_not_enabled` | endpoint kind not permitted |
| 404 | `ai_credential_unavailable`, `skill_unavailable`, `work_agent_project_unavailable` | not found or not yours |
| 405 | `method_not_allowed` | wrong method |
| 409 | `consent_invalid_or_used`, `consent_request_mismatch` | consent problem |
| 413 | `request_too_large` | body over the limit |
| 428 | `fresh_explicit_consent_required` | prepare again and ask the user |
| 429 | `too_many_consent_requests` | too many outstanding consents |
| 499 | `ai_provider_request_cancelled` | the caller cancelled |
| 502 | `ai_provider_authentication_failed` | the stored provider key was refused |
| 502 | `ai_model_or_endpoint_not_found` | model or endpoint not found at the provider |
| 502 | `ai_provider_rate_limited` | the **provider** returned 429 |
| 502 | `ai_provider_unavailable` | provider 5xx |
| 502 | `ai_provider_rejected_request` | other provider 4xx |
| 502 | `ai_provider_unreachable`, `invalid_ai_provider_response`, `ai_provider_no_text_output`, `ai_provider_response_too_large` | provider transport / content problem |
| 503 | `credential_decryption_failed`, `credential_encryption_unavailable` | server-side key problem |
| 504 | `ai_provider_timeout` | provider did not start in time |
| 500 | `chat_orchestration_failed`, `ai_broker_unavailable` | server failure |

Rate limits and quotas that Meo itself enforces: only the consent cap above.
The rest of "rate limited" is the user's own provider talking.

### 2.4 Via the D-Bus broker instead

The broker has **no streaming method**. Its cloud AI operations are
non-streaming: `StartCloudAiOperation` actions `list_connections`,
`discover_models`, `prepare_inference`, `invoke`, `deny_inference` (these map to
`/v1/ai/provider-broker` actions). `StartLocalAiOperation` talks to device-held
Ollama / OpenAI-compatible connections. Result states arrive by
`requestChanged`. If streaming is required, a direct token (1.2) is the only
route.

## 3. Models

Source: `ai-broker.ts` `normalizeModels`, `listModels`; `docs/api-reference.md` §8.

`GET /v1/ai/credentials/:id/models` (also broker action `list_models`) returns

```json
{ "supported": true, "cached": false,
  "models": [{ "id": "…", "name": "…", "description": "≤500 chars",
               "task": "chat", "tasks": ["…"],
               "inputModalities": ["…"], "outputModalities": ["…"] }] }
```

- The list is **the user's own provider's catalogue** for that connection, not a
  Meo-hosted list. There is no Meo-wide model list and no per-plan model list
  today (`chat.models` is a reserved, unused entitlement key; see 4).
- Up to 500 models, cached 5 minutes per credential in the Worker; editing the
  credential invalidates the cache.
- `task` says what the model is for (chat, image generation, image edit, video,
  speech, …); `inputModalities` / `outputModalities` say what it accepts and
  returns. Offer only models whose `task` fits the job.
- `GET /v1/ai/model-profiles` lists named role→model profiles (needs account
  migration `0011`, else `503 model_profiles_unavailable`). A role maps to
  `{credentialId, model}`. Max 20 profiles.

## 4. Plans and quotas

Source: `meo-api/docs/paid-and-cloud-readiness.md`, `migrations/account/0003_billing.sql`.

- `GET /v1/plans` returns the catalogue: `free`, `plus`, `pro`.
- `is_paid`, `checkout_enabled=false`, prices unset, `entitlements` is `{}` for
  all three. Everyone has an active Free subscription. `GET /v1/subscription`
  is read-only.
- **No quota is enforced anywhere.** `entitlements` is read for display only.
  There is no monthly token cap, request cap, or model restriction today. Do
  not show a quota number.
- Reserved entitlement keys, proposed and inactive: `chat.monthly_tokens`,
  `chat.models`, `agent.concurrent_runs`, `agent.device_count`,
  `connectors.max`, `connectors.auto_calls_per_day`, `cloud.enabled`,
  `cloud.monthly_cpu_minutes`, `cloud.concurrent_jobs`,
  `cloud.max_job_minutes`, `memory.items`. A missing key means "platform
  default" (unlimited). When enforcement ships, the server decides; the client
  only displays.
- Payment, checkout, customer portal, webhooks and `/v1/sync` are not
  implemented.

Hard limits that do exist:

| Limit | Value |
| --- | --- |
| Chat `prompt` | 35 000 chars |
| Image `prompt` | 4 000 chars |
| Backups per account | 20; each ≤ 512 KiB (524 288 bytes) |
| Usage events per request | 1–250; body ≤ 2 500 000 bytes |
| Model catalogue returned | 500 |
| Model profiles | 20 |
| Access token | 15 min |
| Reauth grant | 10 min |
| AI consent | 5 min |

## 5. Other routes OmniStore could use

All need a Bearer token with the scope shown (`meo:read` = `GET`/`HEAD`,
`meo:write` = the rest) and a verified, activated account.

### 5.1 Backups — `/v1/backups`

Format `org.meo.backup/v1`. The server **rejects anything else**: exactly the
keys `schema, createdAt, contents, secretsIncluded`; `secretsIncluded` must be
`false`; `contents` has exactly `applications`, `applicationsState`,
`settings`, `userData`.

- `applications[]`: `{id, sourceId}` or `{id, sourceId, version}`;
  `id` matches `^[A-Za-z0-9][A-Za-z0-9._+@-]{0,255}$`, `sourceId` matches
  `^[a-z0-9][a-z0-9-]{0,63}$`, `version` ≤120 chars with no control or
  bidirectional characters; up to 10 000 entries.
- `applicationsState`: `included` or `unavailable` (then the list must be
  empty). `userData` must be empty. `settings` may only contain
  `controlCenter` and `shell`: Meo Settings' own presentation settings.
  **OmniStore settings are not accepted.**
- So OmniStore can already contribute an **application inventory**
  (`id`, `sourceId`, `version`) but only inside a Meo Settings backup, which
  Meo Settings creates. A separate OmniStore backup format would need a new
  schema on the API side. Not defined.
- `GET /v1/backups` → `{backups, maximumBytes, maximumCount}`;
  `POST` → `201 {backup}`; `GET /:id` → `{backup}` with `content`;
  `DELETE /:id` → `{deleted:true}`. Full quota: `409 backup_limit_reached`;
  bad body: `400 invalid_backup`.
- The broker covers this already: `StartAccountOperation` with `list_backups`,
  `upload_backup` (`manifestJson`), `download_backup` / `delete_backup`
  (`backupId`). The result (`backupResultJson`) goes only to the manifest-bound
  caller.

### 5.2 Usage — `/v1/usage-events`, `/v1/usage-dashboard`

This is **AI token usage, not installed-application data.** Fields per event
(`source`, `source_event_id`, `session_id`, `project_key`, `project_name`,
`provider`, `model`, `model_role`, `occurred_at`, input / cached / cache-write /
output / reasoning tokens, `duration_ms`, `session_duration_ms`,
`estimated_cost_microusd`, `metadata`). `POST` takes a JSON **array** of 1–250
events (`400 invalid_usage_batch` / `invalid_usage_event`), idempotent on
`(user, source, source_event_id)`, and returns `202 {accepted: n}`.
`GET /v1/usage-dashboard?days=7..730` (default 365, else `400 invalid_days`).

The broker exposes the same through `/org/meo/Accounts1/Usage`
(`StartUsageOperation(clientId, action, payloadJson)`, `GetUsageRequest`) to
manifests with the `ai_usage_sync` capability. It discards every field outside
the list above before sending. OmniStore has no AI token counters of its own
(its AI goes through the broker), so there is nothing to upload. Not
implemented, and no `source` name has been chosen.

### 5.3 Realtime — `GET /v1/realtime`

Upgrades to a per-user change stream (Durable Object `UserHub`). Needs
`meo:read`. Event types named in the docs: `memory.changed`,
`settings.changed`, `projects.changed`, `files.changed`; the relay also emits
`run.delta`. The payload shapes are in `src/realtime.ts`, not in the prose docs.

### 5.4 Identity — `GET /v1/me`

"Compact current identity." The exact fields are not documented; read
`handleAccount` in `src/account.ts` before depending on any.

## 6. Error contract (all routes)

Body: `{"error": {"code": "…"}}`. Statuses: `400 invalid_request`,
`401 unauthenticated`, `403 insufficient_scope`, `403 reauth_required`,
`403 use_account_api` / `use_account_security_api`, `404` (missing **or not
yours**), `405 method_not_allowed`, `409`, `413 request_too_large`, `503`
(dependency or schema not ready, e.g. `mcp_storage_unavailable`).

Sensitive account actions need a purpose-scoped reauth grant
(`account_security`, `admin`, `billing`, `delete_account`; `POST
/v1/reauth/password|totp`, valid 600 s). A client may ask the user to
re-authenticate but must never mint, store or replay a grant.

## 7. Not defined (nobody has written it down)

| Gap | Where to resolve |
| --- | --- |
| A registered OmniStore OAuth client and its final id | meo-api owner (migration, 1.5) |
| Which scopes OmniStore should hold | decide per feature; start with `meo:read` |
| An OmniStore backup / sync schema | meo-api `src/backups.ts` accepts only `org.meo.backup/v1` |
| The fields of `/v1/me` and of the realtime event payloads | read the source before use |
| A published Meo-wide model list or per-plan model access | does not exist; entitlements are empty |
| Quotas per plan | none enforced; entitlements are empty |
| A streaming method on the D-Bus broker | does not exist |
| An official OpenAPI document for non-admin routes | `GET /v1/admin/api` is an admin-only catalogue and its payload schemas are "in source" |
| A public registration path for third-party clients | none; clients are added by migration |
