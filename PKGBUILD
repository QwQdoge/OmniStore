pkgname=omnistore-bin
pkgver=0.1.1
pkgrel=1
pkgdesc="OmniStore: A unified software repository search and management tool built with Flutter, Rust, and Python."
arch=('x86_64')
options=('!strip' '!debug')
url="https://github.com/QwQdoge/OmniStore"
license=('MIT')
depends=('gtk3' 'libdbusmenu-gtk3' 'libayatana-appindicator')
provides=('omnistore')
conflicts=('omnistore' 'omnistore-git')
_release_tag="v${pkgver}"
source=("omnistore-${_release_tag}-linux-x64.tar.gz::https://github.com/QwQdoge/OmniStore/releases/download/${_release_tag}/omnistore-linux-x64.tar.gz")
sha256sums=('SKIP')

package() {
  # 1. 创建安装到系统 /opt/omnistore 的目录
  install -d "${pkgdir}/opt/omnistore" 

  # 确定源文件目录
  local _src_dir
  if [ -d "$srcdir/release_bundle" ]; then
    _src_dir="$srcdir/release_bundle"
  elif [ -d "$srcdir/omnistore-linux-x64" ]; then
    _src_dir="$srcdir/omnistore-linux-x64"
  else
    _src_dir="$srcdir"
  fi

  # 2. 拷贝解压出来的所有东西
  cp -r "$_src_dir"/* "${pkgdir}/opt/omnistore/"

  # 3. 在系统的 /usr/bin 下建一个软链接
  install -d "${pkgdir}/usr/bin"
  echo -e '#!/bin/sh\ncd /opt/omnistore && ./frontend "$@"' > "${pkgdir}/usr/bin/omnistore"
  chmod +x "${pkgdir}/usr/bin/omnistore"
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
