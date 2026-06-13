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

## 2024-06-10 - [Subprocess Zombie Process Prevention]

Learning:
Unmanaged asyncio subprocesses can become zombies if coroutines are cancelled or raise exceptions. Using direct `asyncio.create_subprocess_exec` inside try/finally blocks is error-prone due to repetitive, often incorrect or redundant reaping logic scattered throughout the codebase.

Action:
Refactored and unified asynchronous process execution using the `safe_subprocess` async context manager across Flatpak, Pacman, and AUR backend sources. Removed redundant manual `proc.kill()` blocks to rely on `safe_subprocess`'s multi-stage reaping (SIGTERM -> 3s wait -> SIGKILL). Ensured that `asyncio.create_subprocess_exec` is never called directly without context management.

## 2025-02-27 - [Async Lifecycle Context Safety]

Learning:
Accessing `widget` or `context` providers (or using them within deeply nested logic) after `await` calls in asynchronous gaps without checking `if (!mounted)` can result in unhandled exceptions and real-world application crashes if the user navigates away or dismisses the UI before the asynchronous operation completes. This is particularly prevalent in settings flows, dialog interactions, and onboarding screens.

Action:
I added explicit `if (!mounted) return;` checks following `await` instructions in both the Details Page (`details_page.dart`) after asynchronous security dialog responses, and the Onboarding Welcome Page (`welcome_page.dart`) following configuration initialization saves. This safely halts execution on unmounted views and prevents exceptions.
## 2024-06-13 - [UI Consistency Mandate / Sentinel Agent - Replaced TextField with SearchBar in Download Page]

Learning:
Custom styled TextFields inside feature pages cause UI fragmentation when a standard `SearchBar` MD3 component exists.

Action:
Replaced the `TextField` with inline decoration borders and fill color in `FlutterUI/lib/features/task_manager/presentation/pages/download_page.dart` with a `SearchBar`.

## 2026-06-13 - [Async Lifecycle State Safety]

Learning:
Accessing `setState` or `context` after an `await` gap (or inside listener callbacks that can trigger after disposal) without a `mounted` check leads to "setState() called after dispose()" errors and potential crashes. Standard window listener callbacks (`onWindowMaximize`, etc.) are particularly vulnerable as they are triggered by external OS events.

Action:
Added `if (!mounted) return;` guards to `HomePage._refresh`, `WindowTitleBar` window listener callbacks, and `AppDetailsPage._handleAction` following asynchronous dialogs.
