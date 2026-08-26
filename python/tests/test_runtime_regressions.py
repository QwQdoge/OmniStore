import inspect
import asyncio
import ast
import json
from pathlib import Path

import pytest
from pydantic import ValidationError
from unittest.mock import AsyncMock

from core import backend as backend_module
from core import cli_handler
from core.cli_handler import CLIArguments, legacy_ai_requested
from core.config_loader import ConfigManager
from core.security_validator import SecurityValidator
from core.sources.git_forges.github import GitHubForge
from core.search.custom_repo import CustomRepoManager
from core.sources.utils import PrivilegeManager
from core.update_manager import UpdateManager
from core.daemon_server import DaemonRequest
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


def test_daemon_protocol_allows_lightweight_ping():
    request = DaemonRequest(action="ping")
    assert request.action == "ping"


def test_daemon_protocol_rejects_legacy_ai_transport():
    with pytest.raises(ValidationError):
        DaemonRequest(action="run_ai_explain", args=["Example"])


def test_cli_legacy_ai_flags_are_routed_to_consent_ui():
    assert legacy_ai_requested(CLIArguments(ai_explain="Example")) is True
    assert legacy_ai_requested(CLIArguments(search="Example")) is False


def test_search_does_not_call_ai_automatically():
    search_source = (
        Path(__file__).resolve().parents[1] / "core/search/manager.py"
    ).read_text(encoding="utf-8")
    assert "ai.recommend_apps" not in search_source
    assert "one-time\n        # consent flow" in search_source


def test_backend_normalizes_incomplete_package_records():
    backend = backend_module.OmnistoreBackend(json_mode=True, emit_stdout=False)
    packages = backend._to_app_packages([
        {"name": "Example", "description": None},
        {"id": "org.meo.Second", "description": "Ready"},
    ])
    assert [package.id for package in packages] == ["Example", "org.meo.Second"]
    assert packages[0].description == ""
    assert packages[1].name == "org.meo.Second"


def test_daemon_backend_never_emits_cli_json(capsys):
    backend = backend_module.OmnistoreBackend(json_mode=True, emit_stdout=False)
    backend._output_command_response(backend_module.CommandResponse(status="success"))
    assert capsys.readouterr().out == ""


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


def test_official_meo_repository_removal_is_fail_closed():
    manager = CustomRepoManager(config_manager=None, executor=None)

    async def reject_removal():
        messages = []
        async def callback(message):
            messages.append(message)
        ok = await manager.remove_pacman_repo("meo-beta", callback=callback)
        return ok, messages

    ok, messages = asyncio.run(reject_removal())
    assert ok is False
    assert "managed by the update channel package" in messages[0]
    assert any("disabled" in message.lower() for message in messages)


def test_privilege_manager_never_reads_or_pipes_the_sudo_password():
    source = inspect.getsource(PrivilegeManager)

    assert '"sudo", "-A"' in source
    assert '"sudo", "-S"' not in source
    assert "password_bytes" not in source
    assert "SUDO_ASKPASS" in source


def test_update_all_uses_real_manager_commands_instead_of_a_fake_package(monkeypatch):
    async def run_update_all():
        manager = UpdateManager(config=ConfigManager())
        manager.privilege.ensure_privileged = AsyncMock(return_value=True)
        manager.privilege.subprocess_environment = AsyncMock(
            return_value={"SUDO_ASKPASS": "/usr/bin/ksshaskpass"}
        )
        manager._run_update_command = AsyncMock(return_value=True)
        monkeypatch.setattr(
            "core.update_manager.shutil.which",
            lambda name: f"/usr/bin/{name}" if name in {"pacman", "flatpak"} else None,
        )

        assert await manager.apply_all_updates() is True
        return manager, [
            call.args[0]
            for call in manager._run_update_command.await_args_list
        ]

    manager, commands = asyncio.run(run_update_all())

    assert ["sudo", "-A", "pacman", "-Syu", "--noconfirm"] in commands
    assert ["flatpak", "update", "--user", "-y"] in commands
    assert all("all" not in command for command in commands)
    manager.privilege.ensure_privileged.assert_not_awaited()


def test_flutter_progress_callback_is_structured_without_protocol_text(capsys):
    backend = backend_module.OmnistoreBackend(json_mode=True)

    asyncio.run(backend._flutter_callback("[PROGRESS] 67", json_mode=True))

    line = capsys.readouterr().out.strip()
    assert line.startswith("[CALLBACK] ")
    payload = json.loads(line.removeprefix("[CALLBACK] "))
    assert payload == {"type": "progress", "progress": 67.0}
    assert "[PROGRESS]" not in line


def test_update_all_passes_graphical_askpass_to_aur_helper(monkeypatch):
    async def run_update_all():
        manager = UpdateManager(
            config={"updates.include_aur_in_update_all": True}
        )
        manager.privilege.ensure_privileged = AsyncMock(return_value=True)
        manager.privilege.subprocess_environment = AsyncMock(
            return_value={"SUDO_ASKPASS": "/usr/bin/ksshaskpass"}
        )
        manager._run_update_command = AsyncMock(return_value=True)
        monkeypatch.setattr(
            "core.update_manager.shutil.which",
            lambda name: f"/usr/bin/{name}" if name in {"pacman", "yay"} else None,
        )

        assert await manager.apply_all_updates() is True
        return manager._run_update_command.await_args_list

    calls = asyncio.run(run_update_all())
    aur_call = next(call for call in calls if call.args[0][0] == "yay")
    assert aur_call.args[0][:3] == ["yay", "--sudoflags", "-A"]
    assert "-Sua" in aur_call.args[0]
    assert "-Syu" not in aur_call.args[0]
    assert aur_call.kwargs["env"]["SUDO_ASKPASS"] == "/usr/bin/ksshaskpass"


def test_all_project_python_sources_parse():
    project_python = Path(__file__).resolve().parents[1]
    failures = []
    for source in project_python.rglob("*.py"):
        if ".venv" in source.parts or "__pycache__" in source.parts:
            continue
        try:
            ast.parse(source.read_text(encoding="utf-8"), filename=str(source))
        except SyntaxError as error:
            failures.append(f"{source.relative_to(project_python)}:{error.lineno}: {error.msg}")
    assert failures == []
