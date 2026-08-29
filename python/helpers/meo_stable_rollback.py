#!/usr/bin/env python3
"""Commit a verified Meo-only Stable rollback without ``pacman -Suu``.

This helper is deliberately invoked only as root from OmniStore.  Its stdin
protocol contains no package names, URLs, shell fragments, or pacman options:

    {"version": 1, "operation": "preview"}
    {"version": 1, "operation": "commit", "planHash": "<sha256>"}

All package identities come from the locally installed meo-release catalog and
all Stable candidates come from the resolved [meo] sync database.  Any change
outside that catalog aborts before a transaction can commit.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator


CATALOG_PATH = Path("/usr/share/meo-release/package-catalog.json")
PACMAN_CONF = Path("/etc/pacman.conf")
PACMAN = "/usr/bin/pacman"
PACMAN_CONF_BIN = "/usr/bin/pacman-conf"
PACKAGE_NAME = re.compile(r"^[A-Za-z0-9@._+:-]+$")
PLAN_HASH = re.compile(r"^[0-9a-f]{64}$")
REQUEST_KEYS = {
    "preview": {"version", "operation"},
    "commit": {"version", "operation", "planHash"},
}


class RollbackError(RuntimeError):
    """Expected, user-safe failure of a rollback request."""


def _error(code: str) -> None:
    sys.stdout.write(json.dumps({"status": "error", "error": code}) + "\n")


def _read_request(raw: str) -> dict[str, str | int]:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as error:
        raise RollbackError("invalid_request") from error
    if not isinstance(payload, dict):
        raise RollbackError("invalid_request")
    operation = payload.get("operation")
    if operation not in REQUEST_KEYS or set(payload) != REQUEST_KEYS[operation]:
        raise RollbackError("invalid_request")
    if payload.get("version") != 1:
        raise RollbackError("unsupported_request_version")
    if operation == "commit" and not isinstance(payload.get("planHash"), str):
        raise RollbackError("invalid_request")
    if operation == "commit" and not PLAN_HASH.fullmatch(str(payload["planHash"])):
        raise RollbackError("invalid_request")
    return payload


def _catalog_packages(catalog_path: Path = CATALOG_PATH) -> tuple[str, ...]:
    try:
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RollbackError("meo_release_catalog_unavailable") from error
    if not isinstance(catalog, dict):
        raise RollbackError("meo_release_catalog_invalid")
    packages = catalog.get("packages")
    if isinstance(packages, dict):
        names = tuple(sorted(str(name) for name in packages))
    else:
        legacy = catalog.get("officialPackages")
        if not isinstance(legacy, list):
            raise RollbackError("meo_release_catalog_invalid")
        names = tuple(sorted(str(name) for name in legacy))
    if not names or len(set(names)) != len(names) or any(not PACKAGE_NAME.fullmatch(name) for name in names):
        raise RollbackError("meo_release_catalog_invalid")
    return names


def _repositories() -> tuple[str, ...]:
    result = subprocess.run(
        (PACMAN_CONF_BIN, "--repo-list"),
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if result.returncode:
        raise RollbackError("pacman_configuration_unavailable")
    repositories = tuple(line.strip().casefold() for line in result.stdout.splitlines() if line.strip())
    if not repositories or any(not re.fullmatch(r"[a-z0-9@._+-]+", name) for name in repositories):
        raise RollbackError("pacman_configuration_invalid")
    meo_repositories = tuple(name for name in repositories if name in {"meo", "meo-beta"})
    if meo_repositories != ("meo",):
        raise RollbackError("stable_channel_not_effective")
    return repositories


def _load_alpm_handle() -> Any:
    if not PACMAN_CONF.is_file():
        raise RollbackError("pacman_configuration_unavailable")
    try:
        from pycman.config import init_with_config  # type: ignore
    except ImportError as error:
        raise RollbackError("pyalpm_unavailable") from error
    try:
        return init_with_config(str(PACMAN_CONF))
    except Exception as error:
        raise RollbackError("pacman_configuration_invalid") from error


def _database(handle: Any, name: str) -> Any:
    for database in handle.get_syncdbs():
        if database.name == name:
            return database
    raise RollbackError("stable_database_unavailable")


def _candidate_packages(handle: Any, catalog: tuple[str, ...]) -> list[tuple[Any, Any]]:
    local = handle.get_localdb()
    stable = _database(handle, "meo")
    candidates: list[tuple[Any, Any]] = []
    try:
        import pyalpm  # type: ignore
    except ImportError as error:
        raise RollbackError("pyalpm_unavailable") from error
    for name in catalog:
        installed = local.get_pkg(name)
        if installed is None:
            continue
        candidate = stable.get_pkg(name)
        if candidate is None:
            raise RollbackError("stable_candidate_missing")
        if pyalpm.vercmp(installed.version, candidate.version) > 0:
            candidates.append((installed, candidate))
    return candidates


def _download_candidates(candidates: list[tuple[Any, Any]], staging: Path) -> list[Path]:
    if not candidates:
        return []
    targets = tuple(f"meo/{candidate.name}={candidate.version}" for _, candidate in candidates)
    result = subprocess.run(
        (PACMAN, "--config", str(PACMAN_CONF), "--cachedir", str(staging), "-Sw", "--noconfirm", *targets),
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if result.returncode:
        raise RollbackError("signed_package_download_failed")
    packages: list[Path] = []
    for _, candidate in candidates:
        filename = str(candidate.filename)
        if Path(filename).name != filename or not filename.endswith(".pkg.tar.zst"):
            raise RollbackError("stable_candidate_invalid")
        package = staging / filename
        signature = staging / f"{filename}.sig"
        if not package.is_file() or not signature.is_file():
            raise RollbackError("signed_package_download_incomplete")
        verified = subprocess.run(
            ("/usr/bin/pacman-key", "--verify", str(signature), str(package)),
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        if verified.returncode:
            raise RollbackError("package_signature_invalid")
        packages.append(package)
    return packages


def _package_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _changes(transaction: Any, catalog: set[str], installed_versions: dict[str, str]) -> list[dict[str, str]]:
    removals = list(transaction.to_remove)
    additions = list(transaction.to_add)
    if removals or any(package.name not in catalog for package in additions):
        raise RollbackError("rollback_would_change_non_meo_packages")
    return [
        {
            "name": package.name,
            "installed": installed_versions[package.name],
            "stable": package.version,
        }
        for package in sorted(additions, key=lambda item: item.name)
    ]


def _canonical_plan(changes: list[dict[str, str]], package_paths: dict[str, Path]) -> dict[str, Any]:
    packages = []
    for change in changes:
        path = package_paths.get(change["name"])
        if path is None:
            raise RollbackError("rollback_plan_invalid")
        packages.append({**change, "sha256": _package_sha256(path)})
    encoded = json.dumps(packages, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {"status": "success", "channel": "stable", "downgrades": packages,
            "planHash": hashlib.sha256(encoded).hexdigest()}


@contextmanager
def _staging_directory() -> Iterator[Path]:
    root = Path("/var/lib/omnistore")
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    if root.is_symlink() or root.stat().st_uid != 0:
        raise RollbackError("rollback_staging_unavailable")
    temporary = Path(tempfile.mkdtemp(prefix="stable-rollback-", dir=root))
    try:
        yield temporary
    finally:
        shutil.rmtree(temporary, ignore_errors=True)


def _make_transaction(handle: Any, candidates: list[tuple[Any, Any]], packages: list[Path]) -> tuple[Any, list[dict[str, str]], dict[str, Path]]:
    transaction = handle.init_transaction()
    package_paths: dict[str, Path] = {}
    try:
        for (_, candidate), path in zip(candidates, packages, strict=True):
            local_package = handle.load_pkg(str(path))
            if local_package.name != candidate.name or local_package.version != candidate.version:
                raise RollbackError("downloaded_package_identity_invalid")
            transaction.add_pkg(local_package)
            package_paths[local_package.name] = path
        transaction.prepare()
        installed_versions = {installed.name: installed.version for installed, _ in candidates}
        changes = _changes(transaction, {candidate.name for _, candidate in candidates}, installed_versions)
        return transaction, changes, package_paths
    except Exception:
        transaction.release()
        raise


def _execute(request: dict[str, str | int]) -> dict[str, Any]:
    if os.geteuid() != 0:
        raise RollbackError("root_required")
    catalog = _catalog_packages()
    _repositories()
    with _staging_directory() as staging:
        handle = _load_alpm_handle()
        candidates = _candidate_packages(handle, catalog)
        packages = _download_candidates(candidates, staging)
        transaction, changes, package_paths = _make_transaction(handle, candidates, packages)
        try:
            plan = _canonical_plan(changes, package_paths)
            if request["operation"] == "preview":
                return plan
            if request["planHash"] != plan["planHash"]:
                raise RollbackError("rollback_plan_drifted")
            transaction.commit()
            return {**plan, "status": "success", "committed": True}
        finally:
            transaction.release()


def main() -> int:
    try:
        request = _read_request(sys.stdin.read())
        result = _execute(request)
    except RollbackError as error:
        _error(str(error))
        return 1
    except Exception:
        _error("rollback_failed")
        return 1
    sys.stdout.write(json.dumps(result, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
