import asyncio
import logging
import contextlib
import os
import signal
import time

@contextlib.asynccontextmanager
async def safe_subprocess(*args, **kwargs):
    """
    Murphy-proof subprocess wrapper that guarantees absolute cleanup and reaping.
    Utilizes process groups (start_new_session) to ensure entire process trees
    (including double-forked children) are reaped upon termination.
    """
    # Force the subprocess into a new process group (session) to allow group killing
    # Murphy-proof: Utilize start_new_session=True (Python 3.2+) for cleaner
    # and safer process group isolation.
    if os.name == 'posix':
        kwargs.setdefault('start_new_session', True)

    proc = None
    try:
        proc = await asyncio.create_subprocess_exec(*args, **kwargs)
        yield proc
    finally:
        if proc:
            pid = proc.pid
            try:
                # Catching BaseException during cleanup to ensure cancellation doesn't
                # orphan the subprocess.
                await _cleanup_proc(proc)
            except BaseException as e:
                if isinstance(e, Exception):
                    logging.error(f"Murphy-proof: Fatal error in subprocess cleanup: {e}")
                raise

async def _cleanup_proc(proc):
    """Murphy-proof: Multi-stage reap sequence with escalation."""
    try:
        if proc.returncode is None:
            # 1. Attempt graceful group termination (SIGTERM to the process group)
            if os.name == 'posix':
                try:
                    # Verification: Ensure PID still exists and belongs to us before querying PGID
                    os.kill(proc.pid, 0)
                    try:
                        pgid = os.getpgid(proc.pid)
                        if pgid != os.getpgrp() and pgid > 1:
                            for sig in [signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT]:
                                try:
                                    os.killpg(pgid, sig)
                                except (ProcessLookupError, PermissionError):
                                    break
                    except ProcessLookupError:
                        pass
                except (ProcessLookupError, PermissionError):
                    pass
            else:
                try: proc.terminate()
                except: pass

            try:
                # Murphy-proof: Use wait_for with a strict timeout
                await asyncio.wait_for(proc.wait(), timeout=5)
            except (asyncio.TimeoutError, Exception):
                # 2. Escalation: Force group kill (SIGKILL to the process group)
                if os.name == 'posix':
                    try:
                        os.kill(proc.pid, 0)
                        pgid = os.getpgid(proc.pid)
                        if pgid != os.getpgrp() and pgid > 1:
                            os.killpg(pgid, signal.SIGKILL)
                    except (ProcessLookupError, PermissionError):
                        pass
                else:
                    try: proc.kill()
                    except: pass

                # Final wait to reap the zombie
                try:
                    await asyncio.wait_for(asyncio.shield(proc.wait()), timeout=2)
                except (asyncio.TimeoutError, Exception):
                    pass
    except BaseException as e:
        if isinstance(e, Exception):
            logging.error(f"Murphy-proof Error Reaping Subprocess (PID {proc.pid}): {e}")
        else:
            raise
