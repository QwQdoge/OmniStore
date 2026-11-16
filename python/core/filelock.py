"""Non-blocking exclusive file lock that works on POSIX and Windows."""

import os

try:  # POSIX
    import fcntl
except ImportError:  # Windows
    fcntl = None
    import msvcrt


def try_lock(file) -> None:
    """Raise OSError when another process holds the lock."""
    if fcntl is not None:
        fcntl.flock(file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return
    file.seek(0)
    msvcrt.locking(file.fileno(), msvcrt.LK_NBLCK, 1)


def unlock(file) -> None:
    if fcntl is not None:
        fcntl.flock(file.fileno(), fcntl.LOCK_UN)
        return
    file.seek(0)
    msvcrt.locking(file.fileno(), msvcrt.LK_UNLCK, 1)
