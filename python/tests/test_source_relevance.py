from core.platform_profile import SystemProfile, source_is_relevant


def test_linux_native_managers_are_mutually_exclusive():
    arch = SystemProfile(platform="linux", distro_id="arch", native_manager="pacman")
    ubuntu = SystemProfile(platform="linux", distro_id="ubuntu", native_manager="apt")
    fedora = SystemProfile(platform="linux", distro_id="fedora", native_manager="dnf")

    assert source_is_relevant("builtin.pacman", arch)
    assert not source_is_relevant("builtin.apt", arch)
    assert not source_is_relevant("builtin.dnf", arch)

    assert source_is_relevant("builtin.apt", ubuntu)
    assert not source_is_relevant("builtin.pacman", ubuntu)
    assert not source_is_relevant("builtin.dnf", ubuntu)

    assert source_is_relevant("builtin.dnf", fedora)
    assert not source_is_relevant("builtin.pacman", fedora)
    assert not source_is_relevant("builtin.apt", fedora)


def test_cross_distro_linux_sources_remain_relevant():
    ubuntu = SystemProfile(platform="linux", distro_id="ubuntu", native_manager="apt")
    assert source_is_relevant("builtin.flatpak", ubuntu)
    assert source_is_relevant("builtin.appimage", ubuntu)
