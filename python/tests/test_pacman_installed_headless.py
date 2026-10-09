import os

import pytest

from core.sources.pacman import PacmanSource


@pytest.mark.asyncio
async def test_installed_metadata_does_not_require_a_terminal(tmp_path, monkeypatch):
    pacman = tmp_path / "pacman"
    pacman.write_text("""#!/usr/bin/env python3
import sys
if '-' in sys.argv:
    print('error: failed to reopen stdin for reading', file=sys.stderr)
elif any('i' in arg and arg.startswith('-Q') for arg in sys.argv):
    print('Name : native-app\\nVersion : 1.2-1\\nInstalled Size : 2.00 MiB\\n')
else:
    print('native-app')
""")
    pacman.chmod(0o755)
    monkeypatch.setenv("PATH", f"{tmp_path}:{os.environ['PATH']}")
    source = PacmanSource()
    source.enabled = True

    rows = await source.list_installed()

    assert len(rows) == 1
    assert rows[0]["id"] == "native-app"
    assert rows[0]["version"] == "1.2-1"
    assert rows[0]["installed_size"] == "2.00 MiB"
