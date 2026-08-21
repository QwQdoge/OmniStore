from core.platform_profile import (
    SystemProfile,
    _manager_from_linux_release,
    recommended_sources,
    source_is_relevant,
)


def test_arch_family_maps_to_pacman():
    assert _manager_from_linux_release("cachyos", ("arch",)) == "pacman"
    assert _manager_from_linux_release("manjaro", ("arch",)) == "pacman"


def test_debian_family_maps_to_apt():
    assert _manager_from_linux_release("ubuntu", ("debian",)) == "apt"
    assert _manager_from_linux_release("pop", ("ubuntu", "debian")) == "apt"


def test_fedora_family_maps_to_dnf():
    assert _manager_from_linux_release("fedora", ()) == "dnf"
    assert _manager_from_linux_release("nobara", ("fedora",)) == "dnf"
    assert _manager_from_linux_release("rocky", ("rhel", "fedora")) == "dnf"


def test_opensuse_and_alpine_mapping():
    assert _manager_from_linux_release("opensuse-tumbleweed", ("suse",)) == "zypper"
    assert _manager_from_linux_release("alpine", ()) == "apk"


def test_arch_recommendations_include_native_flatpak_appimage_and_aur():
    profile = SystemProfile(
        platform="linux",
        distro_id="arch",
        native_manager="pacman",
    )
    assert recommended_sources(profile) == ["pacman", "flatpak", "appimage", "aur"]


def test_fedora_recommendations_do_not_include_apt_or_aur():
    profile = SystemProfile(
        platform="linux",
        distro_id="fedora",
        native_manager="dnf",
    )
    assert recommended_sources(profile) == ["dnf", "flatpak", "appimage"]
    assert source_is_relevant("builtin.dnf", profile)
    assert not source_is_relevant("builtin.apt", profile)
    assert not source_is_relevant("builtin.aur", profile)


def test_immutable_fedora_prefers_cross_distro_app_sources():
    profile = SystemProfile(
        platform="linux",
        distro_id="fedora",
        native_manager="",
        immutable=True,
    )
    assert recommended_sources(profile) == ["flatpak", "appimage"]
    assert source_is_relevant("builtin.flatpak", profile)
    assert not source_is_relevant("builtin.dnf", profile)


def test_windows_and_macos_sources_are_isolated():
    windows = SystemProfile(platform="windows", native_manager="winget")
    macos = SystemProfile(platform="macos", native_manager="brew")

    assert source_is_relevant("builtin.winget", windows)
    assert not source_is_relevant("builtin.pacman", windows)
    assert source_is_relevant("builtin.brew", macos)
    assert not source_is_relevant("builtin.apt", macos)
