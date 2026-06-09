import asyncio
from core.subprocess_utils import safe_subprocess
import re
import os
from typing import List, Dict, Any, Optional

_PKG_HEADER_RE = re.compile(r'^([^\s/]+)/([^\s]+)\s+([^\s]+)(.*)$')

async def search_pacman(query: str, page: int = 1) -> List[Dict[str, Any]]:
    if not os.path.exists("/usr/bin/pacman"):
        return []

    try:
        async with safe_subprocess(
            'pacman', '-Ss', query,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL
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
                        "repo": repo,
                        "last_version": version,
                        "source": "Pacman",
                        "description": "",
                        "installed": "[installed]" in extra,
                        "variants": [{
                            "source": "Pacman",
                            "version": version,
                            "installed": "[installed]" in extra
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
    try:
        async with safe_subprocess(
            "pacman", "-Si", package_id,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL
        ) as proc:
            stdout, _ = await proc.communicate()
            if stdout:
                info = stdout.decode()
                details = {"name": package_id, "source": "Pacman"}
                for line in info.splitlines():
                    if ":" in line:
                        key, val = line.split(":", 1)
                        key = key.strip()
                        val = val.strip()
                        if key == "Depends On": details["depends"] = val.split()
                        elif key == "Installed Size": details["installed_size"] = val
                        elif key == "Description": details["description"] = val
                return details
    except Exception:
        pass
    return {}
