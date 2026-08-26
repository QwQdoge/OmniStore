import asyncio
import json

import pytest

from core.meo_channel import (
    CommandResult,
    MeoChannelError,
    MeoChannelManager,
    channel_from_repositories,
    local_only_pacman_config,
    official_packages,
    package_relation_names,
    pacman_records,
)


def test_channel_follows_pacman_order_not_a_preference():
    assert channel_from_repositories(["meo-beta", "meo", "extra"]) == "beta"
    assert channel_from_repositories(["meo", "meo-beta"]) == "invalid"
    assert channel_from_repositories(["extra", "meo"]) == "stable"


def test_official_package_set_is_metadata_based_not_prefix_based():
    assert official_packages({"schemaVersion": 2, "officialPackages": ["omnistore-bin", "meoui-qml"]}) == (
        "meoui-qml", "omnistore-bin"
    )
    with pytest.raises(Exception):
        official_packages({"schemaVersion": 2, "officialPackages": ["bad;package"]})


def test_local_rollback_parser_and_config_exclude_sync_repositories():
    assert pacman_records("meo-settings 0.1.1beta1-1\n") == {"meo-settings": "0.1.1beta1-1"}
    with pytest.raises(MeoChannelError):
        pacman_records("meo-settings\n")
    assert package_relation_names("Conflicts With : meo-channel-beta\n", "Conflicts With") == {
        "meo-channel-beta"
    }
    assert package_relation_names(
        "Conflicts With : meo-channel-beta\n                 foreign-package\n",
        "Conflicts With",
    ) == {"meo-channel-beta", "foreign-package"}
    config = local_only_pacman_config()
    assert config.startswith("[options]\n")
    assert "\n[meo]" not in config and "\n[core]" not in config


def test_beta_switch_uses_package_owned_channel_then_normal_upgrade(tmp_path):
    catalog = tmp_path / "catalog.json"
    catalog.write_text(json.dumps({"schemaVersion": 2, "officialPackages": ["omnistore-bin"]}), encoding="utf-8")
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


def test_beta_trial_rejects_stable_before_privilege_or_channel_mutation(tmp_path):
    catalog = tmp_path / "catalog.json"
    catalog.write_text(
        json.dumps(
            {
                "schemaVersion": 2,
                "officialPackages": ["meo-desktop", "meoui-qml"],
                "channelAvailability": {
                    "stable": {"coreTrainAvailable": False, "message": "Stable is not published."},
                    "beta": {"coreTrainAvailable": True, "message": "Beta is available."},
                },
            }
        ),
        encoding="utf-8",
    )
    calls = []

    class Privilege:
        async def ensure_privileged(self):
            raise AssertionError("Stable availability must be checked before sudo")

        async def subprocess_environment(self):
            raise AssertionError("Stable availability must be checked before sudo")

    async def runner(args, env):
        calls.append(args)
        if args == ("pacman-conf", "--repo-list"):
            return CommandResult(0, "core\nmeo-beta\nmeo\n")
        raise AssertionError(f"Unexpected command: {args}")

    result = asyncio.run(
        MeoChannelManager(catalog_path=catalog, privilege_manager=Privilege(), runner=runner).switch_to_stable()
    )
    assert result["status"] == "stable_unavailable"
    assert result["currentChannel"] == "beta"
    assert not any(command[:2] == ("sudo", "-A") for command in calls)
