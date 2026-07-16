import asyncio
import inspect
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

    def config_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "source": {
                    "type": "string",
                    "default": "winget",
                    "description": "Winget source name to use for search/install/show.",
                },
                "extra_sources": {
                    "type": "array",
                    "description": "Additional winget sources for future source management.",
                    "items": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "arg": {"type": "string"},
                            "type": {"type": "string"},
                        },
                        "required": ["name", "arg"],
                    },
                },
            },
        }

    async def _run(
        self,
        *args: str,
        timeout: int = 30,
        callback=None,
    ) -> Tuple[int, str]:
        callback = self._async_callback(callback)
        if not self.enabled:
            if callback:
                await callback("[ERROR] winget is not available on this system.")
            return 127, ""

        env = {
            **os.environ,
            "WINGET_DISABLE_INTERACTIVITY": "1",
        }
        proc = None
        try:
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
        except asyncio.TimeoutError:
            if proc and proc.returncode is None:
                try:
                    proc.kill()
                    await proc.wait()
                except Exception:
                    pass
            if callback:
                await callback(f"[ERROR] winget command timed out after {timeout}s.")
            return 124, ""

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
        if not self.enabled:
            return []
        try:
            async with safe_subprocess("scoop", "search", query, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=25)
                installed = {item["id"].lower() for item in await self.list_installed()}
                results = []
                for line in _decode_output(stdout or b"").splitlines():
                    line = line.strip()
                    if not line or line.lower().startswith(("results", "name", "---")):
                        continue
                    parts = line.split()
                    name = parts[0]
                    version = parts[1] if len(parts) > 1 and not parts[1].startswith("[") else "Unknown"
                    bucket = parts[-1].strip("[]") if parts[-1].startswith("[") else ""
                    results.append({
                        "name": name,
                        "id": name,
                        "last_version": version,
                        "description": f"Scoop package{f' from {bucket}' if bucket else ''}",
                        "source": "Scoop",
                        "installed": name.lower() in installed,
                        "variants": [{"source": "Scoop", "id": name, "version": version, "installed": name.lower() in installed}],
                    })
                return results
        except Exception:
            return []

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        name = str(package.get("id") or package.get("name") or "").strip()
        if not name:
            if callback: await callback("[ERROR] Scoop package name missing.")
            return False
        return await _stream_simple_command(["scoop", "install", name], self.enabled, callback, "scoop", timeout=1800)

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        name = str(package.get("id") or package.get("name") or "").strip()
        if not name:
            if callback: await callback("[ERROR] Scoop package name missing for uninstall.")
            return False
        return await _stream_simple_command(["scoop", "uninstall", name], self.enabled, callback, "scoop", timeout=900)

    async def launch(self, package: Dict[str, Any]) -> bool:
        path = await self._prefix(package)
        if not path:
            return False
        cmd = "explorer" if sys.platform == "win32" else ("open" if sys.platform == "darwin" else "xdg-open")
        try:
            async with safe_subprocess(cmd, path, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL):
                return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        return await self.launch(package)

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {
            "name": package_id,
            "id": package_id,
            "source": "Scoop",
            "primary_source": "Scoop",
            "description": f"Scoop package {package_id}",
            "variants": [{"source": "Scoop", "id": package_id, "installed": False}],
        }

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        if not self.enabled:
            return None
        try:
            async with safe_subprocess("scoop", "status", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=20)
                for line in _decode_output(stdout or b"").splitlines():
                    parts = line.split()
                    if parts and parts[0].lower() == package_id.lower():
                        return {
                            "name": package_id,
                            "id": package_id,
                            "source": "Scoop",
                            "current_version": parts[1] if len(parts) > 1 else "Unknown",
                            "new_version": parts[2] if len(parts) > 2 else "Unknown",
                        }
        except Exception:
            return None
        return None

    async def _prefix(self, package: Dict[str, Any]) -> str:
        name = str(package.get("id") or package.get("name") or "").strip()
        if not name:
            return ""
        scoop_home = os.environ.get("SCOOP") or os.path.join(os.path.expanduser("~"), "scoop")
        app_dir = os.path.join(scoop_home, "apps", name, "current")
        return app_dir if os.path.exists(app_dir) else ""

    def config_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "buckets": {"type": "array", "items": {"type": "string"}, "description": "Extra Scoop buckets to add before searching/installing."}
            },
        }

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
        if not self.enabled:
            return []
        try:
            async with safe_subprocess("brew", "search", query, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=25)
                installed = {item["id"].lower() for item in await self.list_installed()}
                results = []
                for line in _decode_output(stdout or b"").splitlines():
                    name = line.strip()
                    if not name or name.startswith("==>"):
                        continue
                    results.append({
                        "name": name,
                        "id": name,
                        "last_version": "Unknown",
                        "description": f"Homebrew package {name}",
                        "source": "Homebrew",
                        "installed": name.lower() in installed,
                        "variants": [{"source": "Homebrew", "id": name, "installed": name.lower() in installed}],
                    })
                return results
        except Exception:
            return []

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        name = str(package.get("id") or package.get("name") or "").strip()
        if not name:
            if callback: await callback("[ERROR] Homebrew package name missing.")
            return False
        return await _stream_simple_command(["brew", "install", name], self.enabled, callback, "brew", timeout=1800)

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        name = str(package.get("id") or package.get("name") or "").strip()
        if not name:
            if callback: await callback("[ERROR] Homebrew package name missing for uninstall.")
            return False
        return await _stream_simple_command(["brew", "uninstall", name], self.enabled, callback, "brew", timeout=900)

    async def launch(self, package: Dict[str, Any]) -> bool:
        path = await self._prefix(package)
        if not path:
            return False
        cmd = "open" if sys.platform == "darwin" else "xdg-open"
        try:
            async with safe_subprocess(cmd, path, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL):
                return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        return await self.launch(package)

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        info: Dict[str, Any] = {
            "name": package_id,
            "id": package_id,
            "source": "Homebrew",
            "primary_source": "Homebrew",
            "description": f"Homebrew package {package_id}",
            "variants": [{"source": "Homebrew", "id": package_id, "installed": False}],
        }
        if not self.enabled:
            return info
        try:
            async with safe_subprocess("brew", "info", "--json=v2", package_id, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=20)
                data = json.loads(_decode_output(stdout or b"{}"))
                formulae = data.get("formulae") or []
                casks = data.get("casks") or []
                item = (formulae or casks or [{}])[0]
                info["description"] = item.get("desc") or info["description"]
                versions = item.get("versions") or {}
                info["version"] = versions.get("stable") or item.get("version") or "Unknown"
        except Exception:
            pass
        return info

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        if not self.enabled:
            return None
        try:
            async with safe_subprocess("brew", "outdated", "--json=v2", package_id, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=20)
                data = json.loads(_decode_output(stdout or b"{}"))
                items = (data.get("formulae") or []) + (data.get("casks") or [])
                if items:
                    item = items[0]
                    return {
                        "name": item.get("name", package_id),
                        "id": item.get("name", package_id),
                        "source": "Homebrew",
                        "current_version": item.get("installed_versions", ["Unknown"])[0] if item.get("installed_versions") else "Unknown",
                        "new_version": item.get("current_version", "Unknown"),
                    }
        except Exception:
            return None
        return None

    async def _prefix(self, package: Dict[str, Any]) -> str:
        name = str(package.get("id") or package.get("name") or "").strip()
        if not name or not self.enabled:
            return ""
        try:
            async with safe_subprocess("brew", "--prefix", name, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10)
                return _decode_output(stdout or b"").strip()
        except Exception:
            return ""

    def config_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "taps": {"type": "array", "items": {"type": "string"}, "description": "Extra Homebrew taps to enable."}
            },
        }

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


