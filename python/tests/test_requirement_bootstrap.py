import asyncio

from core.env_manager import EnvManager
from core.platform_profile import SystemProfile


def manager(present, platform="linux", native="pacman"):
    env = EnvManager()
    env.profile = SystemProfile(platform=platform, native_manager=native)
    env._has_cmd = lambda cmd: cmd in present
    env.calls = []

    async def run(command, callback=None, timeout=1800, **kw):
        env.calls.append(command)
        return True

    async def flathub(callback=None):
        return True

    async def installed(app_id):
        return False

    env._run_command = run
    env._ensure_flathub = flathub
    env._flatpak_app_installed = installed
    return env


def test_present_tools_are_skipped():
    env = manager({"flatpak", "bottles-cli", "yay"})
    assert asyncio.run(env.ensure("bottles")) is True
    assert asyncio.run(env.ensure("flatpak")) is True
    assert asyncio.run(env.ensure("aur_helper")) is True
    assert env.calls == []


def test_bottles_installs_from_flathub_when_missing(monkeypatch):
    monkeypatch.setattr("platform.machine", lambda: "x86_64")
    env = manager({"flatpak"})
    assert asyncio.run(env.ensure("bottles")) is True
    assert env.calls == [["flatpak", "install", "--user", "-y", "--noninteractive", "flathub", "com.usebottles.bottles"]]


def test_bottles_refused_off_linux_and_unknown_requirement_fails():
    assert asyncio.run(manager(set(), platform="macos", native="brew").ensure("bottles")) is False
    assert asyncio.run(manager(set()).ensure("nonsense")) is False


def test_bottles_refused_on_arm(monkeypatch):
    monkeypatch.setattr("platform.machine", lambda: "aarch64")
    env = manager({"flatpak"})
    assert asyncio.run(env.ensure("bottles")) is False
    assert env.calls == []
