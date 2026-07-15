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
    """Murphy-proof: Multi-stage reap sequence with escalation for process trees."""
    try:
        if proc.returncode is None:
            # 1. Stage 1: Graceful SIGTERM on the entire process group (POSIX) or terminate (Windows)
            if os.name == 'posix':
                try:
                    # Verification: Ensure PID still exists before querying PGID
                    os.kill(proc.pid, 0)
                    try:
                        pgid = os.getpgid(proc.pid)
                        # Ensure we don't kill our own group or PID 1
                        if pgid != os.getpgrp() and pgid > 1:
                            os.killpg(pgid, signal.SIGTERM)
                    except (ProcessLookupError, PermissionError):
                        proc.terminate()
                except (ProcessLookupError, PermissionError):
                    pass
            else:
                try:
                    import subprocess
                    if os.name == 'nt':
                        # Murphy-proof: Windows tree kill using taskkill
                        subprocess.run(['taskkill', '/F', '/T', '/PID', str(proc.pid)],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    else:
                        proc.terminate()
                except: pass

            try:
                # Murphy-proof: Wait for graceful termination
                await asyncio.wait_for(proc.wait(), timeout=3)
            except BaseException:
                # 2. Stage 2: Escalation to Forceful SIGKILL (POSIX) or taskkill (Windows)
                if os.name == 'posix':
                    try:
                        os.kill(proc.pid, 0)
                        pgid = os.getpgid(proc.pid)
                        if pgid != os.getpgrp() and pgid > 1:
                            os.killpg(pgid, signal.SIGKILL)
                        else:
                            proc.kill()
                    except (ProcessLookupError, PermissionError):
                        proc.kill()
                elif os.name == 'nt':
                    try:
                        # Use taskkill tree-kill for absolute reaping on Windows
                        import subprocess
                        subprocess.run(['taskkill', '/F', '/T', '/PID', str(proc.pid)],
                                     capture_output=True, timeout=5)
                    except Exception:
                        proc.kill()
                else:
                    try:
                        if os.name == 'nt':
                             import subprocess
                             subprocess.run(['taskkill', '/F', '/T', '/PID', str(proc.pid)],
                                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        else:
                            proc.kill()
                    except: pass

                # Final fail-safe wait to reap the zombie/handle
                try:
                    await asyncio.wait_for(asyncio.shield(proc.wait()), timeout=2)
                except (asyncio.TimeoutError, Exception):
                    pass
    except BaseException as e:
        if isinstance(e, Exception):
            logging.error(f"Murphy-proof: Error Reaping Subprocess (PID {proc.pid}): {e}")
        else:
            raise
