import shutil
from typing import List, Dict

class SnapSearch:
    """Simple Snap package search implementation.

    This is a minimal placeholder that uses the `snap` command if available.
    It returns results in the same format as other SearchSource classes.
    """
    def __init__(self, session):
        self.session = session
        self.enabled = shutil.which('snap') is not None

    async def search(self, query: str) -> List[Dict]:
        """Search Snap store for the given query.

        Returns a list of dicts with keys: name, version, description, source.
        """
        if not self.enabled:
            return []
        # Use subprocess to call `snap find <query>` and parse output.
        import asyncio, shlex
        proc = await asyncio.create_subprocess_exec(
            'snap', 'find', query,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()
        lines = stdout.decode().splitlines()
        results = []
        # Skip header lines (first line is column names)
        for line in lines[1:]:
            parts = line.split()
            if len(parts) < 3:
                continue
            name = parts[0]
            version = parts[1]
            description = ' '.join(parts[2:])
            results.append({
                'name': name,
                'version': version,
                'description': description,
                'source': 'snap',
            })
        return results
