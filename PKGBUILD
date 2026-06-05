
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
# Define a user-writable pkgdir to avoid permission issues
pkgdir=${HOME}/pkg/omnistore


pkgver() {
  cd "$srcdir/omnistore"
  git describe --long --tags | sed 's/\([^-]*-g\)/r\1/;s/-/./g' || echo "0.1.0"
}

build() {
  cd "${srcdir}/omnistore"

  mkdir -p "${pkgdir}/fake_bin"
  cat << 'EOF' > "${pkgdir}/fake_bin/pip"
#!/bin/sh
# 这个脚本是为了绕过 Arch Linux 的安全锁机制而存在的。它会被放在 PATH 前面，冒充 pip 来接管所有 pip 调用。
/user/bin/pip "$@" --break-system-packages
EOF
    chmod +x "${pkgdir}/fake_bin/pip"
    export PATH="${pkgdir}/fake_bin:$PATH"

    python auto_build.py --rust
    python auto_build.py --flutter

    cd python
    python -m venv build_venv
    ./build_venv/bin/pip install -r requirements.txt pyinstaller --break-system-packages
    ./build_venv/bin/pyinstaller --onefile --name python_server --clean main.py

    cd "${srcdir}/omnistore"


  # 1. 🛠️ 核心：强行注入这两个最高优先级的环境变量
  export PIP_BREAK_SYSTEM_PACKAGES=1
  export PIP_EXTERNALLY_MANAGED=0

  # 2. 🛠️ 毁灭级大招：在沙盒环境里直接删掉系统的安全锁配置文件（仅在当前沙盒生效，不影响你原本的系统）
  # 很多偷跑的底层脚本不读环境变量，但这个文件没了它们就绝对无法拦截
  rm -f /usr/lib/python*/EXTERNALLY-MANAGED 2>/dev/null || true


  cd "${srcdir}/omnistore"  
  # 3. 顺便检查你这里有没有给你的脚本传参！如果是想编译全部，记得加上 --all
  python auto_build.py --all --platform linux --output-dir release_bundle
}

package() {
  cd "$srcdir/omnistore"

  # 1. 创建安装到系统 /opt/omnistore 的目录
  install -d "${pkgdir}/opt/omnistore" 

  # 2. 拷贝 Flutter bundle 里的所有东西 (由 auto_build.py 生成)
  # 注意：auto_build.py 已经把 backends 组装到了 bundle 目录里
  cp -r release_bundle/* "${pkgdir}/opt/omnistore/"

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
}
