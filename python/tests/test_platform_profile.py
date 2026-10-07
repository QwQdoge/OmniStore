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


def test_fdroid_device_source_remains_available_across_desktop_hosts():
    for platform in ("linux", "windows", "macos"):
        assert source_is_relevant("builtin.fdroid", SystemProfile(platform=platform))


def test_arch_text_in_other_release_fields_does_not_make_an_arch_host(monkeypatch):
    import core.platform_profile as profiles
    monkeypatch.setattr(profiles.sys, "platform", "linux")
    monkeypatch.setattr(profiles, "_read_os_release", lambda: {
        "ID": "ubuntu", "ID_LIKE": "debian", "NAME": "Arch migration workstation"})
    monkeypatch.setattr(profiles.shutil, "which", lambda command: "/usr/bin/" + command)
    monkeypatch.setattr(profiles.Path, "exists", lambda path: False)
    profile = profiles.detect_system_profile()
    assert profile.native_manager == "apt"
    assert not profile.immutable  # rpm-ostree may be installed on mutable hosts.


def test_builtin_manifest_policy_does_not_hide_third_party_plugins(monkeypatch):
    import core.sources.plugin_registry as registry
    from unittest.mock import MagicMock
    monkeypatch.setattr(registry, "_platform_key", lambda: "linux")
    plugins = registry.PluginRegistry(MagicMock())
    plugins.profile = SystemProfile(platform="linux", native_manager="apt")
    assert not plugins._is_platform_available(registry.PluginInfo(
        id="builtin.pacman", kind="source", name="Pacman", builtin=True))
    assert plugins._is_platform_available(registry.PluginInfo(
        id="builtin.apt", kind="source", name="APT", builtin=True))
    assert plugins._is_platform_available(registry.PluginInfo(
        id="thirdparty.custom", kind="source", name="Custom", platforms=["linux"]))
