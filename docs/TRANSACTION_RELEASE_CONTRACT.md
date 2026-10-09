# OmniStore transaction and release contract

## Purpose

OmniStore is MeoArch's package/source authority. Graphical clients, Meo Settings, the updater and other system components may request software actions, but they must not become independent package managers.

This contract defines the release-critical boundaries for package mutation, task lifetime, system integration, version identity and legacy update paths.

## One package authority

All package mutations must flow through OmniStore-owned typed operations. Callers must not construct privileged `pacman`, `flatpak`, AUR-helper or repository-management shell commands themselves.

The long-term operation model is:

```text
caller
  -> plan typed action
  -> review exact plan
  -> confirm
  -> transaction service owns mutation
  -> progress/status stream
  -> verify resulting state
  -> structured result
```

This model is shared by the OmniStore UI, Meo Settings and future system capabilities such as input-method, language-pack, font, codec, printer-support and optional-component installation.

## Transaction lifetime

A package mutation must not be owned by a QML window or a frontend `QProcess` lifetime.

Closing OmniStore must not implicitly terminate an in-progress install, remove or update operation. The final architecture should place mutating work in an OmniStore task/transaction service whose lifetime is independent from the graphical client.

Until that service owns mutations, the native client must fail safe: it must prevent normal window closure while a backend operation is in progress rather than destructing the child process mid-transaction.

Explicit cancellation is a separate typed operation. Cancellation must be supported only where the underlying package operation can be interrupted safely; closing the UI is not cancellation.

Task snapshots expose an additive `authenticationPrompt` string for a running
PAM fingerprint conversation. The backend forwards sudo's informational output
as it arrives; the frontend displays the prompt with a fingerprint indicator.
Ordinary command output and terminal task states clear the prompt. Passwords
remain inside sudo's graphical askpass helper, and fingerprint verification
remains owned by PAM. The UI never treats this informational field as approval.

## Stable install contract

The public install/remove API should be versioned and structured. A caller should request an intent/capability rather than know the package-manager command when possible.

Example conceptual plan request:

```text
PlanInstall(capability = "input.japanese.mozc")
```

The plan should expose at least:

- schema/version;
- exact source/resource identity;
- package IDs and actions;
- download size when known;
- disk delta when known;
- privilege requirement;
- trust/signature status;
- warnings/conflicts;
- canonical plan hash.

`ApplyPlan(planHash)` must apply the exact reviewed plan or reject it if source state changed. The result should report completed/failed actions and verification state.

Raw user-supplied filesystem paths or arbitrary root commands are not part of this contract.

## Updates

`docs/UNIFIED_UPDATES.md` remains authoritative for system updates. Background checking may discover and notify about updates, but background checking must not silently install native system updates.

The old long-running auto-update behavior in `python/daemon_main.py` is legacy behavior and is not a release authority. It must not be wired back into the MeoArch release path. The package-owned systemd user timer/one-shot update check remains the supported background update model unless this contract is deliberately revised.

## Daemon distinction

Do not conflate these roles:

- request/task server: accepts allowlisted typed frontend operations;
- background update checker: performs scheduled read/check work;
- privileged package helper: performs narrow reviewed privileged changes.

They may share backend code but must retain different security and lifecycle contracts.

## Frontend behavior

The native QML client is presentation and task control. It may:

- submit typed reads and mutations;
- show confirmation before mutation;
- show task progress/logs/status;
- reconnect to task state;
- request safe cancellation where supported.

It must not:

- own the durable lifetime of package mutation;
- silently enable untrusted sources;
- weaken repository signature policy;
- run arbitrary root commands;
- claim a source capability that the runtime backend does not expose.

## Source capability state

Source state must be detected rather than guessed or hard-coded into the UI. UI availability should derive from plugin/runtime metadata including platform support, required executable/backend presence, enabled state, capabilities, trust, review requirement and current error state.

Unavailable platform-specific providers may remain installed as code/plugins but should not be presented as normal usable stores.

## Version and application identity

Release-visible application version must come from build/release metadata, not a stale source literal such as `0.1.0-native`.

Canonical MeoArch identity target:

- product name: `OmniStore`;
- canonical app identity: `org.meo.OmniStore`;
- desktop entry/icon/Wayland grouping should converge on the canonical identity;
- compatibility aliases may remain temporarily where changing them would break an existing release contract.

The native build must permit the release pipeline/package recipe to inject the exact release version.

## Localization

User-visible native QML strings should use Qt translation mechanisms and release builds must compile/install the supported language catalogs. `qsTr()` markers without a translation build/install path do not count as localization support.

## Release UI hygiene

Update-all tasks expose additive `sourceUpdates` entries with `source`, `status`
(`queued`, `running`, `succeeded`, `failed`, `skipped`), `detail`, and nullable
`progress`. They remain available through task snapshots after GUI reconnection.
Overall update progress counts finished source phases; it is not a byte-weighted
download percentage. Per-source progress describes the current package-manager
operation and may restart between downloads, installation and verification.
Absent percentages are indeterminate. Failure in one source does not hide the
remaining source outcomes. Update-all currently covers the selected native
manager, user Flatpak, and explicitly opted-in AUR; it does not imply that every
source plugin supports unattended bulk updates.

Raw backend JSON, build-environment repair, implementation paths and developer diagnostics are not normal user settings. They belong behind an Advanced/Diagnostics surface when they remain useful.

Environment repair should normally route through the Meo Repair/system repair contract rather than teaching the store to bootstrap a development environment.

## Release blockers

For the MeoArch release, treat these as blockers:

1. normal UI close can terminate an active package mutation;
2. different graphical frontends expose materially different release-critical behavior;
3. Settings or another caller must invoke raw privileged package commands instead of a bounded OmniStore contract;
4. stale hard-coded app version/identity leaks into release UI;
5. legacy background auto-install behavior is shipped or enabled as the supported updater;
6. source UI presents unavailable/untrusted capabilities as normal working sources.
