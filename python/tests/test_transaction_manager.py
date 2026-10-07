import asyncio

import pytest

from core.transaction_manager import TransactionManager
from core.daemon_server import DaemonRequest


class FakeRegistry:
    def list_plugins(self):
        return [
            {
                "id": "builtin.pacman",
                "name": "Pacman",
                "enabled": True,
                "available": True,
                "trusted": True,
                "requires_review": False,
                "capabilities": ["search", "install", "uninstall", "update", "details", "size"],
                "permissions": ["subprocess", "filesystem", "system_package_manager"],
            }
        ]


class FakeManager:
    def __init__(self):
        self.plugin_registry = FakeRegistry()


class FakeBackend:
    def __init__(self):
        self.calls = []
        self.manager = FakeManager()

    async def initialize(self):
        return self

    async def run_app_details(self, name, json_mode=False, source=None):
        return {
            "id": name,
            "name": "Demo App",
            "version": "2.0",
            "primary_source": "Native",
            "variants": [
                {
                    "id": name,
                    "name": name,
                    "source": "Native",
                    "version": "2.0",
                    "download_size": "12 MiB",
                    "installed_size": "40 MiB",
                    "depends": ["demo-lib>=1"],
                }
            ],
        }

    async def run_install(self, name, source, url=None, json_mode=False):
        self.calls.append(("install", name, source, url, json_mode))
        await asyncio.sleep(0)
        return {"status": "success", "response": True}

    async def run_uninstall(self, name, source, json_mode=False):
        self.calls.append(("remove", name, source, json_mode))
        await asyncio.sleep(0)
        return {"status": "success", "response": True}

    async def run_update(self, name, source, json_mode=False):
        self.calls.append(("update", name, source, json_mode))
        await asyncio.sleep(0)
        return {"status": "success", "response": True}


async def wait_finished(manager, task_id):
    for _ in range(50):
        snapshot = manager.get(task_id)
        if snapshot["status"] in {"succeeded", "failed", "cancelled"}:
            return snapshot
        await asyncio.sleep(0.01)
    raise AssertionError("transaction did not finish")


@pytest.mark.asyncio
async def test_install_plan_binds_reviewed_metadata_to_one_shot_apply():
    backend = FakeBackend()
    manager = TransactionManager(backend)

    plan = await manager.plan_install(name="demo", source="Native")
    assert plan["schema"] == "org.meo.omnistore.transaction-plan"
    assert plan["version"] == 1
    assert plan["canApply"] is True
    assert plan["source"]["trust"] == "trusted"
    assert plan["requiresPrivilege"] is True
    assert plan["package"]["downloadSize"] == "12 MiB"
    assert plan["package"]["installedSize"] == "40 MiB"
    assert plan["package"]["dependencies"] == ["demo-lib>=1"]
    assert plan["planHash"]

    submitted = manager.submit_planned(plan["planHash"])
    assert submitted["status"] == "queued"
    assert submitted["planHash"] == plan["planHash"]

    finished = await wait_finished(manager, submitted["taskId"])
    assert finished["status"] == "succeeded"
    assert finished["progress"] == 1.0
    assert backend.calls == [("install", "demo", "Native", None, True)]

    with pytest.raises(ValueError, match="plan_not_found_or_expired"):
        manager.submit_planned(plan["planHash"])


@pytest.mark.asyncio
async def test_submit_returns_task_before_non_install_mutation_completes_and_can_reconnect():
    backend = FakeBackend()
    manager = TransactionManager(backend)

    submitted = manager.submit(kind="remove", name="demo", source="Native")
    assert submitted["status"] == "queued"
    assert submitted["taskId"]

    finished = await wait_finished(manager, submitted["taskId"])
    assert finished["status"] == "succeeded"
    assert manager.get(submitted["taskId"])["taskId"] == submitted["taskId"]
    assert manager.list()[0]["taskId"] == submitted["taskId"]
    assert backend.calls == [("remove", "demo", "Native", True)]


@pytest.mark.asyncio
async def test_update_all_is_normalized_to_single_authority_operation():
    backend = FakeBackend()
    manager = TransactionManager(backend)

    submitted = manager.submit(kind="update_all")
    finished = await wait_finished(manager, submitted["taskId"])

    assert finished["status"] == "succeeded"
    assert backend.calls == [("update", "all", "all", True)]


def test_daemon_protocol_allows_only_named_transaction_actions():
    for action in ("transaction.plan", "task.submit", "task.get", "task.list"):
        assert DaemonRequest(action=action)

    for forbidden in ("task.exec", "run_install", "run_uninstall", "run_update"):
        with pytest.raises(Exception):
            DaemonRequest(action=forbidden)


def test_transaction_manager_rejects_unknown_kinds():
    manager = TransactionManager(FakeBackend())
    with pytest.raises(ValueError, match="unsupported_transaction_kind"):
        manager.submit(kind="shell", name="pacman")
