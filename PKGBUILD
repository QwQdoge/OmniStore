pkgname=omnistore-bin
pkgver=0.1.2
pkgrel=1
pkgdesc="OmniStore: A unified software repository search and management tool built with Flutter, Rust, and Python."
arch=('x86_64')
options=('!strip' '!debug')
url="https://github.com/QwQdoge/OmniStore"
license=('MIT')
depends=('gtk3' 'libdbusmenu-gtk3' 'libayatana-appindicator' 'ksshaskpass')
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
            '006c8dfd197ecf1634fecd78503cadead23a16105fbaa9d7ae7c0ae7442cb2a4')

_release_source_dir() {
  if [ -x "$srcdir/release_bundle/backends/python_server" ] \
      && [ -x "$srcdir/release_bundle/frontend" ] \
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
    error "Could not find the extracted OmniStore release bundle."
    return 1
  }

  # Do not ship a command which a stale release backend cannot implement.
  # The verifier runs the bundled binary with an isolated XDG environment and
  # requires the exact schema consumed by Meo Settings.
  python "$srcdir/verify_release_exporter_contract.py" \
    --backend "$_src_dir/backends/python_server"
}

package() {
  # 1. 创建安装到系统 /opt/omnistore 的目录
  install -d "${pkgdir}/opt/omnistore" 

  # 确定源文件目录
  local _src_dir
  _src_dir="$(_release_source_dir)" || {
    error "Could not find the verified OmniStore release bundle."
    return 1
  }

  # 2. 拷贝解压出来的所有东西
  cp -r "$_src_dir"/* "${pkgdir}/opt/omnistore/"

  # 3. 在系统的 /usr/bin 下建一个软链接
  install -d "${pkgdir}/usr/bin"
  echo -e '#!/bin/sh\ncd /opt/omnistore && ./frontend "$@"' > "${pkgdir}/usr/bin/omnistore"
  chmod +x "${pkgdir}/usr/bin/omnistore"
  cat > "${pkgdir}/usr/bin/omnistore-apps-export" <<'EOF'
#!/bin/sh
# Stable, read-only ABI for Meo Settings.  It deliberately calls the bundled
# Python backend instead of opening the Flutter GUI or connecting to a daemon.
set -eu
if [ "$#" -ne 0 ]; then
  echo "omnistore-apps-export takes no arguments" >&2
  exit 64
fi
cd /opt/omnistore
exec /opt/omnistore/backends/python_server --export-installed-usage --json
EOF
  chmod +x "${pkgdir}/usr/bin/omnistore-apps-export"
  cat > "${pkgdir}/usr/bin/omnistore-cleanup-systemd" <<'EOF'
#!/bin/sh
set -eu
systemctl --user disable --now omnistore-update.timer >/dev/null 2>&1 || true
systemctl --user stop omnistore-update.service >/dev/null 2>&1 || true
rm -f "$HOME/.config/systemd/user/omnistore-update.timer"
rm -f "$HOME/.config/systemd/user/omnistore-update.service"
systemctl --user daemon-reload >/dev/null 2>&1 || true
echo "OmniStore user systemd units removed."
EOF
  chmod +x "${pkgdir}/usr/bin/omnistore-cleanup-systemd"

  # 4. 安装图标到系统图标库，以便桌面环境自动识别
  install -Dm644 "$_src_dir/omnistore.svg" "${pkgdir}/usr/share/icons/hicolor/scalable/apps/omnistore.svg"

  # 5. 安装桌面文件
  install -d "${pkgdir}/usr/share/applications"
  cat > "${pkgdir}/usr/share/applications/omnistore.desktop" <<EOF
[Desktop Entry]
Name=OmniStore
Comment=A unified software repository search and management tool built with Flutter, Rust, and Python.
Exec=/usr/bin/omnistore
Icon=omnistore
Terminal=false
Type=Application
Categories=Utility;
EOF
}
