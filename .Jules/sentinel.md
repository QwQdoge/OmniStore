## YYYY-MM-DD - [Async Subprocess Process Leaks]

Learning:
When `asyncio.wait_for` timeouts, the `communicate()` coroutine is cancelled, but the underlying process continues running. Without a `finally` block to `kill()` and `wait()` for the process, it becomes a zombie.

Action:
Always use a `finally` block or context manager to ensure subprocesses are explicitly killed and awaited if their enclosing coroutines are cancelled or raise exceptions.
## 2026-06-09 - [Async Subprocess Process Leaks]

Learning:
Raw `asyncio.create_subprocess_exec` calls are prone to leaking zombie processes if the enclosing coroutine is cancelled or throws an exception before `.wait()` or `.communicate()` completes. Brittle string-replacement scripts for large-scale refactoring frequently introduce syntax/indentation errors and should be avoided or thoroughly verified with `py_compile`.

Action:
Created a centralized `safe_subprocess` async context manager in `core/subprocess_utils.py` that guarantees absolute cleanup (SIGTERM -> 3s wait -> SIGKILL) in its `finally` block. Refactored the entire Python backend to use this wrapper instead of raw `create_subprocess_exec`.
