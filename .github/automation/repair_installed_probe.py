from pathlib import Path

path = Path("python/core/sources/external.py")
text = path.read_text()


def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one match, found {count}: {old[:80]!r}")
    text = text.replace(old, new, 1)


replace_once(
    "import inspect\nimport json\nimport os\nimport re\nimport shutil\nimport sys\n",
    "import inspect\nimport json\nimport logging\nimport os\nimport re\nimport shutil\nimport subprocess\nimport sys\n",
)

scoop_anchor = '''        self.enabled = shutil.which("scoop") is not None\n\n    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:\n'''
scoop_helper = '''        self.enabled = shutil.which("scoop") is not None\n\n    async def _get_installed_ids(self) -> Optional[set[str]]:\n        if not self.enabled:\n            return set()\n        try:\n            async with safe_subprocess("scoop", "list", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:\n                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=20)\n                installed = set()\n                for line in _decode_output(stdout or b"").splitlines():\n                    parts = line.split()\n                    if not parts or parts[0].lower() in {"name", "---"} or set(parts[0]) <= {"-"}:\n                        continue\n                    installed.add(parts[0].lower())\n                return installed\n        except (asyncio.TimeoutError, OSError, subprocess.SubprocessError) as exc:\n            logging.getLogger(__name__).warning("Scoop installed-state probe failed; falling back to full installed lookup: %s", exc)\n            return None\n\n    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:\n'''
replace_once(scoop_anchor, scoop_helper)

replace_once(
    '''                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=25)\n                installed = {item["id"].lower() for item in await self.list_installed()}\n                results = []\n''',
    '''                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=20)\n                installed = await self._get_installed_ids()\n                if installed is None:\n                    installed = {item["id"].lower() for item in await self.list_installed()}\n                results = []\n''',
)

replace_once(
    '''                return results\n        except Exception:\n            return []\n\n    async def install(self, package: Dict[str, Any], callback=None) -> bool:\n        callback = self._async_callback(callback)\n        name = str(package.get("id") or package.get("name") or "").strip()\n        if not name:\n            if callback: await callback("[ERROR] Scoop package name missing.")\n''',
    '''                return results\n        except (asyncio.TimeoutError, OSError, subprocess.SubprocessError) as exc:\n            logging.getLogger(__name__).warning("Scoop search failed: %s", exc)\n            return []\n\n    async def install(self, package: Dict[str, Any], callback=None) -> bool:\n        callback = self._async_callback(callback)\n        name = str(package.get("id") or package.get("name") or "").strip()\n        if not name:\n            if callback: await callback("[ERROR] Scoop package name missing.")\n''',
)

replace_once(
    '''                    if not parts or parts[0].lower() in {"name", "---"}:\n                        continue\n                    name = parts[0]\n''',
    '''                    if not parts or parts[0].lower() in {"name", "---"} or set(parts[0]) <= {"-"}:\n                        continue\n                    name = parts[0]\n''',
)

brew_anchor = '''        self.enabled = shutil.which("brew") is not None\n\n    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:\n'''
brew_helper = '''        self.enabled = shutil.which("brew") is not None\n\n    async def _get_installed_ids(self) -> Optional[set[str]]:\n        if not self.enabled:\n            return set()\n        try:\n            async with safe_subprocess("brew", "list", "--versions", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL) as proc:\n                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=20)\n                installed = set()\n                for line in _decode_output(stdout or b"").splitlines():\n                    parts = line.split()\n                    if parts:\n                        installed.add(parts[0].lower())\n                return installed\n        except (asyncio.TimeoutError, OSError, subprocess.SubprocessError) as exc:\n            logging.getLogger(__name__).warning("Homebrew installed-state probe failed; falling back to full installed lookup: %s", exc)\n            return None\n\n    async def search(self, query: str, page: int = 1, filters: Optional[Dict[str, Any]] = None, **kwargs) -> List[Dict[str, Any]]:\n'''
replace_once(brew_anchor, brew_helper)

replace_once(
    '''                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=25)\n                installed = {item["id"].lower() for item in await self.list_installed()}\n                results = []\n''',
    '''                stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=20)\n                installed = await self._get_installed_ids()\n                if installed is None:\n                    installed = {item["id"].lower() for item in await self.list_installed()}\n                results = []\n''',
)

