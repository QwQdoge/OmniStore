# OmniStore native MeoUI frontend contract

## Product decision

On MeoArch, OmniStore's canonical and only shipped graphical client is Qt 6 + QML + MeoUI.
The MeoArch Linux release path is native-only: it must not build, bundle, launch, or silently fall back to Flutter.

The historical `FlutterUI/` source tree may remain temporarily as migration/reference material while any still-valid behavior or localization is transferred. Its presence in Git does not make it a supported MeoArch runtime frontend, and new MeoArch UI work must not target it.

The release architecture is:

```text
OmniStore
├── Qt/QML client
│   └── MeoUI presentation
├── persistent transaction service
│   └── install/remove/update task ownership
├── Python backend
│   └── package/source/update authority
└── source plugins
```

The UI must never reimplement package-manager logic, repository trust, update policy, privilege handling, or source plugins.

## Navigation contract

Primary navigation is intentionally small:

- Home
- Explore
- Installed
- Updates
- Settings

Search is an app-bar capability rather than a permanent navigation destination.
Task/download progress is surfaced through the task app-bar action and expandable task side sheet rather than consuming permanent primary navigation.

The native client must evolve from this information architecture rather than reproducing the historical Flutter navigation one-for-one.

## Home and Explore

Home is a storefront surface, not a package-manager table. It may present featured, recommended, popular and recently updated software using runtime backend metadata.

Explore may present product categories, but category results must come from the backend/source contracts. The QML layer must not maintain a fake hard-coded application catalog.

Store-specific cards may live in OmniStore. Generic controls, typography, shapes, motion and adaptive-shell behavior belong in MeoUI.

## App details

App details should use available backend metadata such as:

- icon;
- screenshots;
- description;
- developer;
- source and version;
- license;
- installed/download size where known;
- variants;
- install location where appropriate.

Missing metadata is omitted or represented by a neutral fallback; the UI must not invent screenshots, ratings, versions, sizes, permissions or developer information.

Large windows should use an adaptive content/detail layout. Smaller windows may use a side sheet or full-page details surface. Backend JSON shape must not directly dictate presentation layout.

## Package transaction ownership

Install, remove and update operations are not owned by the graphical process.

The normal path is:

```text
QML / MeoUI
  -> TransactionClient
  -> private per-user Unix socket
  -> omnistore-task.service
  -> TransactionManager
  -> package backend
```

The service exposes named task operations (`task.submit`, `task.get`, `task.list`). Direct daemon package-mutation calls are not part of the client protocol.

Closing OmniStore must not cancel an active package transaction. Reopening the application reconnects to the service and restores task state. The service serializes native package mutations so multiple graphical clients cannot independently mutate the package database at the same time.

The release transport is a private socket under the user's runtime directory. A legacy loopback development transport may exist for compatibility/testing but is not the MeoArch release authority.

## Software sources

MeoArch should prioritize sources that are actually relevant and available on the running system.
The UI consumes runtime source metadata such as:

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

Developer-only backend dumps, environment bootstrap details and raw configuration belong in diagnostics/developer tooling, not the default settings page.

## MeoUI ownership

The native client uses the shared `MeoUI` module as its visual language. OmniStore may own store-specific page composition and components, but must not copy shared MeoUI controls into this repository.

Dynamic color, shape, typography, spacing and motion come from MeoUI/Meo desktop contracts. The client should adapt to desktop density rather than literally copying phone layouts.

## Flutter retirement state

The MeoArch release path has already crossed the runtime retirement boundary:

- Flutter is not built by `NativeUI/build_linux_release.py`;
- a native release bundle must contain `omnistore-native` and must not contain the legacy `frontend` artifact;
- the MeoArch launcher/package runs the native client directly and provides no Flutter runtime fallback;
- package transaction and source authority live outside either UI implementation.

Remaining Flutter source is migration/reference material only. Before deleting that tree, transfer any still-valid behavior that is not already represented elsewhere, such as useful localization strings, metadata presentation rules, tests or Account/consent behavior that remains part of the current product.

Deleting the historical tree must not be used as a reason to reimplement backend/package logic in QML.

## Application identity

The canonical application identity is:

```text
org.meo.OmniStore
```

The native application, desktop file, icon and Meo Account client identity should converge on this value. Legacy icon/file aliases may exist only where needed for upgrade compatibility and must not become the canonical identity again.

Release-visible version information is injected from the build/package version. Development builds report an explicit development version rather than a stale hard-coded product version.

## AI integration

Do not rebuild a separate OmniStore AI assistant in the native client.
AI-driven software actions should enter through the Meo system AI router and map to typed OmniStore capabilities such as search, plan installation, confirm, apply and verify.

## Release acceptance

The native MeoArch client is release-ready when:

1. core browse/search/details/install/remove/update flows work through one backend authority;
2. package mutations survive graphical client closure and can be recovered through task state;
3. source availability/trust/capability states are runtime-derived;
4. the client has usable localization for release languages;
5. app identity/version are build/package-derived rather than stale hard-coded UI values;
6. the MeoArch release bundle contains no Flutter runtime fallback;
7. package/repository validation and NativeUI build checks pass for the release revision.
