pkgname=omnistore-bin
pkgver=0.1.0.beta
pkgrel=1
pkgdesc="OmniStore: A unified software repository search and management tool built with Flutter, Rust, and Python."
arch=('x86_64')
options=('!strip' '!debug')
url="https://github.com/QwQdoge/OmniStore"
license=('MIT')
depends=('krita' 'libdbusmenu-gtk3' 'libappindicator-gtk3')
provides=('omnistore')
conflicts=('omnistore' 'omnistore-git')
source=("omnistore-v${pkgver}-linux-x64.tar.gz::https://github.com/QwQdoge/OmniStore/releases/download/v${pkgver}/omnistore-v${pkgver}-linux-x64.tar.gz"
        "omnistore.svg::https://raw.githubusercontent.com/QwQdoge/OmniStore/v${pkgver}/omnistore.svg")
sha256sums=('SKIP' 'SKIP')
# Define a user-writable pkgdir to avoid permission issues
pkgdir=${HOME}/pkg/omnistore

package() {
  # 1. 创建安装到系统 /opt/omnistore 的目录
  install -d "${pkgdir}/opt/omnistore" 

  # 2. 拷贝解压出来的所有东西 (根据实际解压目录进行拷贝)
  if [ -d "$srcdir/release_bundle" ]; then
    cp -r "$srcdir/release_bundle"/* "${pkgdir}/opt/omnistore/"
  elif [ -d "$srcdir/omnistore-v${pkgver}-linux-x64" ]; then
    cp -r "$srcdir/omnistore-v${pkgver}-linux-x64"/* "${pkgdir}/opt/omnistore/"
  else
    # 假设直接解压在 $srcdir
    for item in frontend lib data backends; do
      if [ -e "$srcdir/$item" ]; then
        cp -r "$srcdir/$item" "${pkgdir}/opt/omnistore/"
      fi
    done
  fi

  # 3. 在系统的 /usr/bin 下建一个软链接
  install -d "${pkgdir}/usr/bin"
  echo -e '#!/bin/sh\ncd /opt/omnistore && ./frontend "$@"' > "${pkgdir}/usr/bin/omnistore"
  chmod +x "${pkgdir}/usr/bin/omnistore"

  # 4. 安装图标
  install -d "${pkgdir}/usr/share/pixmaps"
  install -m644 "$srcdir/omnistore.svg" "${pkgdir}/usr/share/pixmaps/omnistore.svg"

  # 5. 安装桌面文件
  install -d "${pkgdir}/usr/share/applications"
  cat > "${pkgdir}/usr/share/applications/omnistore.desktop" <<EOF
[Desktop Entry]
Name=OmniStore
Comment=A unified software repository search and management tool built with Flutter, Rust, and Python.
Exec=/opt/omnistore/frontend
Icon=/opt/omnistore/omnistore.svg
Terminal=false
Type=Application
Categories=Utility;
EOF
}