replace_once(
    '''                return results\n        except Exception:\n            return []\n\n    async def install(self, package: Dict[str, Any], callback=None) -> bool:\n        callback = self._async_callback(callback)\n        name = str(package.get("id") or package.get("name") or "").strip()\n        if not name:\n            if callback: await callback("[ERROR] Homebrew package name missing.")\n''',
    '''                return results\n        except (asyncio.TimeoutError, OSError, subprocess.SubprocessError) as exc:\n            logging.getLogger(__name__).warning("Homebrew search failed: %s", exc)\n            return []\n\n    async def install(self, package: Dict[str, Any], callback=None) -> bool:\n        callback = self._async_callback(callback)\n        name = str(package.get("id") or package.get("name") or "").strip()\n        if not name:\n            if callback: await callback("[ERROR] Homebrew package name missing.")\n''',
)

path.write_text(text)

Path("python/tests/test_external_sources_installed_probe.py").write_text(
    '''import asyncio\nimport subprocess\nfrom unittest.mock import AsyncMock, patch\n\nimport pytest\n\nfrom core.sources.external import BrewSource, ScoopSource\n\n\ndef _process(stdout=b""):\n    proc = AsyncMock()\n    proc.communicate.return_value = (stdout, b"")\n    return proc\n\n\n@pytest.mark.asyncio\nasync def test_scoop_fast_probe_avoids_full_installed_scan():\n    source = ScoopSource()\n    source.enabled = True\n    search_proc = _process(b"git 2.50.0 [main]\\n")\n    source._get_installed_ids = AsyncMock(return_value={"git"})\n    source.list_installed = AsyncMock(side_effect=AssertionError("slow installed scan must not run"))\n    with patch("core.sources.external.safe_subprocess") as safe:\n        safe.return_value.__aenter__.return_value = search_proc\n        results = await source.search("git")\n    assert results[0]["installed"] is True\n    source.list_installed.assert_not_called()\n\n\n@pytest.mark.asyncio\nasync def test_scoop_probe_failure_falls_back_without_false_uninstalled_state():\n    source = ScoopSource()\n    source.enabled = True\n    search_proc = _process(b"git 2.50.0 [main]\\n")\n    source._get_installed_ids = AsyncMock(return_value=None)\n    source.list_installed = AsyncMock(return_value=[{"id": "git"}])\n    with patch("core.sources.external.safe_subprocess") as safe:\n        safe.return_value.__aenter__.return_value = search_proc\n        results = await source.search("git")\n    assert results[0]["installed"] is True\n    source.list_installed.assert_awaited_once()\n\n\n@pytest.mark.asyncio\nasync def test_brew_probe_failure_falls_back_without_false_uninstalled_state():\n    source = BrewSource()\n    source.enabled = True\n    search_proc = _process(b"wget\\n")\n    source._get_installed_ids = AsyncMock(return_value=None)\n    source.list_installed = AsyncMock(return_value=[{"id": "wget"}])\n    with patch("core.sources.external.safe_subprocess") as safe:\n        safe.return_value.__aenter__.return_value = search_proc\n        results = await source.search("wget")\n    assert results[0]["installed"] is True\n    source.list_installed.assert_awaited_once()\n\n\n@pytest.mark.asyncio\nasync def test_expected_probe_failure_returns_unknown_signal_and_logs(caplog):\n    source = ScoopSource()\n    source.enabled = True\n    proc = AsyncMock()\n    proc.communicate.side_effect = asyncio.TimeoutError()\n    with patch("core.sources.external.safe_subprocess") as safe:\n        safe.return_value.__aenter__.return_value = proc\n        with caplog.at_level("WARNING"):\n            installed = await source._get_installed_ids()\n    assert installed is None\n    assert "falling back" in caplog.text\n\n\n@pytest.mark.asyncio\nasync def test_unexpected_probe_and_search_errors_propagate():\n    source = ScoopSource()\n    source.enabled = True\n    proc = AsyncMock()\n    proc.communicate.side_effect = TypeError("programming error")\n    with patch("core.sources.external.safe_subprocess") as safe:\n        safe.return_value.__aenter__.return_value = proc\n        with pytest.raises(TypeError, match="programming error"):\n            await source._get_installed_ids()\n        with pytest.raises(TypeError, match="programming error"):\n            await source.search("git")\n\n\n@pytest.mark.asyncio\nasync def test_expected_search_subprocess_error_is_logged_and_safe(caplog):\n    source = BrewSource()\n    source.enabled = True\n    proc = AsyncMock()\n    proc.communicate.side_effect = subprocess.SubprocessError("brew failed")\n    with patch("core.sources.external.safe_subprocess") as safe:\n        safe.return_value.__aenter__.return_value = proc\n        with caplog.at_level("WARNING"):\n            results = await source.search("wget")\n    assert results == []\n    assert "Homebrew search failed" in caplog.text\n'''
)
