import asyncio
import json
import os
import re
import shutil
import sys
from typing import Any, Dict, List, Optional, Tuple

from core.sources.base import UnifiedSource
from core.subprocess_utils import safe_subprocess


def _decode_output(data: bytes) -> str:
    return data.decode("utf-8", errors="ignore").replace("\r\n", "\n")


def _normalize_source_id(value: str) -> str:
    return value.strip().lower().replace(" ", "")


def _is_winget_package_id(value: str) -> bool:
    if not value or any(token in value for token in ("\\", "/", "…", "{", "}", "  ")):
        return False
    if " " in value:
        return False
    return bool(re.match(r"^[A-Za-z0-9][A-Za-z0-9.+_-]*(\.[A-Za-z0-9][A-Za-z0-9.+_-]*)+$", value))


class WingetSource(UnifiedSource):
    def __init__(self, weight: float = 1.0):
        super().__init__(name="Winget", weight=weight)
        self.enabled = sys.platform == "win32" and shutil.which("winget") is not None

    async def _run(
        self,
        *args: str,
        timeout: int = 30,
        callback=None,
    ) -> Tuple[int, str]:
        if not self.enabled:
            if callback:
                await callback("[ERROR] winget is not available on this system.")
            return 127, ""

        env = {
            **os.environ,
            "WINGET_DISABLE_INTERACTIVITY": "1",
        }
        async with safe_subprocess(
            "winget",
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=env,
        ) as proc:
            stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
            output = _decode_output(stdout or b"")
            return proc.returncode or 0, output

    async def _stream_run(
        self,
        args: List[str],
        callback=None,
        timeout: int = 1800,
    ) -> bool:
        if not self.enabled:
            if callback:
                await callback("[ERROR] winget is not available on this Windows installation.")
            return False

        if callback:
            await callback(f"[INFO] Running: winget {' '.join(args)}")
            await callback("[PROGRESS] 5")

        last_progress = 5
        env = {
            **os.environ,
            "WINGET_DISABLE_INTERACTIVITY": "1",
        }

        async with safe_subprocess(
            "winget",
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            env=env,
        ) as proc:
            async def _read_output():
                nonlocal last_progress
                if not proc.stdout:
                    return
                while True:
                    line_bytes = await proc.stdout.readline()
                    if not line_bytes:
                        break
                    line = _decode_output(line_bytes).strip()
                    if not line:
                        continue
                    if callback:
                        await callback(f"[INFO] {line}")
                        progress = self._progress_from_line(line, last_progress)
                        if progress > last_progress:
                            last_progress = progress
                            await callback(f"[PROGRESS] {progress}")
                        display_line = line[:48] + "..." if len(line) > 48 else line
                        await callback(f"[SPEED] {display_line}")

            await asyncio.wait_for(_read_output(), timeout=timeout)
            await asyncio.wait_for(proc.wait(), timeout=10)

        if proc.returncode == 0:
            if callback:
                await callback("[PROGRESS] 100")
            return True

        if callback:
            await callback(f"[ERROR] winget exited with code {proc.returncode}.")
        return False

    def _progress_from_line(self, line: str, current: int) -> int:
        lower = line.lower()
        percent_match = re.search(r"(\d{1,3})\s*%", line)
        if percent_match:
            return min(99, max(current, int(percent_match.group(1))))
        if "found" in lower or "package" in lower:
            return max(current, 20)
        if "downloading" in lower:
            return max(current, 35)
        if "installing" in lower or "uninstalling" in lower:
            return max(current, 70)
        if "successfully" in lower or "complete" in lower:
            return max(current, 95)
        return current

    async def search(
        self,
        query: str,
        page: int = 1,
        filters: Optional[Dict[str, Any]] = None,
        **kwargs,
    ) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []

        installed_task = kwargs.get("installed_winget_task")
        installed_set = await installed_task if installed_task is not None else await self._get_installed_ids()

        json_results = await self._search_json(query)
        if not json_results:
            json_results = await self._search_table(query)

        for item in json_results:
            item_id = item.get("id") or item.get("name", "")
            item["installed"] = _normalize_source_id(item_id) in installed_set
            item["variants"] = [{
                "source": "Winget",
                "id": item_id,
                "version": item.get("last_version", "Unknown"),
                "installed": item["installed"],
                "description": item.get("description", ""),
            }]
        return json_results

    async def _search_json(self, query: str) -> List[Dict[str, Any]]:
        code, output = await self._run(
            "search",
            query,
            "--source",
            "winget",
            "--accept-source-agreements",
            "--disable-interactivity",
            "--output",
            "json",
            timeout=20,
        )
        if code != 0:
            return []
        data = self._extract_json(output)
        rows = self._json_rows(data)
        return [self._result_from_row(row) for row in rows if self._result_from_row(row)]

    async def _search_table(self, query: str) -> List[Dict[str, Any]]:
        code, output = await self._run(
            "search",
            query,
            "--source",
            "winget",
            "--accept-source-agreements",
            "--disable-interactivity",
            timeout=20,
        )
        if code != 0:
            return []
        return self._parse_table(output)[:50]

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        package_id = self._package_id(package)
        if not package_id:
            if callback:
                await callback("[ERROR] Winget package ID is missing.")
            return False
        return await self._stream_run(
            [
                "install",
                "--id",
                package_id,
                "--exact",
                "--source",
                "winget",
                "--accept-package-agreements",
                "--accept-source-agreements",
                "--disable-interactivity",
            ],
            callback=callback,
            timeout=3600,
        )

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        package_id = self._package_id(package)
        if not package_id:
            if callback:
                await callback("[ERROR] Winget package ID is missing for uninstall.")
            return False
        return await self._stream_run(
            [
                "uninstall",
                "--id",
                package_id,
                "--exact",
                "--disable-interactivity",
            ],
            callback=callback,
            timeout=1800,
        )

    async def launch(self, package: Dict[str, Any]) -> bool:
        return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        package_id = self._package_id(package)
        if not package_id:
            return False
        code, output = await self._run(
            "show",
            "--id",
            package_id,
            "--exact",
            "--source",
            "winget",
            "--accept-source-agreements",
            "--disable-interactivity",
            timeout=15,
        )
        return code == 0 and bool(output.strip())

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        code, output = await self._run(
            "show",
            "--id",
            package_id,
            "--exact",
            "--source",
            "winget",
            "--accept-source-agreements",
            "--disable-interactivity",
            timeout=20,
        )
        if code != 0:
            return {"id": package_id, "source": "Winget"}
        details = self._parse_show(output)
        details.setdefault("id", package_id)
        details.setdefault("name", package_id)
        details["source"] = "Winget"
        details["primary_source"] = "Winget"
        details["variants"] = [{
            "source": "Winget",
            "id": package_id,
            "version": details.get("version", "Unknown"),
            "installed": False,
            "description": details.get("description", ""),
        }]
        return details

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        code, output = await self._run(
            "upgrade",
            "--id",
            package_id,
            "--exact",
            "--source",
            "winget",
            "--accept-source-agreements",
            "--disable-interactivity",
            timeout=20,
        )
        if code != 0:
            return None
        rows = self._parse_table(output)
        if not rows:
            return None
        row = rows[0]
        return {
            "name": row.get("name", package_id),
            "id": row.get("id", package_id),
            "source": "Winget",
            "current_version": row.get("version", "Unknown"),
            "new_version": row.get("available", row.get("last_version", "Unknown")),
        }

    async def _get_installed_ids(self) -> set:
        if not self.enabled:
            return set()
        code, output = await self._run(
            "list",
            "--source",
            "winget",
            "--accept-source-agreements",
            "--disable-interactivity",
            timeout=20,
        )
        if code != 0:
            return set()
        return {_normalize_source_id(item["id"]) for item in self._parse_table(output) if item.get("id")}

    async def list_installed(self) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []
        code, output = await self._run(
            "list",
            "--source",
            "winget",
            "--accept-source-agreements",
            "--disable-interactivity",
            timeout=25,
        )
        if code != 0:
            return []
        results = []
        for item in self._parse_table(output):
            package_id = item.get("id")
            if not package_id:
                continue
            size = await self.get_size(item)
            results.append({
                "name": item.get("name", package_id),
                "id": package_id,
                "primary_source": "Winget",
                "source": "Winget",
                "managed": True,
                "installed": True,
                "description": f"Winget package {package_id}",
                "version": item.get("version", "Unknown"),
                **size,
                "variants": [{"source": "Winget", "id": package_id, "version": item.get("version", "Unknown"), "installed": True, "managed": True, **size}],
            })
        return results

    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "download_size": package.get("download_size"),
            "installed_size": package.get("installed_size"),
            "disk_size": package.get("disk_size"),
            "size_confidence": package.get("size_confidence", "unknown"),
            "size_source": package.get("size_source", "winget metadata"),
        }

    def _package_id(self, package: Dict[str, Any]) -> str:
        return str(package.get("id") or package.get("name") or "").strip()

    def _extract_json(self, output: str) -> Any:
        try:
            return json.loads(output)
        except Exception:
            start_candidates = [i for i in (output.find("{"), output.find("[")) if i >= 0]
            if not start_candidates:
                return None
            start = min(start_candidates)
            end = max(output.rfind("}"), output.rfind("]"))
            if end <= start:
                return None
            try:
                return json.loads(output[start:end + 1])
            except Exception:
                return None

    def _json_rows(self, data: Any) -> List[Dict[str, Any]]:
        if isinstance(data, list):
            return [row for row in data if isinstance(row, dict)]
        if not isinstance(data, dict):
            return []
        for key in ("Data", "data", "Sources", "sources", "Packages", "packages"):
            value = data.get(key)
            if isinstance(value, list):
                rows = []
                for item in value:
                    if isinstance(item, dict) and isinstance(item.get("Packages"), list):
                        rows.extend(p for p in item["Packages"] if isinstance(p, dict))
                    elif isinstance(item, dict):
                        rows.append(item)
                return rows
        return []

    def _result_from_row(self, row: Dict[str, Any]) -> Dict[str, Any]:
        package_id = str(row.get("PackageIdentifier") or row.get("Id") or row.get("id") or "").strip()
        name = str(row.get("PackageName") or row.get("Name") or row.get("name") or package_id).strip()
        if not package_id or not name:
            return {}
        version = str(row.get("Version") or row.get("version") or "Unknown").strip()
        description = str(row.get("Description") or row.get("Moniker") or f"Winget package {package_id}").strip()
        return {
            "id": package_id,
            "name": name,
            "last_version": version,
            "version": version,
            "source": "Winget",
            "primary_source": "Winget",
            "description": description,
        }

    def _parse_table(self, output: str) -> List[Dict[str, Any]]:
        lines = [line.rstrip() for line in output.splitlines() if line.strip()]
        header_index = next((i for i, line in enumerate(lines) if "Name" in line and "Id" in line), -1)
        if header_index < 0:
            return []

        header = lines[header_index]
        columns = [(m.group(0), m.start()) for m in re.finditer(r"\S+", header)]
        if len(columns) < 2:
            return []

        rows = []
        for line in lines[header_index + 1:]:
            if set(line.strip()) <= {"-"}:
                continue
            cells: Dict[str, str] = {}
            for idx, (name, start) in enumerate(columns):
                end = columns[idx + 1][1] if idx + 1 < len(columns) else None
                cells[name.lower()] = line[start:end].strip()
            package_id = cells.get("id", "")
            display_name = cells.get("name", "")
            if not package_id or not display_name or package_id.lower() == "id":
                continue
            if not _is_winget_package_id(package_id):
                continue
            version = cells.get("version", "Unknown")
            result = {
                "id": package_id,
                "name": display_name,
                "last_version": version,
                "version": version,
                "source": "Winget",
                "primary_source": "Winget",
                "description": f"Winget package {package_id}",
            }
            if "available" in cells:
                result["available"] = cells["available"]
            rows.append(result)
        return rows

    def _parse_show(self, output: str) -> Dict[str, Any]:
        details: Dict[str, Any] = {}
        key_map = {
            "found": "name",
            "name": "name",
            "id": "id",
            "version": "version",
            "publisher": "developer",
            "publisher url": "homepage",
            "homepage": "homepage",
            "description": "description",
            "license": "license",
            "tags": "tags",
        }
        for raw_line in output.splitlines():
            line = raw_line.strip()
            if ":" not in line:
                continue
            key, value = [part.strip() for part in line.split(":", 1)]
            mapped = key_map.get(key.lower())
            if mapped and value:
                details[mapped] = value
        return details