async def _stream_simple_command(command: List[str], enabled: bool, callback, tool_name: str, timeout: int = 900) -> bool:
    if callback is not None:
        original_callback = callback

        async def callback(message: str):
            result = original_callback(message)
            if inspect.isawaitable(result):
                await result

    if not enabled:
        if callback:
            await callback(f"[ERROR] {tool_name} is not available on this system.")
        return False
    if callback:
        await callback(f"[INFO] Running: {' '.join(command)}")
        await callback("[PROGRESS] 5")
    try:
        async with safe_subprocess(*command, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT) as proc:
            if proc.stdout:
                while True:
                    line = await asyncio.wait_for(proc.stdout.readline(), timeout=timeout)
                    if not line:
                        break
                    if callback:
                        await callback(f"[INFO] {_decode_output(line).strip()}")
            await asyncio.wait_for(proc.wait(), timeout=10)
            if callback and proc.returncode == 0:
                await callback("[PROGRESS] 100")
            return proc.returncode == 0
    except Exception as exc:
        if callback:
            await callback(f"[ERROR] {tool_name} command failed: {exc}")
        return False

class CommandPackageSource(UnifiedSource):
    """Generic subprocess-backed package source for platform package managers.

    The source stays disabled until its command exists on the current platform; this
    lets OmniStore list the plugin as available metadata without enabling unsafe or
    unavailable package managers by default.
    """

    manager_id = "command"
    command = ""
    platforms: Tuple[str, ...] = ()
    search_args: Tuple[str, ...] = ("search", "{query}")
    install_args: Tuple[str, ...] = ("install", "-y", "{id}")
    uninstall_args: Tuple[str, ...] = ("remove", "-y", "{id}")
    list_args: Tuple[str, ...] = ()
    update_args: Tuple[str, ...] = ()

    def __init__(self, name: str, weight: float = 1.0):
        super().__init__(name=name, weight=weight)
        platform_ok = not self.platforms or self._platform_key() in self.platforms
        self.enabled = bool(platform_ok and self.command and shutil.which(self.command))

    def config_schema(self) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "command": {"type": "string", "default": self.command},
                "repositories": {
                    "type": "array",
                    "description": f"Additional {self.name} repositories configured outside OmniStore.",
                    "items": {"type": "string"},
                },
            },
        }

    @staticmethod
    def _platform_key() -> str:
        if sys.platform == "win32":
            return "windows"
        if sys.platform == "darwin":
            return "macos"
        if sys.platform.startswith("linux"):
            return "linux"
        return sys.platform

    def _expand(self, args: Tuple[str, ...], package_id: str = "", query: str = "") -> List[str]:
        return [arg.format(id=package_id, query=query) for arg in args]

    async def _run_command(self, args: List[str], timeout: int = 30) -> Tuple[int, str]:
        if not self.enabled:
            return 127, ""
        try:
            async with safe_subprocess(
                self.command,
                *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
            ) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return proc.returncode or 0, _decode_output(stdout or b"")
        except asyncio.TimeoutError:
            return 124, ""
        except FileNotFoundError:
            self.enabled = False
            return 127, ""

    def _package_id(self, package: Dict[str, Any]) -> str:
        return str(package.get("id") or package.get("name") or "").strip()

    def _parse_search_output(self, output: str, query: str) -> List[Dict[str, Any]]:
        results: List[Dict[str, Any]] = []
        seen = set()
        for raw_line in output.splitlines():
            line = raw_line.strip()
            if not line or line.startswith(("WARNING", "Listing", "Name ", "---")):
                continue
            token = re.split(r"\s+", line, maxsplit=1)[0].strip()
            token = token.split("/")[-1]
            token = token.strip("*:")
            if not token or token.lower() in seen:
                continue
            if query and query.lower() not in line.lower() and query.lower() not in token.lower():
                continue
            seen.add(token.lower())
            results.append({
                "id": token,
                "name": token,
                "description": line,
                "source": self.name,
                "primary_source": self.name.lower(),
                "last_version": "Unknown",
                "installed": False,
                "variants": [{
                    "source": self.name,
                    "id": token,
                    "version": "Unknown",
                    "installed": False,
                    "description": line,
                }],
            })
            if len(results) >= 50:
                break
        return results

    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:
        if not self.enabled:
            return []
        code, output = await self._run_command(self._expand(self.search_args, query=query), timeout=25)
        if code != 0:
            return []
        return self._parse_search_output(output, query)

    async def install(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        package_id = self._package_id(package)
        if not package_id:
            if callback:
                await callback(f"[ERROR] {self.name} package id is missing.")
            return False
        if callback:
            await callback(f"[INFO] Running {self.name} install for {package_id}")
            await callback("[PROGRESS] 10")
        code, _ = await self._run_command(self._expand(self.install_args, package_id=package_id), timeout=3600)
        if callback:
            await callback("[PROGRESS] 100" if code == 0 else f"[ERROR] {self.name} install exited with {code}.")
        return code == 0

    async def uninstall(self, package: Dict[str, Any], callback=None) -> bool:
        callback = self._async_callback(callback)
        package_id = self._package_id(package)
        if not package_id:
            if callback:
                await callback(f"[ERROR] {self.name} package id is missing.")
            return False
        code, _ = await self._run_command(self._expand(self.uninstall_args, package_id=package_id), timeout=1800)
        return code == 0

    async def launch(self, package: Dict[str, Any]) -> bool:
        package_id = self._package_id(package)
        if not package_id:
            return False
        try:
            async with safe_subprocess(package_id, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL):
                return True
        except Exception:
            return False

    async def locate(self, package: Dict[str, Any]) -> bool:
        package_id = self._package_id(package)
        return bool(package_id and shutil.which(package_id))

    async def get_details(self, package_id: str) -> Dict[str, Any]:
        return {"id": package_id, "name": package_id, "source": self.name, "description": f"{self.name} package {package_id}"}

    async def check_update(self, package_id: str) -> Optional[Dict[str, Any]]:
        if not self.enabled or not self.update_args:
            return None
        code, output = await self._run_command(self._expand(self.update_args, package_id=package_id), timeout=60)
        if code == 0 and package_id.lower() in output.lower():
            return {"name": package_id, "source": self.name, "has_update": True, "raw": output[:500]}
        return None

    async def list_installed(self) -> List[Dict[str, Any]]:
        if not self.enabled or not self.list_args:
            return []
        code, output = await self._run_command(list(self.list_args), timeout=30)
        if code != 0:
            return []
        return self._parse_search_output(output, "")


    async def get_size(self, package: Dict[str, Any]) -> Dict[str, Any]:
        data = await super().get_size(package)
        data["size_source"] = self.name
        data["size_confidence"] = data.get("size_confidence") or "manager_metadata"
        return data


class AptSource(CommandPackageSource):
    manager_id = "apt"
    command = "apt-cache"
    platforms = ("linux",)
    search_args = ("search", "{query}")
    install_args = ("apt-get", "install", "-y", "{id}")
    uninstall_args = ("apt-get", "remove", "-y", "{id}")
    list_args = ("pkgnames",)

    def __init__(self, weight: float = 1.0):
        super().__init__("APT", weight)
        self.enabled = self.enabled and shutil.which("apt-get") is not None

    async def _run_command(self, args: List[str], timeout: int = 30) -> Tuple[int, str]:
        executable = self.command
        final_args = args
        if args and args[0] == "apt-get":
            executable = "apt-get"
            final_args = args[1:]
        if not shutil.which(executable):
            return 127, ""
        try:
            async with safe_subprocess(executable, *final_args, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT) as proc:
                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=timeout)
                return proc.returncode or 0, _decode_output(stdout or b"")
        except asyncio.TimeoutError:
            return 124, ""


