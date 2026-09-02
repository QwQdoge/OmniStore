# Unified Meo update contract

`meo-update` is the packaged command-line entry point shared by OmniStore,
Meo Settings, notifications, and the systemd user timer. OmniStore's Python
backend owns the implementation and all package mutations. Meo Settings reads
the versioned state and links to OmniStore for actions; it does not become a
second privileged package manager.

## Commands and state

- `meo-update check` checks enabled sources and writes
  `$XDG_STATE_HOME/meo-update/state.json` atomically.
- `meo-update status` returns the last versioned state without network or
  package mutation.
- `meo-update plan` returns a canonical SHA-256 plan and the individual
  resources which produced it.
- `meo-update background` performs the same check and may notify the desktop;
  it never installs packages.
- `meo-update apply` is an explicit foreground action. Pacman repository
  packages are always upgraded through one full `pacman -Syu` transaction.

Every candidate retains `resource_id`, `source_id`, package ID, versions, and
repository when available. UI grouping must not merge those identities. This
preserves OmniStore's one-source/one-resource-package model even though Arch
repository packages must be applied as one complete system transaction.

The package installs `omnistore-update.service` and
`omnistore-update.timer`. Settings writes only a user timer interval drop-in;
the executable and base units remain package-owned. The timer is a persistent
one-shot checker rather than a root-resident daemon. OmniStore's optional tray
is the only long-lived desktop process.

## Pacman repository management

Custom Pacman repositories are rendered into
`/etc/pacman.d/omnistore-repositories.conf`, with one include line added to
`/etc/pacman.conf`. The narrow root helper receives the complete desired
managed set and only changes that fragment. It:

- accepts HTTPS servers only;
- fixes `SigLevel` to `Required DatabaseOptional`, so package signatures are
  mandatory;
- never downloads/imports keys or weakens trust;
- never runs `pacman -Sy`;
- refuses Arch, Meo, and CachyOS reserved repository names;
- refuses to take ownership of a repository already configured elsewhere;
- preserves non-UTF-8 bytes in the existing Pacman configuration.

Meo Stable/Beta remain package-owned by `meo-channel-stable` and
`meo-channel-beta`. CachyOS is an optional external distribution preset: only
its official keyring/mirrorlist/packages may establish trust, and OmniStore
does not silently bootstrap or enable it. Existing CachyOS repositories are
shown as externally managed.

## Complete-update follow-up

After a successful explicit update, the orchestrator reports a pending kernel
reboot, `.pacnew` files, and failed systemd units. It does not delete orphans,
clear caches, process configuration files, restart services, or reboot without
a separate user action.

## Upstream references and licensing

The background cadence and maintenance checklist were informed by
[CachyOS/cachy-update](https://github.com/CachyOS/cachy-update), a
GPL-3.0-or-later fork of Arch-Update, and the mirror refresh separation by
[CachyOS-PKGBUILDS/cachyos-rate-mirrors](https://github.com/CachyOS/CachyOS-PKGBUILDS/tree/master/cachyos-rate-mirrors).
The full-upgrade rule follows the
[Arch Linux system maintenance guidance](https://wiki.archlinux.org/title/System_maintenance).

No CachyOS/Arch-Update source code is copied into OmniStore. The Meo
implementation is independently written under this repository's MIT license;
the links and behavioral influence are recorded here for provenance.