class ScoopSource(UnifiedSource):
    def __init__(self, weight: float = 1.0):
        super().__init__(name="Scoop", weight=weight)
        self.enabled = shutil.which("scoop") is not None

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        return []

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        return False

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        return False

    async def launch(self, package: Dict[str, Any]) -> bool:
        return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None

    async def list_installed(self) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []
        try:
            async with safe_subprocess("scoop", "list", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await proc.communicate()
                results = []
                for line in stdout.decode(errors="ignore").splitlines():
                    parts = line.split()
                    if not parts or parts[0].lower() in {"name", "---"}:
                        continue
                    name = parts[0]
                    version = parts[1] if len(parts) > 1 else "Unknown"
                    size = await self.get_size({"name": name})
                    results.append({
                        "name": name,
                        "id": name,
                        "primary_source": "Scoop",
                        "source": "Scoop",
                        "managed": True,
                        "installed": True,
                        "version": version,
                        "description": "Scoop package",
                        **size,
                        "variants": [{"source": "Scoop", "id": name, "version": version, "installed": True, "managed": True, **size}],
                    })
                return results
        except Exception:
            return []

    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        name = package.get("id") or package.get("name")
        scoop_home = os.environ.get("SCOOP") or os.path.join(os.path.expanduser("~"), "scoop")
        app_dir = os.path.join(scoop_home, "apps", str(name), "current") if name else ""
        disk_size = _directory_size(app_dir)
        return {
            "download_size": None,
            "installed_size": _format_bytes(disk_size) if disk_size else None,
            "disk_size": disk_size or None,
            "size_confidence": "estimated" if disk_size else "unknown",
            "size_source": "filesystem scan",
        }


class BrewSource(UnifiedSource):
    def __init__(self, weight: float = 1.0):
        super().__init__(name="Homebrew", weight=weight)
        self.enabled = shutil.which("brew") is not None

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        return []

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        return False

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        return False

    async def launch(self, package: Dict[str, Any]) -> bool:
        return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        return False

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        return None

    async def list_installed(self) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []
        try:
            async with safe_subprocess("brew", "list", "--versions", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await proc.communicate()
                results = []
                for line in stdout.decode(errors="ignore").splitlines():
                    parts = line.split()
                    if not parts:
                        continue
                    name = parts[0]
                    version = parts[1] if len(parts) > 1 else "Unknown"
                    size = await self.get_size({"name": name})
                    results.append({
                        "name": name,
                        "id": name,
                        "primary_source": "Homebrew",
                        "source": "Homebrew",
                        "managed": True,
                        "installed": True,
                        "version": version,
                        "description": "Homebrew package",
                        **size,
                        "variants": [{"source": "Homebrew", "id": name, "version": version, "installed": True, "managed": True, **size}],
                    })
                return results
        except Exception:
            return []

    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        name = package.get("id") or package.get("name")
        try:
            async with safe_subprocess("brew", "--prefix", str(name), stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await proc.communicate()
                path = stdout.decode(errors="ignore").strip()
                disk_size = _directory_size(path)
                return {
                    "download_size": None,
                    "installed_size": _format_bytes(disk_size) if disk_size else None,
                    "disk_size": disk_size or None,
                    "size_confidence": "estimated" if disk_size else "unknown",
                    "size_source": "filesystem scan",
                }
        except Exception:
            return await super().get_size(package)


def _directory_size(path: str) -> int:
    if not path or not os.path.exists(path):
        return 0
    total = 0
    for root, _, files in os.walk(path):
        for filename in files:
            try:
                total += os.path.getsize(os.path.join(root, filename))
            except OSError:
                pass
    return total


def _format_bytes(size: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} B"
        value /= 1024
    return f"{size} B"
