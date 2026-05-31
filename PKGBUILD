# Maintainer: OmniStore Team <contact@omnistore.dev>
pkgname=omnistore-git
pkgver=v0.1.0.beta
pkgrel=1
pkgdesc="OmniStore: A unified software repository search and management tool built with Flutter, Rust, and Python."
arch=('x86_64')
options=('!strip' '!debug')
url="https://github.com/QwQdoge/OmniStore"
license=('MIT')
depends=('krita' 'libdbusmenu-gtk3' 'libappindicator-gtk3')
makedepends=('git' 'cargo' 'pyinstaller' 'python-pip')
source=('omnistore::git+https://github.com/QwQdoge/OmniStore.git')
md5sums=('SKIP')

pkgver() {
  cd "$srcdir/omnistore"
  git describe --long --tags | sed 's/\([^-]*-g\)/r\1/;s/-/./g' || echo "0.1.0"
}

build() {
  cd "$srcdir/omnistore"

  export PIP_NO_CACHE_DIR=1

  echo "=== use auto_build.py to build everything ==="
  # 确保 python 依赖已安装 (PKGBUILD 环境通常需要)
  pip install -r python/requirements.txt

  python auto_build.py --all

  if not any(vars(arg).values()):
    parser.print_help()
    sys.exit(1)
}

package() {
  cd "$srcdir/omnistore"

  # 1. 创建安装到系统 /opt/omnistore 的目录
  install -d "${pkgdir}/opt/omnistore" 

  # 2. 拷贝 Flutter bundle 里的所有东西 (由 auto_build.py 生成)
  # 注意：auto_build.py 已经把 backends 组装到了 bundle 目录里
  cp -r FlutterUI/build/linux/x64/release/bundle/* "${pkgdir}/opt/omnistore/"

  # 3. 在系统的 /usr/bin 下建一个软链接
  install -d "${pkgdir}/usr/bin"
  echo -e '#!/bin/sh\ncd /opt/omnistore && ./frontend "$@"' > "${pkgdir}/usr/bin/omnistore"
  chmod +x "${pkgdir}/usr/bin/omnistore"

  # 4. 安装图标
  install -d "${pkgdir}/usr/share/pixmaps"
  install -m644 omnistore.svg "${pkgdir}/usr/share/pixmaps/omnistore.svg"

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

  chmod +x "${pkgdir}/usr/share/applications/omnistore.desktop"
}