class DnfSource(CommandPackageSource):
    manager_id = "dnf"
    command = "dnf"
    platforms = ("linux",)
    search_args = ("search", "{query}")
    install_args = ("install", "-y", "{id}")
    uninstall_args = ("remove", "-y", "{id}")
    list_args = ("list", "installed")
    update_args = ("check-update", "{id}")

    def __init__(self, weight: float = 1.0):
        super().__init__("DNF", weight)


class ZypperSource(CommandPackageSource):
    manager_id = "zypper"
    command = "zypper"
    platforms = ("linux",)
    search_args = ("--non-interactive", "search", "{query}")
    install_args = ("--non-interactive", "install", "{id}")
    uninstall_args = ("--non-interactive", "remove", "{id}")
    list_args = ("--non-interactive", "search", "--installed-only")

    def __init__(self, weight: float = 1.0):
        super().__init__("Zypper", weight)


class ApkSource(CommandPackageSource):
    manager_id = "apk"
    command = "apk"
    platforms = ("linux",)
    search_args = ("search", "{query}")
    install_args = ("add", "{id}")
    uninstall_args = ("del", "{id}")
    list_args = ("info",)

    def __init__(self, weight: float = 1.0):
        super().__init__("APK", weight)


class ChocolateySource(CommandPackageSource):
    manager_id = "chocolatey"
    command = "choco"
    platforms = ("windows",)
    search_args = ("search", "{query}", "--limit-output")
    install_args = ("install", "{id}", "-y", "--no-progress")
    uninstall_args = ("uninstall", "{id}", "-y")
    list_args = ("list", "--local-only", "--limit-output")
    update_args = ("outdated", "--limit-output")

    def __init__(self, weight: float = 1.0):
        super().__init__("Chocolatey", weight)


class FdroidSource(CommandPackageSource):
    manager_id = "fdroid"
    command = "fdroidcl"
    platforms = ("linux", "macos", "windows", "android")
    search_args = ("search", "{query}")
    install_args = ("install", "{id}")
    uninstall_args = ("uninstall", "{id}")
    list_args = ("list", "--installed")
    update_args = ("update", "{id}")

    def __init__(self, weight: float = 1.0):
        super().__init__("F-Droid", weight)
