pkgname=omnistore-bin
pkgver=0.1.2
pkgrel=6
pkgdesc="OmniStore software manager with the native MeoUI frontend"
arch=('x86_64')
options=('!strip' '!debug')
url="https://github.com/QwQdoge/OmniStore"
license=('GPL-3.0-only')
depends=('qt6-base' 'qt6-declarative' 'meoui-qml' 'meo-kde-runtime'
         'ksshaskpass' 'libsecret' 'pacman-contrib' 'python' 'pyalpm')
optdepends=('meo-release: shared MeoArch application catalog and channel integration'
            'meo-account: use Meo Account'
            'flatpak: install applications from Flatpak remotes')
makedepends=('python')
provides=('omnistore')
conflicts=('omnistore' 'omnistore-git')
_release_tag="v${pkgver}"
_release_asset="omnistore-linux-x64.tar.gz"
_release_archive="omnistore-${_release_tag}-linux-x64.tar.gz"
source=("${_release_archive}::https://github.com/QwQdoge/OmniStore/releases/download/${_release_tag}/${_release_asset}"
        'verify_release_exporter_contract.py')
noextract=("${_release_archive}")
sha256sums=('SKIP'
            'd4b7694e512898a32907be3a4fdf76ffba994b001ae2c957c0533b31b59c0773')

_release_source_dir() {
  if [ -x "$srcdir/release_bundle/backends/python_server" ] \
      && [ -x "$srcdir/release_bundle/omnistore-native" ] \
      && [ -d "$srcdir/release_bundle/data" ]; then
    printf '%s\n' "$srcdir/release_bundle"
  else
    return 1
  fi
}

prepare() {
  local _bundle_dir="$srcdir/release_bundle"
  if [ -e "$_bundle_dir" ]; then
    error "Stale release extraction path exists; use a clean makepkg srcdir."
    return 1
  fi
  install -d "$_bundle_dir"
  if ! bsdtar -xf "$srcdir/$_release_archive" -C "$_bundle_dir"; then
    error "Could not extract the OmniStore release bundle."
    return 1
  fi

  local _src_dir
  _src_dir="$(_release_source_dir)" || {
    error "Could not find the native OmniStore release bundle."
    return 1
  }

  test ! -e "$_src_dir/frontend" || {
    error "Native MeoArch release bundle must not contain the retired Flutter frontend."
    return 1
  }
  test -f "$_src_dir/data/systemd/user/omnistore-task.service" || {
    error "Native release bundle is missing the transaction service unit."
    return 1
  }

  python "$srcdir/verify_release_exporter_contract.py" \
    --backend "$_src_dir/backends/python_server"
}

