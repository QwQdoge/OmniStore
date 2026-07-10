mkdir -p .Jules
cat << 'MD' >> .Jules/sentinel.md
## $(date +%Y-%m-%d) - [Zombie Process Leak on Async Cancellation]

Learning:
In Python 3.8+, `asyncio.CancelledError` inherits from `BaseException` rather than `Exception`. Therefore, error handling blocks catching `Exception` will be bypassed during task cancellation. If a process is being reaped inside an `asyncio.wait_for(...)` block and the task is cancelled, the standard timeout/exception block is skipped, skipping the escalation to `SIGKILL` and leaving zombie processes if the process ignored `SIGTERM`.

Action:
Modified `safe_subprocess` in `python/core/subprocess_utils.py` and `OmnistoreBackend` in `python/core/backend.py` to explicitly catch `BaseException` during shutdown/reaping blocks. Used `asyncio.shield` to protect the final `wait()` from the same cancellation event. Re-raised `BaseException` (like `CancelledError`) after completing the necessary zombie cleanup to ensure standard async propagation.
MD
