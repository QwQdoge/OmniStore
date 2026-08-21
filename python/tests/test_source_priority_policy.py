from core.platform_profile import SystemProfile, recommended_sources


def test_native_source_is_first_when_available():
    for distro_id, manager in (
        ("arch", "pacman"),
        ("ubuntu", "apt"),
        ("fedora", "dnf"),
        ("opensuse-tumbleweed", "zypper"),
        ("alpine", "apk"),
    ):
        sources = recommended_sources(
            SystemProfile(
                platform="linux",
                distro_id=distro_id,
                native_manager=manager,
            )
        )
        assert sources[0] == manager
        assert "flatpak" in sources
        assert "appimage" in sources
