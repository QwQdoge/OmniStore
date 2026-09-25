#!/usr/bin/env python3
"""Validate the release-bundle exporter consumed by Meo Settings.

This is deliberately dependency-free so it can run from an Arch PKGBUILD
``prepare()`` phase.  It verifies the *bundled* ``python_server`` rather than
the checkout's Python files: the Settings ABI is only publishable when both
are in agreement.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from typing import Any


EXPORT_FLAG = "--export-installed-usage"
MANAGEMENT_EXPORT_FLAG = "--export-app-management"
MANAGEMENT_ACTION_FLAG = "--app-action"
MANAGEMENT_APP_ID_FLAG = "--app-id"
SCHEMA = "org.meo.omnistore.installed-usage"
MANAGEMENT_SCHEMA = "org.meo.omnistore.app-management"
SCHEMA_VERSION = 1
MAX_OUTPUT_BYTES = 4 * 1024 * 1024
REQUIRED_SOURCE_MANIFESTS = (
    Path("plugins/sources/pacman/plugin.json"),
    Path("plugins/sources/flatpak/plugin.json"),
    Path("data/app-manifests/schema.json"),
)
ROLLBACK_HELPER = Path("backends/meo_stable_rollback.py")


def advertises_exporter(help_output: str) -> bool:
    """Return whether a backend help response advertises both public app ABIs."""
    return all(
        flag in help_output
        for flag in (
            EXPORT_FLAG,
            MANAGEMENT_EXPORT_FLAG,
            MANAGEMENT_ACTION_FLAG,
            MANAGEMENT_APP_ID_FLAG,
        )
    )


def _non_negative_int(value: Any) -> bool:
    return type(value) is int and value >= 0


def bundle_root_for(backend: Path) -> Path:
    """Resolve and validate the release root for ``backends/python_server``."""
    if backend.parent.name != "backends":
        raise ValueError("release backend must be located at backends/python_server")
    root = backend.parent.parent
    missing = [str(path) for path in REQUIRED_SOURCE_MANIFESTS if not (root / path).is_file()]
    if not (root / ROLLBACK_HELPER).is_file():
        missing.append(str(ROLLBACK_HELPER))
    if missing:
        raise ValueError(
            "release bundle is missing required source manifests or rollback helper: " + ", ".join(missing)
        )
    return root


def validate_snapshot(output: bytes) -> dict[str, Any]:
    """Parse the minimal schema-v1 response expected by Meo Settings."""
    if not output or len(output) > MAX_OUTPUT_BYTES:
        raise ValueError("exporter output is empty or exceeds the maximum size")
    try:
        value = json.loads(output)
    except (TypeError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError("exporter output is not one JSON document") from error
    if not isinstance(value, dict):
        raise ValueError("exporter output must be a JSON object")
    if value.get("schema") != SCHEMA or value.get("version") != SCHEMA_VERSION:
        raise ValueError("exporter output does not use the supported schema")
    if value.get("status") != "success":
        raise ValueError("exporter did not report success")
    if not isinstance(value.get("applications"), list) or not isinstance(value.get("sources"), list):
        raise ValueError("exporter output is missing application data")
    for field in ("applicationCount", "knownSizeBytes", "unknownSizeCount"):
        if not _non_negative_int(value.get(field)):
            raise ValueError(f"exporter output has an invalid {field}")
    return value


def validate_management_snapshot(output: bytes) -> dict[str, Any]:
    """Parse the non-destructive app-management inventory contract."""
    if not output or len(output) > MAX_OUTPUT_BYTES:
        raise ValueError("app-management output is empty or exceeds the maximum size")
    try:
        value = json.loads(output)
    except (TypeError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError("app-management output is not one JSON document") from error
    if not isinstance(value, dict):
        raise ValueError("app-management output must be a JSON object")
    if value.get("schema") != MANAGEMENT_SCHEMA or value.get("version") != SCHEMA_VERSION:
        raise ValueError("app-management output does not use the supported schema")
    if value.get("status") != "success":
        raise ValueError("app-management exporter did not report success")
    applications = value.get("applications")
    if not isinstance(applications, list) or not _non_negative_int(value.get("applicationCount")):
        raise ValueError("app-management output is missing application data")
    if value["applicationCount"] != len(applications):
        raise ValueError("app-management output has an inconsistent application count")
    for application in applications:
        if not isinstance(application, dict):
            raise ValueError("app-management output has an invalid application record")
        for field in ("id", "name", "sourceId", "sourceName", "sizeKind"):
            if not isinstance(application.get(field), str) or not application[field]:
                raise ValueError(f"app-management application has an invalid {field}")
        if not _non_negative_int(application.get("storageBytes")):
            raise ValueError("app-management application has an invalid storageBytes")
        if not isinstance(application.get("storage"), list):
            raise ValueError("app-management application is missing storage rows")
        if not isinstance(application.get("settings"), dict):
            raise ValueError("app-management application is missing settings metadata")
        if not isinstance(application.get("capabilities"), dict):
            raise ValueError("app-management application is missing capabilities")
    return value


def verify_release_backend(backend: Path, timeout: int) -> dict[str, Any]:
    """Run the candidate release backend with an isolated XDG environment."""
    if not backend.is_file() or not os.access(backend, os.X_OK):
        raise ValueError("release bundle has no executable backends/python_server")
    bundle_root = bundle_root_for(backend)

    try:
        help_result = subprocess.run(
            [str(backend), "--help"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ValueError("release backend could not be queried for supported arguments") from error
    if help_result.returncode != 0 or not advertises_exporter(
        help_result.stdout.decode("utf-8", errors="replace")
    ):
        raise ValueError(
            "release backend does not advertise the required app export/management flags; "
            "do not ship the Meo Settings wrappers from this bundle"
        )

    with tempfile.TemporaryDirectory(prefix="omnistore-export-contract-") as temporary_root:
        root = Path(temporary_root)
        environment = os.environ.copy()
        environment.update(
            {
                "XDG_CONFIG_HOME": str(root / "config"),
                "XDG_CACHE_HOME": str(root / "cache"),
                "XDG_DATA_HOME": str(root / "data"),
                "NO_COLOR": "1",
                "TERM": "dumb",
            }
        )
        try:
            result = subprocess.run(
                [str(backend), EXPORT_FLAG, "--json"],
                # Plugin manifests are intentionally part of the release
                # bundle. The packaged wrapper uses this same working dir.
                cwd=bundle_root,
                env=environment,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                timeout=timeout,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ValueError("release backend could not run the installed-app export") from error
    if result.returncode != 0:
        raise ValueError("release backend returned a failure for the installed-app export")
    usage_snapshot = validate_snapshot(result.stdout)

    with tempfile.TemporaryDirectory(prefix="omnistore-management-contract-") as temporary_root:
        root = Path(temporary_root)
        environment = os.environ.copy()
        environment.update(
            {
                "XDG_CONFIG_HOME": str(root / "config"),
                "XDG_CACHE_HOME": str(root / "cache"),
                "XDG_DATA_HOME": str(root / "data"),
                "XDG_STATE_HOME": str(root / "state"),
                "NO_COLOR": "1",
                "TERM": "dumb",
            }
        )
        try:
            management_result = subprocess.run(
                [str(backend), MANAGEMENT_EXPORT_FLAG, "--json"],
                cwd=bundle_root,
                env=environment,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
                timeout=timeout,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ValueError("release backend could not run the app-management export") from error
    if management_result.returncode != 0:
        raise ValueError("release backend returned a failure for the app-management export")
    management_snapshot = validate_management_snapshot(management_result.stdout)
    return {"usage": usage_snapshot, "management": management_snapshot}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify the release-bundle OmniStore app-usage export contract."
    )
    parser.add_argument("--backend", required=True, type=Path,
                        help="Path to the release bundle's backends/python_server")
    parser.add_argument("--timeout", type=int, default=45,
                        help="Per-process timeout in seconds (default: 45)")
    arguments = parser.parse_args()
    if arguments.timeout < 1 or arguments.timeout > 300:
        parser.error("--timeout must be between 1 and 300 seconds")
    try:
        snapshots = verify_release_backend(arguments.backend, arguments.timeout)
    except ValueError as error:
        print(f"release exporter contract failed: {error}", file=sys.stderr)
        return 1
    print(
        "release exporter contract verified: "
        f"{snapshots['usage']['applicationCount']} usage applications, "
        f"{snapshots['management']['applicationCount']} manageable applications, "
        f"{snapshots['usage']['knownSizeBytes']} known bytes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
