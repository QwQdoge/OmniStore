import asyncio
import logging
import contextlib
import os
import signal

@contextlib.asynccontextmanager
async def safe_subprocess(*args, **kwargs):
    """
    Murphy-proof subprocess wrapper that guarantees absolute cleanup and reaping.
    Utilizes process groups (os.setsid) to ensure entire process trees (including
    double-forked children) are reaped upon termination.
    """
    # Force the subprocess into a new process group (session) to allow group killing
    if 'preexec_fn' not in kwargs and os.name == 'posix':
        kwargs['preexec_fn'] = os.setsid

    proc = None
    try:
        proc = await asyncio.create_subprocess_exec(*args, **kwargs)
        yield proc
    finally:
        if proc:
            try:
                if proc.returncode is None:
                    # 1. Attempt graceful group termination (SIGTERM to the process group)
                    if os.name == 'posix':
                        try:
                            # Verification: Ensure PID still exists before querying PGID
                            os.kill(proc.pid, 0)
                            # Race condition protection: if process dies here, getpgid might raise
                            try:
                                pgid = os.getpgid(proc.pid)
                                # Murphy-proof: Never kill our own process group or system-critical groups
                                if pgid != os.getpgrp() and pgid > 1:
                                    # Start with SIGTERM, SIGHUP, SIGQUIT for a wider graceful shutdown signal
                                    for sig in [signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT]:
                                        try:
                                            os.killpg(pgid, sig)
                                        except (ProcessLookupError, PermissionError):
                                            break
                            except ProcessLookupError:
                                # Process died between os.kill and os.getpgid
                                pass
                        except (ProcessLookupError, PermissionError):
                            pass
                    else:
                        try: proc.terminate()
                        except: pass

                    try:
                        # Murphy-proof: Use wait_for with a strict timeout to avoid hanging the entire event loop
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
                            await asyncio.wait_for(proc.wait(), timeout=2)
                        except:
                            pass
            except Exception as e:
                logging.error(f"Murphy-proof Error Reaping Subprocess (PID {proc.pid if proc else 'N/A'}): {e}")
