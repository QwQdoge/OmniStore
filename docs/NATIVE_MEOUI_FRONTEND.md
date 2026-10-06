# OmniStore native MeoUI frontend contract

## Product decision

On MeoArch, OmniStore's canonical graphical client is Qt 6 + QML + MeoUI.
Flutter is a migration artifact, not a second long-term MeoArch product surface.
New MeoArch UI work must target the native client and must not add new Flutter-only features.

The target architecture is:

```text
OmniStore
├── app/native Qt/QML client
│   └── MeoUI presentation only
├── Python backend
│   └── package/source/update authority
├── source plugins
└── package/update transaction services
```

The UI must never reimplement package-manager logic, repository trust, update policy, privilege handling, or source plugins.

## Navigation target

The primary navigation should remain intentionally small:

- Home
- Explore
- Installed
- Updates
- Settings

Search is a top-level app-bar capability rather than a permanent navigation destination.
Task/download progress is surfaced through a persistent task indicator and expandable side sheet or task surface rather than consuming a permanent primary navigation destination.

The current NativeUI pages may be migrated incrementally, but new information architecture should follow this contract instead of reproducing the Flutter navigation one-for-one.

## App details

Large windows should use an adaptive content/detail layout with app identity, install/update action, screenshots, description, source, version, storage and permission information.
Smaller windows may use a side sheet or full-page details surface.
Backend JSON shape must not directly dictate presentation layout.

## Software sources

MeoArch should prioritize sources that are actually relevant and available on the running system.
The UI must consume runtime source metadata such as:

- `available`
- `enabled`
- `capabilities`
- `trusted`
- `requires_review`
- `error`

Unavailable platform-specific sources must not be presented as normal enabled sources.
Meo/Arch repositories and Flatpak are normal MeoArch sources. AUR is an explicit community source. GitHub, AppImage and other specialized sources belong under advanced source management unless product requirements promote them.

## Settings presentation

The release UI must not expose raw backend JSON as a normal settings experience.
Normal settings should present product concepts such as:

- update checks and notifications;
- software sources;
- downloads and cache;
- update channel;
- storage/cache usage;
- repository management;
- diagnostics under an Advanced section.

Developer-only backend dumps, environment bootstrap details, and raw configuration belong in diagnostics/developer tooling, not the default settings page.

## MeoUI ownership

The native client uses the shared `MeoUI` module as its visual language. OmniStore may own store-specific page composition and components, but must not copy shared MeoUI controls into this repository.

Dynamic color, shape, typography, spacing and motion come from MeoUI/Meo desktop contracts. The client should adapt to desktop density rather than literally copying phone layouts.

## Flutter retirement

Flutter removal is allowed only after the native client has covered the release-critical MeoArch workflows and any still-valid behavior has been transferred to shared backend contracts or the native client.

Before deletion, preserve only behavior that is still required, such as:

- localization strings worth retaining;
- Account/consent behavior that remains valid;
- metadata presentation rules;
- tests that encode still-supported behavior.

Once parity is sufficient for MeoArch:

- remove Flutter from the MeoArch release bundle;
- remove the runtime Flutter fallback from the MeoArch launcher/package;
- remove Flutter-only Linux CI and packaging paths;
- rename `NativeUI` to a canonical app/ui location only when doing so will not destabilize the release.

Flutter must not remain a hidden feature fallback where the available feature set changes depending on whether MeoUI starts successfully.

## AI integration

Do not rebuild a separate OmniStore AI assistant in the native client.
AI-driven software actions should enter through the Meo system AI router and map to typed OmniStore capabilities such as search, plan installation, confirm, apply and verify.

## Release acceptance

The native MeoArch client is release-ready when:

1. core browse/search/details/install/remove/update flows work through one backend authority;
2. package mutations are not owned by the graphical process lifetime;
3. source availability/trust/capability states are runtime-derived;
4. the client has usable localization for release languages;
5. app identity/version are build/package-derived rather than stale hard-coded UI values;
6. no release-critical workflow requires falling back to the Flutter client.
