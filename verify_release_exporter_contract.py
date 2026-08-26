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
SCHEMA = "org.meo.omnistore.installed-usage"
SCHEMA_VERSION = 1
MAX_OUTPUT_BYTES = 4 * 1024 * 1024
REQUIRED_SOURCE_MANIFESTS = (
    Path("plugins/sources/pacman/plugin.json"),
    Path("plugins/sources/flatpak/plugin.json"),
)


def advertises_exporter(help_output: str) -> bool:
    """Return whether a backend help response advertises the public flag."""
    return EXPORT_FLAG in help_output


def _non_negative_int(value: Any) -> bool:
    return type(value) is int and value >= 0


def bundle_root_for(backend: Path) -> Path:
    """Resolve and validate the release root for ``backends/python_server``."""
    if backend.parent.name != "backends":
        raise ValueError("release backend must be located at backends/python_server")
    root = backend.parent.parent
    missing = [str(path) for path in REQUIRED_SOURCE_MANIFESTS if not (root / path).is_file()]
    if missing:
        raise ValueError(
            "release bundle is missing required built-in source manifests: " + ", ".join(missing)
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
            "release backend does not advertise --export-installed-usage; "
            "do not ship the Meo Settings wrapper from this bundle"
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
    return validate_snapshot(result.stdout)


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
        snapshot = verify_release_backend(arguments.backend, arguments.timeout)
    except ValueError as error:
        print(f"release exporter contract failed: {error}", file=sys.stderr)
        return 1
    print(
        "release exporter contract verified: "
        f"{snapshot['applicationCount']} applications, "
        f"{snapshot['knownSizeBytes']} known bytes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
