#!/usr/bin/env python3
"""Narrow root helper for OmniStore-managed Pacman repository fragments.

It never downloads or imports keys, never weakens package-signature policy,
never runs pacman -Sy, and never removes repository blocks owned by another
tool.  The caller supplies the complete desired managed set on stdin.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit


PACMAN_CONF = Path("/etc/pacman.conf")
MANAGED_FRAGMENT = Path("/etc/pacman.d/omnistore-repositories.conf")
INCLUDE_LINE = "Include = /etc/pacman.d/omnistore-repositories.conf"
MARKER = "# Managed by OmniStore; edit through OmniStore or meo-update."
NAME = re.compile(r"^[A-Za-z0-9@._+:-]{1,128}$")
RESERVED = {
    "options", "core", "extra", "multilib",
    "meo", "meo-beta",
    "cachyos", "cachyos-v3", "cachyos-v4",
    "cachyos-core-v3", "cachyos-extra-v3",
    "cachyos-core-v4", "cachyos-extra-v4",
}


def _active_repositories() -> set[str]:
    result = subprocess.run(
        ["pacman-conf", "--repo-list"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        timeout=15,
    )
    if result.returncode != 0:
        raise ValueError("pacman-conf could not resolve the active configuration")
    return {line.strip().casefold() for line in result.stdout.splitlines() if line.strip()}


def _managed_names() -> set[str]:
    if not MANAGED_FRAGMENT.exists():
        return set()
    return {
        match.group(1).casefold()
        for match in re.finditer(r"^\s*\[([^\]\s]+)\]", MANAGED_FRAGMENT.read_text(encoding="utf-8"), re.MULTILINE)
    }


def _validate_server(raw: object) -> str:
    value = str(raw).strip()
    if not value or len(value) > 2048 or any(ch in value for ch in "\r\n\0"):
        raise ValueError("repository server is invalid")
    parsed = urlsplit(value.replace("$repo", "repo").replace("$arch", "x86_64"))
    if parsed.scheme != "https" or not parsed.netloc:
        raise ValueError("custom Pacman repositories require an HTTPS server")
    return value


def validate(payload: object) -> list[dict[str, str]]:
    if not isinstance(payload, dict) or payload.get("schema") != "org.meo.pacman-repositories":
        raise ValueError("unsupported repository request")
    if payload.get("version") != 1 or not isinstance(payload.get("repositories"), list):
        raise ValueError("unsupported repository request")
    repositories: list[dict[str, str]] = []
    names: set[str] = set()
    active_unmanaged = _active_repositories() - _managed_names()
    for item in payload["repositories"]:
        if not isinstance(item, dict):
            raise ValueError("repository entry is invalid")
        name = str(item.get("name", "")).strip()
        folded = name.casefold()
        if not NAME.fullmatch(name) or folded in RESERVED or folded in names:
            raise ValueError(f"repository name is reserved or invalid: {name}")
        if folded in active_unmanaged:
            raise ValueError(f"repository is already owned outside OmniStore: {name}")
        names.add(folded)
        repositories.append({"name": name, "url": _validate_server(item.get("url"))})
    return repositories


def _atomic_write(path: Path, content: str, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    os.chmod(temporary, mode)
    temporary.replace(path)


def _atomic_write_bytes(path: Path, content: bytes, mode: int = 0o644) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(content)
    os.chmod(temporary, mode)
    temporary.replace(path)


def apply(repositories: list[dict[str, str]]) -> None:
    configuration = [MARKER]
    for item in repositories:
        configuration.extend([
            "",
            f"[{item['name']}]",
            "SigLevel = Required DatabaseOptional",
            f"Server = {item['url']}",
        ])
    configuration.append("")
    _atomic_write(MANAGED_FRAGMENT, "\n".join(configuration))

    pacman_bytes = PACMAN_CONF.read_bytes()
    pacman_configuration = pacman_bytes.decode("utf-8", errors="surrogateescape")
    if INCLUDE_LINE not in {
        line.strip() for line in pacman_configuration.splitlines() if not line.lstrip().startswith("#")
    }:
        suffix = b"" if pacman_bytes.endswith(b"\n") else b"\n"
        addition = f"\n{MARKER}\n{INCLUDE_LINE}\n".encode("utf-8")
        _atomic_write_bytes(PACMAN_CONF, pacman_bytes + suffix + addition)


def main() -> int:
    if os.geteuid() != 0:
        print(json.dumps({"status": "error", "error": "root_required"}))
        return 77
    try:
        raw = sys.stdin.buffer.read(256 * 1024 + 1)
        if len(raw) > 256 * 1024:
            raise ValueError("repository request exceeds its safety limit")
        repositories = validate(json.loads(raw))
        apply(repositories)
        resolved = sorted(_active_repositories())
        print(json.dumps({"status": "success", "repositories": resolved}))
        return 0
    except (OSError, ValueError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        print(json.dumps({"status": "error", "error": str(error)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
