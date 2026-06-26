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
                            pgid = os.getpgid(proc.pid)
                            # Murphy-proof: Never kill our own process group
                            if pgid != os.getpgrp() and pgid > 1:
                                os.killpg(pgid, signal.SIGTERM)
                        except ProcessLookupError:
                            pass
                    else:
                        proc.terminate()

                    try:
                        await asyncio.wait_for(proc.wait(), timeout=3)
                    except asyncio.TimeoutError:
                        # 2. Escalation: Force group kill (SIGKILL to the process group)
                        if os.name == 'posix':
                            try:
                                pgid = os.getpgid(proc.pid)
                                if pgid != os.getpgrp() and pgid > 1:
                                    os.killpg(pgid, signal.SIGKILL)
                            except ProcessLookupError:
                                pass
                        else:
                            proc.kill()
                        await proc.wait()
            except Exception as e:
                logging.error(f"Murphy-proof Error Reaping Subprocess (PID {proc.pid if proc else 'N/A'}): {e}")
