import asyncio
import json
import sys

import pytest

from core.meo_channel import CommandResult, MeoChannelManager, channel_from_repositories, official_packages


def test_channel_helper_does_not_eagerly_import_unrelated_network_sources():
    assert "core.sources.aur.aur" not in sys.modules
    assert "core.sources.github.github" not in sys.modules


def test_channel_follows_pacman_order_not_a_preference():
    assert channel_from_repositories(["meo-beta", "meo", "extra"]) == "beta"
    assert channel_from_repositories(["meo", "meo-beta"]) == "invalid"
    assert channel_from_repositories(["extra", "meo"]) == "stable"


def test_official_package_set_is_metadata_based_not_prefix_based():
    assert official_packages({"packages": {"omnistore-bin": {}, "meoui-qml": {}}}) == (
        "meoui-qml", "omnistore-bin"
    )
    with pytest.raises(Exception):
        official_packages({"packages": {"bad;package": {}}})


def test_beta_switch_uses_package_owned_channel_then_normal_upgrade(tmp_path):
    catalog = tmp_path / "catalog.json"
    catalog.write_text(json.dumps({"packages": {"omnistore-bin": {}}}), encoding="utf-8")
    calls = []

    class Privilege:
        async def ensure_privileged(self): return True
        async def subprocess_environment(self): return {"SUDO_ASKPASS": "/bin/true"}

    async def runner(args, env):
        calls.append(args)
        if args == ("pacman-conf", "--repo-list"):
            return CommandResult(0, "meo-beta\nmeo\n")
        return CommandResult(0, "")

    result = asyncio.run(MeoChannelManager(catalog_path=catalog, privilege_manager=Privilege(), runner=runner).switch_to_beta())
    assert result["channel"] == "beta"
    assert calls[0][-1] == "meo-channel-beta"
    assert ("sudo", "-A", "pacman", "-Syyu", "--noconfirm") in calls
    assert not any("-Suu" in call for call in calls)
