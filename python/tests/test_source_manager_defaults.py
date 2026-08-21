from core.platform_profile import SystemProfile, recommended_sources


def test_aur_is_only_recommended_for_pacman_hosts():
    assert "aur" in recommended_sources(
        SystemProfile(platform="linux", distro_id="arch", native_manager="pacman")
    )
    for distro_id, manager in (
        ("ubuntu", "apt"),
        ("fedora", "dnf"),
        ("opensuse-tumbleweed", "zypper"),
        ("alpine", "apk"),
    ):
        assert "aur" not in recommended_sources(
            SystemProfile(
                platform="linux",
                distro_id=distro_id,
                native_manager=manager,
            )
        )
