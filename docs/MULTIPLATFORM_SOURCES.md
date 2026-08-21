# OmniStore Multi-platform Source Policy

OmniStore should start from a clean operating-system installation and discover capabilities instead of assuming Arch Linux or requiring optional package managers to be installed in advance.

## Default policy

| Platform / distro family | Native source | Recommended application sources | Bootstrap behavior |
| --- | --- | --- | --- |
| Arch / CachyOS / Manjaro / EndeavourOS | Pacman | Pacman, Flatpak/Flathub, AppImage, optional AUR | Install Flatpak if missing; add user Flathub; install git/base-devel and yay-bin if AUR is selected and no yay/paru exists |
| Debian / Ubuntu / Mint / Pop!_OS / Zorin | APT | APT, Flatpak/Flathub, AppImage | `apt-get update`, install Flatpak if missing, add user Flathub |
| Fedora / RHEL family / Nobara / Rocky / AlmaLinux | DNF | DNF, Flatpak/Flathub, AppImage | Install Flatpak with DNF if missing, add user Flathub |
| Fedora Atomic / Silverblue / Kinoite / rpm-ostree host | image-managed host | Flatpak/Flathub, AppImage | Do not mutate the host through DNF; configure user Flathub only |
| openSUSE | Zypper | Zypper, Flatpak/Flathub, AppImage | Install Flatpak with Zypper if missing, add user Flathub |
| Alpine | APK | APK, Flatpak/Flathub, AppImage | Install Flatpak with APK when available, add user Flathub |
| Windows | Winget when present | Winget | Do not silently install third-party package managers |
| macOS | Homebrew when present | Homebrew | Do not silently install Homebrew |

## Safety rules

- Never enable APT, DNF, Pacman, Zypper, or APK merely because the operating system is Linux. Enable only the native manager detected for the current distribution.
- Package-manager search/list/details operations stay unprivileged. Host installation and removal request privilege only when needed.
- Flatpak is a cross-distribution desktop application source. OmniStore configures Flathub per-user rather than modifying system-wide remotes by default.
- AUR is Arch-specific and remains an explicit user choice because packages execute community PKGBUILDs. OmniStore may prepare `yay-bin` or use an existing `yay`/`paru` helper.
- Immutable Fedora-style hosts are not treated like mutable DNF systems.
- Optional sources that are not installed must report themselves unavailable instead of crashing search or falsely reporting success.
- Source enablement and search enablement are persisted together so the plugin registry and SearchManager cannot disagree.
- Configuration changes must become visible to the daemon without restarting OmniStore.

## Source priority

The distribution's native source should rank above third-party alternatives. Flatpak is the preferred cross-distribution GUI application fallback, followed by AppImage. AUR is useful on Arch but should not outrank official repositories.

The preference is a ranking aid, not an absolute rule: an exact package match, source availability, package freshness, sandbox needs, publisher trust, and user selection can override the default order.
