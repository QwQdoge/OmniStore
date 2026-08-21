import inspect
import asyncio
import json

import pytest
from pydantic import ValidationError
from unittest.mock import AsyncMock

from core import backend as backend_module
from core import cli_handler
from core.cli_handler import CLIArguments
from core.config_loader import ConfigManager
from core.security_validator import SecurityValidator
from core.sources.git_forges.github import GitHubForge
from core.search.custom_repo import CustomRepoManager
from core.sources.utils import PrivilegeManager
from core.update_manager import UpdateManager
from daemon_main import parse_json_output


def test_appimage_custom_repo_requires_url():
    with pytest.raises(ValidationError):
        CLIArguments(add_custom_repo="appimage")


def test_appimage_custom_repo_accepts_url_only_shortcut():
    args = CLIArguments(add_custom_repo="appimage,https://example.com/feed.json")
    assert args.add_custom_repo == "appimage,https://example.com/feed.json"


def test_search_cli_accepts_github_store_query_syntax():
    args = CLIArguments(search="source:github stars:>5000 sort:stars")
    assert args.search == "source:github stars:>5000 sort:stars"


def test_search_validator_rejects_shell_control_syntax():
    for char in [";", "&", "|", "`", "$", "(", ")", "\\", "'", '"']:
        with pytest.raises(ValueError):
            SecurityValidator.validate_search_query(f"source:github{char} rm -rf /")


def test_github_forge_uses_structured_query_params():
    source = inspect.getsource(GitHubForge.search_repositories)

    assert "params = " in source
    assert "params=params" in source
    assert "?q={query}" not in source


def test_daemon_update_check_parses_json_after_log_noise():
    updates = [{"name": "demo", "source": "AUR"}]
    raw = "starting update check\n" + json.dumps(updates)
    assert parse_json_output(raw) == updates


def test_config_load_does_not_mutate_defaults(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    manager = ConfigManager()
    manager.config_path.write_text("ui:\n  language: en\n", encoding="utf-8")

    loaded = manager.load()

    assert loaded["ui"]["language"] == "en"
    assert manager.default_config["ui"]["language"] == "zh-CN"


def test_details_cli_routes_source_to_plugin_details():
    handler_source = inspect.getsource(cli_handler.handle_cli)
    backend_signature = inspect.signature(backend_module.OmnistoreBackend.run_app_details)

    assert "backend.run_app_details(validated_args.details, validated_args.json_mode, validated_args.source)" in handler_source
    assert "source" in backend_signature.parameters


def test_resource_cleanup_does_not_cancel_its_own_task():
    class ClosableHandle:
        closed = False

        def __init__(self):
            self.close_calls = 0

        async def close(self):
            self.close_calls += 1
            self.closed = True

    async def cleanup_current_task():
        coordinator = backend_module.ResourceCoordinator()
        handle = ClosableHandle()
        coordinator.track_task(asyncio.current_task())
        coordinator.track_handle(handle)

        await coordinator.cleanup()
        return handle.close_calls

    assert asyncio.run(cleanup_current_task()) == 1


def test_resource_cleanup_cancels_and_gathers_background_tasks():
    async def cleanup_background_task():
        coordinator = backend_module.ResourceCoordinator()
        started = asyncio.Event()

        async def worker():
            started.set()
            await asyncio.Event().wait()

        task = asyncio.create_task(worker())
        coordinator.track_task(task)
        await started.wait()
        await coordinator.cleanup()
        return task.cancelled(), coordinator._tasks, coordinator._background_tasks

    cancelled, tracked_tasks, background_tasks = asyncio.run(cleanup_background_task())

    assert cancelled is True
    assert tracked_tasks == set()
    assert background_tasks == set()


def test_custom_pacman_repository_addition_is_fail_closed():
    messages = []

    async def reject_custom_repository():
        manager = CustomRepoManager(config_manager=None, executor=None)

        async def callback(message):
            messages.append(message)

        return await manager.add_pacman_repo(
            "unsigned-example",
            "https://packages.example.invalid/$arch",
            callback=callback,
        )

    assert asyncio.run(reject_custom_repository()) is False
    assert any("disabled" in message.lower() for message in messages)


def test_privilege_manager_never_reads_or_pipes_the_sudo_password():
    source = inspect.getsource(PrivilegeManager.ensure_privileged)

    assert '"sudo", "-A"' in source
    assert '"sudo", "-S"' not in source
    assert "password_bytes" not in source
    assert "SUDO_ASKPASS" in source


def test_update_all_uses_real_manager_commands_instead_of_a_fake_package(monkeypatch):
    async def run_update_all():
        manager = UpdateManager(config=ConfigManager())
        manager.privilege.ensure_privileged = AsyncMock(return_value=True)
        manager._run_update_command = AsyncMock(return_value=True)
        monkeypatch.setattr(
            "core.update_manager.shutil.which",
            lambda name: f"/usr/bin/{name}" if name in {"pacman", "flatpak"} else None,
        )

        assert await manager.apply_all_updates() is True
        return [call.args[0] for call in manager._run_update_command.await_args_list]

    commands = asyncio.run(run_update_all())

    assert ["sudo", "pacman", "-Syu", "--noconfirm"] in commands
    assert ["flatpak", "update", "--user", "-y"] in commands
    assert all("all" not in command for command in commands)
