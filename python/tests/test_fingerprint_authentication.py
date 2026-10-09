import asyncio
import json
from contextlib import asynccontextmanager

import pytest

from core.sources import utils
from core.transaction_manager import TransactionRecord, _TaskCapture


@pytest.mark.asyncio
async def test_pam_prompt_is_forwarded_before_authentication_finishes(monkeypatch):
    delivered = asyncio.Event()
    commands = []
    messages = []

    class Process:
        returncode = 0

        @property
        def stderr(self):
            async def stream():
                yield b"Place your right index finger on the fingerprint reader\n"
                await asyncio.wait_for(delivered.wait(), timeout=1)
            return stream()

        async def wait(self):
            assert delivered.is_set()
            return self.returncode

    @asynccontextmanager
    async def subprocess(*args, **kwargs):
        commands.append(args)
        assert kwargs["env"]["SUDO_ASKPASS"] == "/test/askpass"
        yield Process()

    async def askpass(self):
        return "/test/askpass"

    async def callback(message):
        messages.append(message)
        if "Place your right index finger" in message:
            delivered.set()

    monkeypatch.setattr(utils.os, "getuid", lambda: 1000)
    monkeypatch.setattr(utils, "safe_subprocess", subprocess)
    monkeypatch.setattr(utils.PrivilegeManager, "_find_askpass", askpass)
    assert await utils.PrivilegeManager().ensure_privileged(callback)
    assert len(commands) == 1
    assert "-A" in commands[0]
    assert "-n" not in commands[0]
    assert delivered.is_set()
    assert messages[-1] == "[INFO] Authorization confirmed."


def test_transaction_exposes_transient_fingerprint_prompt():
    record = TransactionRecord("test", "install", "test-app", "Pacman", status="running")
    capture = _TaskCapture(record)

    def emit(message):
        capture.write("[CALLBACK] " + json.dumps({"type": "log", "message": message}) + "\n")

    prompt = "Place your finger on the fingerprint reader"
    emit(prompt)
    assert record.snapshot()["authenticationPrompt"] == prompt
    record.status = "failed"
    assert record.snapshot()["authenticationPrompt"] == ""
    record.status = "running"
    emit("Authorization confirmed.")
    assert record.snapshot()["authenticationPrompt"] == ""
    emit("Installing fingerprint-reader-support")
    assert record.snapshot()["authenticationPrompt"] == ""
