# Maintainer: OmniStore Team <contact@omnistore.dev>
pkgname=omnistore-git
pkgver=0.1.0.r0.g$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
pkgrel=1
pkgdesc="OmniStore: A unified software repository search and management tool built with Flutter, Rust, and Python."
arch=('x86_64')
url="https://github.com/QwQdoge/OmniStore"
license=('MIT')
depends=('krita' 'libdbusmenu-gtk3' 'libappindicator-gtk3')
makedepends=('git' 'flutter' 'cargo' 'python-pyinstaller' 'python-pip')
source=('omnistore::git+https://github.com/QwQdoge/OmniStore.git')
md5sums=('SKIP')

pkgver() {
  cd "$srcdir/omnistore"
  git describe --long --tags | sed 's/\([^-]*-g\)/r\1/;s/-/./g' || echo "0.1.0"
}

build() {
  cd "$srcdir/omnistore"

  echo "=== use auto_build.py to build everything ==="
  # 确保 python 依赖已安装 (PKGBUILD 环境通常需要)
  pip install -r python/requirements.txt

  python auto_build.py --all
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
}
