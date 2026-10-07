from core.platform_profile import SystemProfile, recommended_sources, source_is_relevant


def test_immutable_fedora_does_not_expose_dnf_as_host_source():
    profile = SystemProfile(
        platform="linux",
        distro_id="fedora",
        distro_like=("fedora",),
        native_manager="",
        immutable=True,
    )

    assert recommended_sources(profile) == ["flatpak", "appimage"]
    assert not source_is_relevant("builtin.dnf", profile)
    assert source_is_relevant("builtin.flatpak", profile)