package() {
  install -d "${pkgdir}/opt/omnistore"

  local _src_dir
  _src_dir="$(_release_source_dir)" || {
    error "Could not find the verified native OmniStore release bundle."
    return 1
  }

  cp -r "$_src_dir"/* "${pkgdir}/opt/omnistore/"

  test -x "${pkgdir}/opt/omnistore/backends/meo_stable_rollback.py" || {
    error "Verified release bundle is missing the Stable rollback root helper."
    return 1
  }
  install -Dm755 "${pkgdir}/opt/omnistore/backends/meo_stable_rollback.py" \
    "${pkgdir}/usr/lib/omnistore/meo-stable-rollback.py"
  test -x "${pkgdir}/opt/omnistore/backends/meo_repository_helper.py" || {
    error "Verified release bundle is missing the Pacman repository helper."
    return 1
  }
  install -Dm755 "${pkgdir}/opt/omnistore/backends/meo_repository_helper.py" \
    "${pkgdir}/usr/lib/omnistore/meo-repository-helper.py"

  install -Dm644 "$_src_dir/data/meo-account/org.meo.OmniStore.json" \
    "${pkgdir}/usr/share/meo-account/clients/org.meo.OmniStore.json"

  install -d "${pkgdir}/usr/bin"
  cat > "${pkgdir}/usr/bin/omnistore-native" <<'EOF'
#!/bin/sh
set -eu
cd /opt/omnistore
exec /opt/omnistore/omnistore-native "$@"
EOF
  chmod +x "${pkgdir}/usr/bin/omnistore-native"

  cat > "${pkgdir}/usr/bin/omnistore" <<'EOF'
#!/bin/sh
set -eu
exec /usr/bin/omnistore-native "$@"
EOF
  chmod +x "${pkgdir}/usr/bin/omnistore"

  cat > "${pkgdir}/usr/bin/omnistore-daemon" <<'EOF'
#!/bin/sh
set -eu
cd /opt/omnistore
exec /opt/omnistore/backends/python_server "$@"
EOF
  chmod +x "${pkgdir}/usr/bin/omnistore-daemon"

  cat > "${pkgdir}/usr/bin/omnistore-apps-export" <<'EOF'
#!/bin/sh
# Stable, read-only ABI for Meo Settings.
set -eu
if [ "$#" -ne 0 ]; then
  echo "omnistore-apps-export takes no arguments" >&2
  exit 64
fi
cd /opt/omnistore
exec /opt/omnistore/backends/python_server --export-installed-usage --json
EOF
  chmod +x "${pkgdir}/usr/bin/omnistore-apps-export"

  cat > "${pkgdir}/usr/bin/omnistore-apps" <<'EOF'
#!/bin/sh
set -eu
cd /opt/omnistore
command="${1:-}"
[ "$#" -ge 1 ] && shift || true
case "$command" in
  export)
    [ "$#" -eq 0 ] || { echo "omnistore-apps export takes no arguments" >&2; exit 64; }
    exec /opt/omnistore/backends/python_server --export-app-management --json
    ;;
  clear-cache|reset-settings|clear-data|uninstall)
    [ "$#" -eq 2 ] || { echo "omnistore-apps $command requires APP_ID SOURCE" >&2; exit 64; }
    exec /opt/omnistore/backends/python_server --app-action "$command" --app-id "$1" --source "$2" --json
    ;;
  *)
    echo "usage: omnistore-apps export | {clear-cache|reset-settings|clear-data|uninstall} APP_ID SOURCE" >&2
    exit 64
    ;;
esac
EOF
  chmod +x "${pkgdir}/usr/bin/omnistore-apps"

  cat > "${pkgdir}/usr/bin/omnistore-cli" <<'EOF'
#!/bin/sh
set -eu
cd /opt/omnistore
exec /opt/omnistore/backends/python_server "$@"
EOF
  chmod +x "${pkgdir}/usr/bin/omnistore-cli"

  cat > "${pkgdir}/usr/bin/meo-update" <<'EOF'
#!/bin/sh
set -eu
backend=/opt/omnistore/backends/python_server
command="${1:-help}"
[ "$#" -eq 0 ] || shift
case "$command" in
  check) exec "$backend" --check-updates --json "$@" ;;
  status) exec "$backend" --update-status --json "$@" ;;
  plan) exec "$backend" --update-plan --json "$@" ;;
  background) exec "$backend" --background-update-check --json "$@" ;;
  apply) exec "$backend" --update all --source all --json "$@" ;;
  repositories) exec "$backend" --list-custom-repos --json "$@" ;;
  help|-h|--help)
    echo 'Usage: meo-update {check|status|plan|background|apply|repositories}'
    ;;
  *) echo "Unknown meo-update command: $command" >&2; exit 64 ;;
esac
EOF
  chmod +x "${pkgdir}/usr/bin/meo-update"

  cat > "${pkgdir}/usr/bin/omnistore-cleanup-systemd" <<'EOF'
#!/bin/sh
set -eu
systemctl --user disable --now omnistore-update.timer >/dev/null 2>&1 || true
systemctl --user stop omnistore-update.service >/dev/null 2>&1 || true
systemctl --user stop omnistore-task.service >/dev/null 2>&1 || true
rm -f "$HOME/.config/systemd/user/omnistore-update.timer"
rm -f "$HOME/.config/systemd/user/omnistore-update.service"
rm -f "$HOME/.config/systemd/user/omnistore-update.timer.d/interval.conf"
rmdir "$HOME/.config/systemd/user/omnistore-update.timer.d" >/dev/null 2>&1 || true
systemctl --user daemon-reload >/dev/null 2>&1 || true
echo "OmniStore user systemd overrides removed and services stopped."
EOF
  chmod +x "${pkgdir}/usr/bin/omnistore-cleanup-systemd"

  install -Dm644 "$_src_dir/data/systemd/user/omnistore-task.service" \
    "${pkgdir}/usr/lib/systemd/user/omnistore-task.service"
  install -Dm644 "$_src_dir/data/systemd/user/omnistore-update.service" \
    "${pkgdir}/usr/lib/systemd/user/omnistore-update.service"
  install -Dm644 "$_src_dir/data/systemd/user/omnistore-update.timer" \
    "${pkgdir}/usr/lib/systemd/user/omnistore-update.timer"

  for doc in UNIFIED_UPDATES.md NATIVE_MEOUI_FRONTEND.md TRANSACTION_RELEASE_CONTRACT.md; do
    if [ -f "$_src_dir/data/docs/$doc" ]; then
      install -Dm644 "$_src_dir/data/docs/$doc" \
        "${pkgdir}/usr/share/doc/omnistore/$doc"
    fi
  done
  install -Dm644 "$_src_dir/LICENSE" \
    "${pkgdir}/usr/share/licenses/$pkgname/LICENSE"

  install -Dm644 "$_src_dir/omnistore.svg" \
    "${pkgdir}/usr/share/icons/hicolor/scalable/apps/org.meo.OmniStore.svg"
  install -Dm644 "$_src_dir/omnistore.svg" \
    "${pkgdir}/usr/share/icons/hicolor/scalable/apps/omnistore.svg"

  install -d "${pkgdir}/usr/share/applications"
  cat > "${pkgdir}/usr/share/applications/org.meo.OmniStore.desktop" <<'EOF'
[Desktop Entry]
Version=1.0
Name=OmniStore
GenericName=App Store
GenericName[zh_CN]=应用商店
Comment=Unified software store for MeoArch
Comment[zh_CN]=MeoArch 的统一软件商店
Keywords=apps;software;packages;updates;MeoArch;
Keywords[zh_CN]=应用;软件;软件包;更新;MeoArch;
Exec=/usr/bin/omnistore %u
Icon=org.meo.OmniStore
Terminal=false
Type=Application
Categories=Utility;PackageManager;
MimeType=x-scheme-handler/omnistore;
StartupNotify=true
EOF
}
