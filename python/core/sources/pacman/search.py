import asyncio
from core.subprocess_utils import safe_subprocess
import re
import os
import sys
import shutil
import logging
from typing import List, Dict, Any, Optional

_PKG_HEADER_RE = re.compile(r'^([^\s/]+)/([^\s]+)\s+([^\s]+)(.*)$')

async def search_pacman(query: str, page: int = 1) -> List[Dict[str, Any]]:
    # Murphy-proof: Strict platform guard and binary discovery
    if not sys.platform.startswith("linux"):
        return []

    pacman_bin = shutil.which("pacman")
    if not pacman_bin:
        logging.warning("search_pacman: 'pacman' binary not found.")
        return []

    try:
        async with safe_subprocess(
            pacman_bin, '-Ss', query,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL,
            env={**os.environ, "LC_ALL": "C"}
        ) as proc:
            stdout, _ = await proc.communicate()
            raw_output = stdout.decode().strip()
            if not raw_output:
                return []

            packages = []
            current_pkg = None

            for line in raw_output.splitlines():
                if not line.strip():
                    continue

                header_match = _PKG_HEADER_RE.match(line)
                if header_match:
                    if current_pkg:
                        packages.append(current_pkg)

                    repo, name, version, extra = header_match.groups()
                    current_pkg = {
                        "name": name,
                        "id": name,
                        "repo": repo,
                        "last_version": version,
                        "source": "Pacman",
                        "description": "",
                        "installed": "[installed" in extra,
                        "variants": [{
                            "source": "Pacman",
                            "id": name,
                            "version": version,
                            "installed": "[installed" in extra
                        }]
                    }
                elif current_pkg and line.startswith("    "):
                    current_pkg["description"] += line.strip() + " "

            if current_pkg:
                packages.append(current_pkg)

            return packages
    except Exception:
        return []

async def get_pacman_details(package_id: str) -> Dict[str, Any]:
    pacman_bin = shutil.which("pacman")
    if not pacman_bin or not sys.platform.startswith("linux"):
        return {}

    for query_mode in ("-Qi", "-Si"):
        try:
            async with safe_subprocess(
                pacman_bin, query_mode, "--", package_id,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
                env={**os.environ, "LC_ALL": "C"}
            ) as proc:
                stdout, _ = await proc.communicate()
                if proc.returncode != 0 or not stdout:
                    continue
                details = {"name": package_id, "id": package_id, "source": "Pacman",
                           "installed": query_mode == "-Qi"}
                for line in stdout.decode(errors="replace").splitlines():
                    if ":" not in line:
                        continue
                    key, val = (part.strip() for part in line.split(":", 1))
                    if key == "Version": details["version"] = val
                    elif key == "Depends On": details["depends"] = [] if val == "None" else val.split()
                    elif key == "Installed Size": details["installed_size"] = val
                    elif key == "Download Size": details["download_size"] = val
                    elif key == "Description": details["description"] = val
                return details
        except OSError:
            continue
    return {}
