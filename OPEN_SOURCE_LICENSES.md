# 开源项目与参考仓库声明 (Open Source Attribution & Licenses)

OmniStore 的后端更新、下载管理、锁检查和多包源处理逻辑借鉴并吸收了以下知名开源项目的良好架构设计与技术实现：

## 1. Shelly-ALPM
- **仓库地址**: [https://github.com/Seafoam-Labs/Shelly-ALPM](https://github.com/Seafoam-Labs/Shelly-ALPM)
- **主要用途/借鉴内容**: 
  - 多包源（Pacman / AUR / Flatpak / AppImage / GitHub Releases）统一更新查询与下载任务调度架构。
  - 流式进度与下载状态回调机制设计。
- **开源许可证**: GNU General Public License v3.0 (GPL-3.0)

## 2. CachyOS Package Tools (cachy-update & cachyos-package-manager)
- **仓库地址**: [https://github.com/CachyOS](https://github.com/CachyOS)
- **主要用途/借鉴内容**:
  - `/var/lib/pacman/db.lck` 数据库锁主动检测与死锁拦截逻辑。
  - 软件包更新时的版本比较（`current_version` -> `new_version`）与包管理器状态提示。
- **开源许可证**: GNU General Public License v3.0 (GPL-3.0)

## 3. archlinux/pacman-contrib
- **仓库地址**: [https://gitlab.archlinux.org/pacman/pacman-contrib](https://gitlab.archlinux.org/pacman/pacman-contrib)
- **主要用途/借鉴内容**:
  - `checkupdates` 非破坏性数据库同步更新检测模式，避免破坏本地 root 数据库。
- **开源许可证**: GNU General Public License v2.0 (GPL-2.0)

## 4. Bauh (Linux Application Manager)
- **仓库地址**: [https://github.com/vinifig/bauh](https://github.com/vinifig/bauh)
- **主要用途/借鉴内容**:
  - AppImage、Flatpak、AUR 统一抽象接口与轻量化下载执行器（InstallExecutor）设计。
- **开源许可证**: GNU General Public License v3.0 (GPL-3.0)

---

> OmniStore 尊重并感谢所有开源贡献者的努力！
