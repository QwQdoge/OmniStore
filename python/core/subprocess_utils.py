import asyncio
import logging
import contextlib

@contextlib.asynccontextmanager
async def safe_subprocess(*args, **kwargs):
    """Murphy-proof subprocess wrapper that guarantees absolute cleanup and reaping."""
    proc = None
    try:
        proc = await asyncio.create_subprocess_exec(*args, **kwargs)
        yield proc
    finally:
        if proc:
            try:
                if proc.returncode is None:
                    # Attempt graceful termination (SIGTERM)
                    proc.terminate()
                    try:
                        await asyncio.wait_for(proc.wait(), timeout=3)
                    except asyncio.TimeoutError:
                        # Escalation: Force kill (SIGKILL)
                        proc.kill()
                        await proc.wait()
            except Exception as e:
                logging.error(f"Murphy-proof Error Reaping Subprocess: {e}")
