from unittest.mock import patch

import pytest
import daemon_main


@pytest.mark.asyncio
@pytest.mark.parametrize("payload", [None, {}, "Flatpak", [None], [{"source": "Flatpak"}, "invalid"]])
async def test_malformed_update_payload_never_starts_process(payload):
    with patch.object(daemon_main, "safe_subprocess") as process:
        await daemon_main.run_auto_updates(payload)
    process.assert_not_called()
