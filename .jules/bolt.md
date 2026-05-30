## 2025-05-22 - [Optimizing Search Scoring and Merging]
**Learning:** Redundant regex compilation and repeated string normalization in a tight loop (e.g., processing hundreds of search results) are significant CPU bottlenecks in Python. Pre-compiling regexes and using simple dictionary-based caches for idempotent string operations can yield an 80% speedup in those hot paths.
**Action:** Always pre-compile regexes at the module level. Use instance-level or method-level caches for string normalization if the same strings are likely to be processed multiple times in a single session.

## 2025-05-30 - [Asynchronous Metadata Caching]
**Learning:** Performing synchronous disk I/O (like `json.dump`) inside an `async` function that is part of a concurrent `asyncio.gather` group can block the event loop and cause race conditions. Always use `run_in_executor` for blocking file operations and atomic replacement (`replace`) to ensure data integrity.
**Action:** Use `asyncio.get_event_loop().run_in_executor(None, sync_io_func)` for any persistence logic in async backends.
