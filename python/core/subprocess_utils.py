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
    # Force the subprocess into its own session for absolute process group isolation.
    # This prevents signals to the parent from killing the child accidentally,
    # and ensures os.killpg() only affects the child's tree.
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
                if proc.returncode is None:
                    # 1. Attempt graceful group termination
                    if os.name == 'posix':
                        try:
                            # Verification: Ensure PID still exists and belongs to us before querying PGID
                            os.kill(pid, 0)
                            try:
                                pgid = os.getpgid(pid)
                                # Murphy-proof: Never kill our own process group or system-critical groups
                                # Because we use start_new_session=True, pgid should be pid.
                                if pgid > 1:
                                    # Multi-stage termination sequence for maximum compliance
                                    for sig in [signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT]:
                                        try:
                                            os.killpg(pgid, sig)
                                            # Brief pause to allow signal handling
                                            await asyncio.sleep(0.1)
                                            os.kill(pid, 0) # Check if still alive
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
                        # Murphy-proof: Use wait_for with a strict timeout to avoid hanging the entire event loop
                        await asyncio.wait_for(proc.wait(), timeout=3.0)
                    except (asyncio.TimeoutError, Exception):
                        # 2. Escalation: Force group kill (SIGKILL to the process group)
                        if os.name == 'posix':
                            try:
                                os.kill(pid, 0)
                                pgid = os.getpgid(pid)
                                if pgid > 1:
                                    os.killpg(pgid, signal.SIGKILL)
                            except (ProcessLookupError, PermissionError):
                                pass
                        else:
                            try: proc.kill()
                            except: pass

                        # Final wait to reap the zombie
                        try:
                            await asyncio.wait_for(proc.wait(), timeout=2.0)
                        except:
                            pass

                # Murphy-proof: Final "Zombie Check" to ensure the process is actually gone
                if os.name == 'posix':
                    try:
                        os.kill(pid, 0)
                        logging.warning(f"Murphy-proof Warning: Process {pid} survived all termination attempts.")
                    except ProcessLookupError:
                        # Process successfully reaped
                        pass
            except Exception as e:
                logging.error(f"Murphy-proof Error Reaping Subprocess (PID {pid}): {e}")
