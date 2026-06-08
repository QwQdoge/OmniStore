## YYYY-MM-DD - [Async Subprocess Process Leaks]

Learning:
When `asyncio.wait_for` timeouts, the `communicate()` coroutine is cancelled, but the underlying process continues running. Without a `finally` block to `kill()` and `wait()` for the process, it becomes a zombie.

Action:
Always use a `finally` block or context manager to ensure subprocesses are explicitly killed and awaited if their enclosing coroutines are cancelled or raise exceptions.
