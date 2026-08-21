import pytest

from core.update_manager import UpdateManager


@pytest.mark.asyncio
async def test_apt_update_parser(monkeypatch):
    manager = UpdateManager()

    async def fake_capture(command, timeout=45):
        assert command == ["apt", "list", "--upgradable"]
        return (
            0,
            "Listing... Done\n"
            "curl/noble-updates 8.5.0-2ubuntu10.6 amd64 [upgradable from: 8.5.0-2ubuntu10.5]\n",
        )

    monkeypatch.setattr(manager, "_capture", fake_capture)
    updates = await manager.check_apt_updates()

    assert updates == [
        {
            "name": "curl",
            "source": "APT",
            "current_version": "8.5.0-2ubuntu10.5",
            "new_version": "8.5.0-2ubuntu10.6",
            "description": "Update available from APT",
        }
    ]


@pytest.mark.asyncio
async def test_dnf_update_parser_accepts_exit_code_100(monkeypatch):
    manager = UpdateManager()

    async def fake_capture(command, timeout=45):
        if command == ["dnf", "check-upgrade", "--quiet"]:
            return 100, "firefox.x86_64 141.0-1.fc42 updates\n"
        if command[:3] == ["rpm", "-q", "--qf"]:
            return 0, "140.0-1.fc42"
        raise AssertionError(command)

    monkeypatch.setattr(manager, "_capture", fake_capture)
    updates = await manager.check_dnf_updates()

    assert updates == [
        {
            "name": "firefox",
            "source": "DNF",
            "current_version": "140.0-1.fc42",
            "new_version": "141.0-1.fc42",
            "description": "Update available from DNF",
        }
    ]
