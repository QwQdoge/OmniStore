from core.sources.linux_native import (
    PrivilegedApkSource,
    PrivilegedAptSource,
    PrivilegedDnfSource,
    PrivilegedZypperSource,
)


def test_native_install_commands_are_manager_specific():
    assert PrivilegedAptSource()._install_command("curl") == [
        "apt-get",
        "install",
        "-y",
        "curl",
    ]
    assert PrivilegedDnfSource()._install_command("curl") == [
        "dnf",
        "install",
        "-y",
        "curl",
    ]
    assert PrivilegedZypperSource()._install_command("curl") == [
        "zypper",
        "--non-interactive",
        "install",
        "curl",
    ]
    assert PrivilegedApkSource()._install_command("curl") == [
        "apk",
        "add",
        "curl",
    ]


def test_native_uninstall_commands_are_manager_specific():
    assert PrivilegedAptSource()._uninstall_command("curl") == [
        "apt-get",
        "remove",
        "-y",
        "curl",
    ]
    assert PrivilegedDnfSource()._uninstall_command("curl") == [
        "dnf",
        "remove",
        "-y",
        "curl",
    ]
    assert PrivilegedZypperSource()._uninstall_command("curl") == [
        "zypper",
        "--non-interactive",
        "remove",
        "curl",
    ]
    assert PrivilegedApkSource()._uninstall_command("curl") == [
        "apk",
        "del",
        "curl",
    ]
