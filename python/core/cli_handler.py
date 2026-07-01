import sys
import json
import asyncio
import inspect
import logging
import shutil
import os
import re
from typing import Optional
from pydantic import BaseModel, Field, field_validator, ValidationError
from core.backend import OmnistoreBackend, hijacked_print, safe_subprocess

class CLIArguments(BaseModel):
    search: Optional[str] = Field(None, max_length=500)
    install: Optional[str] = Field(None, max_length=500)
    remove: Optional[str] = Field(None, max_length=500)
    update: Optional[str] = Field(None, max_length=500)
    check_updates: bool = False
    list_installed: bool = False
    recommend: bool = False
    details: Optional[str] = None
    clean_system: bool = False
    ai_summary: bool = False
    get_config: bool = False
    set_config: Optional[str] = None
    check_env: bool = False
    bootstrap: bool = False
    list_custom_repos: bool = False
    add_custom_repo: Optional[str] = None
    remove_custom_repo: Optional[str] = None
    ai_explain: Optional[str] = None
    ai_recommend: Optional[str] = None
    ai_analyze_error: Optional[str] = None
    ai_compare: Optional[str] = None
    ai_health: bool = False
    ai_test: bool = False
    ai_pick: bool = False
    ai_correct: Optional[str] = None
    ai_changelog: Optional[str] = None
    ai_cli: Optional[str] = None
    ai_conflicts: Optional[str] = None
    essentials: bool = False
    import_packages: Optional[str] = None
    export_packages: Optional[str] = None
    launch: Optional[str] = None
    locate: Optional[str] = None
    daemon: bool = False
    storage_info: bool = False
    json_mode: bool = Field(default=False, alias="json")
    source: str = "AUR"
    url: Optional[str] = None
    ai_desc: Optional[str] = None
    force_refresh: bool = False

    @field_validator(
        "search", "install", "remove", "update", "details",
        "ai_explain", "ai_recommend", "ai_analyze_error", "ai_compare",
        "ai_correct", "ai_conflicts", "launch", "locate"
    )
    @classmethod
    def validate_safe_input(cls, v: Optional[str]) -> Optional[str]:
        """Murphy-proof: Strict alphanumeric/symbol check to prevent shell injection."""
        if v is not None:
            v_stripped = v.strip()
            if not v_stripped: raise ValueError("Argument cannot be empty.")
            # Boundary Defense: Forbid shell metacharacters: ; & | ` $ ( ) < > \ ' "
            # Allow: letters, numbers, dots, dashes, underscores, slashes, pluses, at-signs, and spaces.
            if not re.match(r'^[a-zA-Z0-9._/ +\-@]+$', v_stripped):
                raise ValueError("Security violation: Argument contains forbidden shell metacharacters.")
            return v_stripped
        return v

    @field_validator("import_packages", "export_packages")
    @classmethod
    def validate_safe_path(cls, v: Optional[str]) -> Optional[str]:
        """Murphy-proof: Path validation to prevent traversal attacks."""
        if v is not None:
            v_stripped = v.strip()
            if not v_stripped: raise ValueError("Path cannot be empty.")
            if ".." in v_stripped: raise ValueError("Security violation: Path traversal ('..') is forbidden.")
            if not re.match(r'^[a-zA-Z0-9._/\\: -]+$', v_stripped):
                raise ValueError("Security violation: Path contains illegal characters.")
            return v_stripped
        return v

    @field_validator("add_custom_repo")
    @classmethod
    def validate_add_custom_repo(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v_stripped = v.strip()
            if not re.match(r'^[a-zA-Z0-9._/ +\-@,:]+$', v_stripped):
                raise ValueError("Security violation: Repo string contains forbidden characters.")
            parts = [p.strip() for p in v_stripped.split(',', 2)]
            if len(parts) < 3 and parts[0] == "appimage" and len(parts) >= 2:
                parts = ["appimage", "", parts[1]]
            if len(parts) < 3: raise ValueError("Invalid format: type,name,url")
        return v

    @field_validator("remove_custom_repo")
    @classmethod
    def validate_remove_custom_repo(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v_stripped = v.strip()
            if not re.match(r'^[a-zA-Z0-9._/ +\-@,:]+$', v_stripped):
                raise ValueError("Security violation: Repo string contains forbidden characters.")
            parts = [p.strip() for p in v_stripped.split(',', 1)]
            if len(parts) < 2: raise ValueError("Invalid format: type,name")
        return v

    @field_validator("ai_changelog")
    @classmethod
    def validate_ai_changelog(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v_stripped = v.strip()
            if not re.match(r'^[a-zA-Z0-9._/ +\-@,:]+$', v_stripped):
                raise ValueError("Security violation: Argument contains forbidden characters.")
            parts = v_stripped.split(',')
            if len(parts) < 3: raise ValueError("Changelog format: name,current,next")
        return v

    @field_validator("ai_cli")
    @classmethod
    def validate_ai_cli(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            v_stripped = v.strip()
            if not re.match(r'^[a-zA-Z0-9._/ +\-@,:]+$', v_stripped):
                raise ValueError("Security violation: Argument contains forbidden characters.")
            parts = v_stripped.split(',')
            if len(parts) < 2: raise ValueError("AI CLI format: name,summary")
        return v

async def handle_cli(backend: OmnistoreBackend, args):
    """Murphy-proof Registry-based Command Dispatcher."""
    try:
        validated_args = CLIArguments(**vars(args))
    except ValidationError as ve:
        errors = [f"Argument '{e['loc'][0]}' invalid: {e['msg']}" for e in ve.errors()]
        await backend._handle_error("Validation Failure", ValueError("; ".join(errors)), args.json)
        sys.exit(1)

    async def _save_config_handler():
        data = sys.stdin.read().strip() or validated_args.set_config
        success = await backend.run_save_config(json.loads(data))
        sys.stdout.write(json.dumps({"status": "success" if success else "error"}) + "\n")

    async def _handle_check_env():
        env_res = await backend.env.check_env()
        sys.stdout.write(json.dumps(env_res, ensure_ascii=False) + "\n")

    async def _handle_bootstrap():
        await backend.env.bootstrap(callback=lambda m: backend._flutter_callback(m, validated_args.json_mode))
        if validated_args.json_mode: sys.stdout.write(json.dumps({"status": "success"}) + "\n")

    async def _handle_ai_changelog(p):
        parts = p.split(',')
        res = await backend.ai.summarize_changelog(parts[0], parts[1], parts[2])
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")

    async def _handle_ai_cli(p):
        parts = p.split(',')
        res = await backend.ai.generate_cli_command(parts[0], parts[1])
        sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")

    async def _handle_ai_conflicts(p):
        if shutil.which("pacman"):
            try:
                async with safe_subprocess("pacman", "-Qq", stdout=asyncio.subprocess.PIPE) as proc:
                    stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=5)
                    res = await backend.ai.detect_conflicts(p, stdout.decode().splitlines())
                    sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")
            except: sys.stdout.write(json.dumps({"response": "Conflict check failed."}) + "\n")
        else: sys.stdout.write(json.dumps({"response": "pacman not found, conflict check skipped."}) + "\n")

    async def _handle_ai_compare(p):
        async with backend:
            if backend.manager:
                candidates = await backend.manager.search_all(p)
                target = next((c for c in candidates if c['name'].lower() == p.lower()), candidates[0] if candidates else None)
                if target:
                    res = await backend.ai.compare_variants(p, target.get('variants', []))
                    sys.stdout.write(json.dumps({"response": res}, ensure_ascii=False) + "\n")
                else: sys.stdout.write(json.dumps({"response": "App not found for comparison."}) + "\n")

    async def _handle_add_custom_repo(raw_repo):
        parts = [p.strip() for p in raw_repo.split(',', 2)]
        if len(parts) < 3 and parts[0] == "appimage" and len(parts) >= 2:
            parts = ["appimage", "", parts[1]]
        async with backend: await backend.run_add_custom_repo(parts[0], parts[1], parts[2], validated_args.json_mode)

    async def _handle_remove_custom_repo(raw_repo):
        parts = [p.strip() for p in raw_repo.split(',', 1)]
        async with backend: await backend.run_remove_custom_repo(parts[0], parts[1], validated_args.json_mode)

    REGISTRY = {
        "get_config": lambda: sys.stdout.write(json.dumps(backend.config.data, ensure_ascii=False) + "\n"),
        "set_config": _save_config_handler,
        "search": lambda: backend.run_search(validated_args.search, validated_args.json_mode),
        "install": lambda: backend.run_install(validated_args.install, validated_args.source, validated_args.url, validated_args.json_mode),
        "remove": lambda: backend.run_uninstall(validated_args.remove, validated_args.source, validated_args.json_mode, validated_args.remove),
        "update": lambda: backend.run_update(validated_args.update, validated_args.source, validated_args.json_mode),
        "check_updates": lambda: backend.run_check_updates(validated_args.json_mode),
        "list_installed": lambda: backend.run_list_installed(validated_args.json_mode, validated_args.force_refresh),
        "details": lambda: backend.run_app_details(validated_args.details, validated_args.json_mode),
        "recommend": lambda: backend.run_recommendations(validated_args.json_mode),
        "clean_system": lambda: backend.run_clean_system(validated_args.json_mode),
        "ai_summary": lambda: backend.run_ai_summary(validated_args.json_mode),
        "check_env": _handle_check_env,
        "bootstrap": _handle_bootstrap,
        "list_custom_repos": lambda: backend.run_list_custom_repos(),
        "ai_explain": lambda: backend.run_ai_explain(validated_args.ai_explain, validated_args.ai_desc or ""),
        "ai_recommend": lambda: backend.run_ai_recommend(validated_args.ai_recommend),
        "ai_analyze_error": lambda: backend.run_ai_analyze_error(validated_args.ai_analyze_error),
        "ai_health": backend.run_ai_health,
        "ai_test": lambda: backend.run_ai_test(validated_args.json_mode),
        "ai_pick": lambda: backend.run_ai_pick(validated_args.json_mode),
        "ai_correct": lambda: backend.run_ai_correct(validated_args.ai_correct),
        "ai_changelog": lambda: _handle_ai_changelog(validated_args.ai_changelog),
        "ai_cli": lambda: _handle_ai_cli(validated_args.ai_cli),
        "ai_conflicts": lambda: _handle_ai_conflicts(validated_args.ai_conflicts),
        "ai_compare": lambda: _handle_ai_compare(validated_args.ai_compare),
        "add_custom_repo": lambda: _handle_add_custom_repo(validated_args.add_custom_repo),
        "remove_custom_repo": lambda: _handle_remove_custom_repo(validated_args.remove_custom_repo),
        "essentials": lambda: backend.run_get_essentials(),
        "import_packages": lambda: backend.run_import_packages(validated_args.import_packages),
        "export_packages": lambda: backend.run_export_packages(validated_args.export_packages),
        "launch": lambda: backend.run_launch(validated_args.launch, validated_args.source, validated_args.json_mode),
        "locate": lambda: backend.run_locate(validated_args.locate, validated_args.source, validated_args.json_mode),
        "storage_info": lambda: backend.run_get_storage_info(validated_args.json_mode),
    }

    for flag, handler in REGISTRY.items():
        if getattr(validated_args, flag, None):
            res = handler()
            if inspect.isawaitable(res): await res
            return True
    return False
