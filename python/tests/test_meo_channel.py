import asyncio
import inspect
import json

import pytest

from core.meo_channel import CommandResult, MeoChannelManager, channel_from_repositories, official_packages


def test_channel_follows_pacman_order_not_a_preference():
    assert channel_from_repositories(["meo-beta", "meo", "extra"]) == "beta"
    assert channel_from_repositories(["meo", "meo-beta"]) == "invalid"
    assert channel_from_repositories(["extra", "meo"]) == "stable"


def test_channel_import_does_not_eagerly_load_network_source_plugins():
    import core.sources

    source = inspect.getsource(core.sources)
    assert "from .aur.aur import" not in source
    assert "from .github.github import" not in source


def test_official_package_set_is_metadata_based_not_prefix_based():
    assert official_packages({"packages": {"omnistore-bin": {}, "meoui-qml": {}}}) == (
        "meoui-qml", "omnistore-bin"
    )
    with pytest.raises(Exception):
        official_packages({"packages": {"bad;package": {}}})
    assert official_packages({"officialPackages": ["omnistore-bin", "meoui-qml"]}) == (
        "meoui-qml", "omnistore-bin"
    )


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


def test_stable_switch_reuses_the_reviewed_helper_plan_hash(tmp_path):
    catalog = tmp_path / "catalog.json"
    catalog.write_text(json.dumps({"officialPackages": ["meoui-qml"]}), encoding="utf-8")
    requests = []

    class Privilege:
        async def ensure_privileged(self): return True
        async def subprocess_environment(self): return {"SUDO_ASKPASS": "/bin/true"}

    async def runner(args, env):
        if args == ("pacman-conf", "--repo-list"):
            return CommandResult(0, "meo\n")
        return CommandResult(0, "")

    async def rollback_runner(request, env):
        requests.append(request)
        if request["operation"] == "preview":
            return CommandResult(0, json.dumps({
                "status": "success", "channel": "stable", "downgrades": [
                    {"name": "meoui-qml", "installed": "2-1", "stable": "1-1", "sha256": "a" * 64}
                ], "planHash": "b" * 64,
            }))
        assert request == {"version": 1, "operation": "commit", "planHash": "b" * 64}
        return CommandResult(0, json.dumps({"status": "success", "channel": "stable", "downgrades": [], "committed": True}))

    result = asyncio.run(MeoChannelManager(
        catalog_path=catalog,
        privilege_manager=Privilege(),
        runner=runner,
        rollback_runner=rollback_runner,
    ).switch_to_stable(confirm_downgrades=True, confirmed_plan_hash="b" * 64))
    assert result["committed"] is True
    assert [request["operation"] for request in requests] == ["preview", "commit"]
