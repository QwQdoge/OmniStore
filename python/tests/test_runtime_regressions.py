import inspect
import asyncio
import json

import pytest
from pydantic import ValidationError

from core import backend as backend_module
from core import cli_handler
from core.cli_handler import CLIArguments
from core.config_loader import ConfigManager
from core.security_validator import SecurityValidator
from core.sources.git_forges.github import GitHubForge
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
