from core.platform_profile import SystemProfile, recommended_sources


def test_clean_linux_source_sets():
    assert recommended_sources(
        SystemProfile(platform="linux", distro_id="arch", native_manager="pacman")
    ) == ["pacman", "flatpak", "appimage", "aur"]

    assert recommended_sources(
        SystemProfile(platform="linux", distro_id="ubuntu", native_manager="apt")
    ) == ["apt", "flatpak", "appimage"]

    assert recommended_sources(
        SystemProfile(platform="linux", distro_id="fedora", native_manager="dnf")
    ) == ["dnf", "flatpak", "appimage"]

    assert recommended_sources(
        SystemProfile(platform="linux", distro_id="opensuse-tumbleweed", native_manager="zypper")
    ) == ["zypper", "flatpak", "appimage"]

    assert recommended_sources(
        SystemProfile(platform="linux", distro_id="alpine", native_manager="apk")
    ) == ["apk", "flatpak", "appimage"]
