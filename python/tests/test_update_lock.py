import fcntl

from core.update_manager import UpdateManager


def test_update_lock_is_non_blocking_and_per_user(tmp_path, monkeypatch):
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(tmp_path))

    first = UpdateManager._acquire_update_lock()
    assert first is not None
    try:
        assert UpdateManager._acquire_update_lock() is None
    finally:
        fcntl.flock(first.fileno(), fcntl.LOCK_UN)
        first.close()

    second = UpdateManager._acquire_update_lock()
    assert second is not None
    fcntl.flock(second.fileno(), fcntl.LOCK_UN)
    second.close()
