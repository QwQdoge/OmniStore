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

## 2024-06-15 - [AuthPage Memory Leak & Async Crash]

Learning:
Missing `dispose()` calls for `TextEditingController` instances cause memory leaks. Additionally, accessing a controller's state (like `.text`) after an `await` without verifying `if (!mounted)` can result in unhandled exceptions and real-world application crashes if the user navigates away or dismisses the UI before the asynchronous operation completes, because the controller could have been disposed.

Action:
Added a missing `dispose()` method for `_patController` in `AuthPage` (`FlutterUI/lib/features/auth/auth_page.dart`). Also added an explicit `if (!mounted) return;` check following the asynchronous `configRepo.loadConfig()` call in `_savePat()` to prevent accessing `_patController.text` after the widget has been unmounted.

## 2026-06-15 - [Daemon Async Subprocess Leaks]

Learning:
Like other parts of the backend, the resident daemon in `python/daemon_main.py` directly used `asyncio.create_subprocess_exec` for background auto-updates and check operations. This could lead to zombie processes if the event loop is cancelled or encounters an unexpected exception.

Action:
Refactored `python/daemon_main.py` to use the centralized `safe_subprocess` context manager from `core.subprocess_utils` for all asynchronous process executions. This guarantees that auto-update and update-check subprocesses are gracefully terminated and awaited if their coroutine fails or is cancelled, preventing process leaks.

## 2025-02-28 - [Async Lifecycle Safety]

Learning:
Missing `mounted` checks after `await` gaps can lead to real-world crashes when `context.read` or `setState` is called on an unmounted widget. Found violations in `home_page.dart` (`_fetchAIPick` invocation inside `_refresh`) and `settings_page.dart` (`_fetchStorageInfo` invocation after system cleanup).

Action:
Added strict `if (!mounted) return;` statements after async operations in `_refresh` and `_triggerCleanup` to safely terminate the execution paths and prevent unsafe `BuildContext` usage. Automated static analysis scripts should continue to monitor these async gaps.

## 2026-06-15 - [Async Lifecycle Context and State Safety Hardening]

Learning:
Unmounted widgets are highly vulnerable to crashes when context.read or setState is called after an await gap. During settings refactoring and homepage updates, missing checks on widgets' mounting status could trigger unhandled exceptions if the view was disposed while a cleanup task or background AI pick fetch was pending.

Action:
Added strict `if (!mounted) return;` checks to `HomePage._fetchAIPick` in `home_page.dart` (before reading context) and to `_StorageCleanupCardState._triggerCleanup` in `storage_cleanup_card.dart` (after awaiting the cleanup system task) to prevent asynchronous state operation crashes.

## 2024-06-16 - [Async Lifecycle State Safety in Dialogs]

Learning:
When launching asynchronous operations inside dialog or bottom sheet callbacks (such as `_showAddSourceDialog` in `sources_config_card.dart`), it is critical to verify if the underlying widget is still mounted before attempting to show a `SnackBar` or modify state. Caching `ScaffoldMessenger.of(context)` prior to an `await` does not guarantee the view remains intact by the time the operation completes. Accessing unmounted views this way can lead to crashes if the app transitions or exits during the async gap.

Action:
Added an explicit `if (!mounted) return;` check immediately before `messenger.showSnackBar` in the `_showAddSourceDialog` callback within `FlutterUI/lib/features/settings/presentation/widgets/sources_config_card.dart` to prevent lifecycle crashes.

## 2026-06-25 - [Async Lifecycle Hardening across Feature Pages]

Learning:
Extensive audit revealed several asynchronous gaps where  or  was accessed after an `await` without verifying `mounted` status. This is particularly dangerous in high-traffic areas like `MainNavigationEntry`, `AppDetailsPage`, and the various store pages where a user might navigate away while a network request is pending.

Action:
Implemented strict `if (!mounted) return;` guards immediately following `await` calls in `MainNavigationEntry`, `AppDetailsPage`, `HomePage`, `GitHubStorePage`, `FlatpakStorePage`, and `DownloadPage`. This proactively prevents "setState() called after dispose()" and "use of BuildContext across async gaps" errors, ensuring application stability during rapid navigation or background updates.

## 2026-06-25 - [Async Lifecycle Hardening across Feature Pages]

Learning:
Extensive audit revealed several asynchronous gaps where `setState` or `BuildContext` was accessed after an `await` without verifying `mounted` status. This is particularly dangerous in high-traffic areas like `MainNavigationEntry`, `AppDetailsPage`, and the various store pages where a user might navigate away while a network request is pending.

Action:
Implemented strict `if (!mounted) return;` guards immediately following `await` calls in `MainNavigationEntry`, `AppDetailsPage`, `HomePage`, `GitHubStorePage`, `FlatpakStorePage`, and `DownloadPage`. This proactively prevents "setState() called after dispose()" and "use of BuildContext across async gaps" errors, ensuring application stability during rapid navigation or background updates.

## 2026-06-25 - [Atomic File Write Hardening]

Learning:
Writing directly to JSON configuration or cache files (`daemon_main.py`, `cache_manager.py`, `recommendation_manager.py`, `habit_tracker.py`) using `with open(..., "w")` creates a vulnerability where a crash or power failure mid-write can corrupt the file. This can lead to JSON decoding errors and application instability upon subsequent reads.

Action:
Replaced direct writes with atomic writes across the Python backend. The data is now written to a temporary `.tmp` file first, which is then swapped with the target file using `os.replace()` (or `.replace()` on `Path` objects). This guarantees that configuration and state files are never left in a partially written, corrupt state.

## 2024-06-27 - [Provider Anti-pattern: Missing Imports Fix]

Learning:
Unused and duplicated methods can lead to hidden warnings or broken code logic. And removing those shouldn't be done arbitrarily without replacing the relevant imports. The lack of standard tools usage can introduce bugs in the codebase.

Action:
Ensure necessary dependencies and imports are handled correctly before doing cleanup on dead functions and dead UI elements.

## 2026-06-25 - [Atomic File Write Hardening in Plugins and Tests]

Learning:
Non-atomic file writes `with open(..., "w")` leave the application vulnerable to state corruption if a crash occurs mid-write. This applies broadly, even to test mocks and localized operations like AppImage `.desktop` entry generation.

Action:
Updated `_create_desktop_entry` in `python/core/sources/appimage/appimage.py` and file operations in `test_cache_manager.py` and `test_essentials.py` to utilize `.tmp` files with atomic `replace` operations.

## 2026-06-25 - [Async Lifecycle Context and State Safety Hardening in Main Navigation]

Learning:
Extensive audit revealed asynchronous gaps where `context` was accessed after an `await` without verifying `mounted` status in less obvious paths, such as utility shutdown sequences invoked by window closure events.

Action:
Implemented a strict `if (!mounted) return;` guard immediately at the beginning of `_handleFullExit` in `FlutterUI/lib/app/main_navigation.dart`, which is invoked after asynchronous gaps during window shutdown (`onWindowClose`). This proactively prevents "use of BuildContext across async gaps" errors.

## 2026-07-08 - [Exit Flow Async Lifecycle Tail Guard]

Learning:
Even after capturing services before shutdown awaits, the final window-manager calls in `_handleFullExit` still execute after multiple async gaps. If the widget is unmounted during backend cleanup, calling window APIs from the stale lifecycle path can create hard-to-reproduce shutdown crashes.

Action:
Added a final `if (!mounted) return;` guard immediately before `windowManager.setPreventClose(false)` and `windowManager.close()` in `FlutterUI/lib/app/main_navigation.dart`. Rechecked nearby home and storage cleanup paths; they already had the mounted guards recommended by the audit.
## 2026-07-18 - [Zombie Process Leak on Async Cancellation]

Learning:
In Python 3.8+, `asyncio.CancelledError` inherits from `BaseException` rather than `Exception`. Therefore, error handling blocks catching `Exception` will be bypassed during task cancellation. If a process is being reaped inside an `asyncio.wait_for(...)` block and the task is cancelled, the standard timeout/exception block is skipped, skipping the escalation to `SIGKILL` and leaving zombie processes if the process ignored `SIGTERM`.

Action:
Modified `safe_subprocess` in `python/core/subprocess_utils.py` and `OmnistoreBackend` in `python/core/backend.py` to explicitly catch `BaseException` during shutdown/reaping blocks. Used `asyncio.shield` to protect the final `wait()` from the same cancellation event. Re-raised `BaseException` (like `CancelledError`) after completing the necessary zombie cleanup to ensure standard async propagation.

## 2026-07-11 - [Zombie Process Leak on Async Cancellation - Fix Refinement]

Learning:
When modifying `except Exception:` to `except BaseException:` to catch `asyncio.CancelledError`, care must be taken not to blindly suppress cancellation entirely or trigger false-positive critical logs when cancellation is standard behavior. The inner `try-except` blocks within `safe_subprocess` should only catch and swallow specific errors like `TimeoutError`, rather than broadly silencing `BaseException` which breaks asyncio cancellation flows.

Action:
Refined exception handling in `_cleanup_proc` within `python/core/subprocess_utils.py` and `OmnistoreBackend.__aexit__` in `python/core/backend.py` to properly re-raise `BaseException` variants (like `CancelledError` or `KeyboardInterrupt`) without logging them as critical errors, and ensured inner `try-except` blocks don't swallow `BaseException`. Used `asyncio.shield` correctly to allow the cancellation cleanup sequence to run without leaving zombies, while maintaining the correct propagation of `asyncio.CancelledError`.

## 2026-07-12 - [Zombie Process Leak on Async Cancellation - Fix Refinement]

Learning:
When modifying `except Exception:` to `except BaseException:` to catch `asyncio.CancelledError`, care must be taken not to blindly suppress cancellation entirely or trigger false-positive critical logs when cancellation is standard behavior. The inner `try-except` blocks within `safe_subprocess` should only catch and swallow specific errors like `TimeoutError`, rather than broadly silencing `BaseException` which breaks asyncio cancellation flows.

Action:
Refined exception handling in `_cleanup_proc` within `python/core/subprocess_utils.py` and `OmnistoreBackend.__aexit__` in `python/core/backend.py` to properly re-raise `BaseException` variants (like `CancelledError` or `KeyboardInterrupt`) without logging them as critical errors, and ensured inner `try-except` blocks don't swallow `BaseException`. Used `asyncio.shield` correctly to allow the cancellation cleanup sequence to run without leaving zombies, while maintaining the correct propagation of `asyncio.CancelledError`.
## 2026-07-18 - [Zombie Process Leak on Async Cancellation - Fix Refinement]

Learning:
When catching `BaseException` to properly handle `asyncio.CancelledError` during subprocess cleanup, it is critical not to accidentally swallow the exception or skip subsequent cleanup steps. In `_cleanup_proc`, a cancelled `wait_for` during stage 1 should not skip the stage 2 escalation (SIGKILL). In `OmnistoreBackend.__aexit__`, a cancelled AI session closure must not skip the final resource cleanup.

Action:
Refined exception handling in `_cleanup_proc` within `python/core/subprocess_utils.py` and `OmnistoreBackend.__aexit__` in `python/core/backend.py`. Used `asyncio.shield` correctly in `_cleanup_proc` stage 1 to allow the cancellation cleanup sequence to run without leaving zombies, and explicitly re-raised `_exc` if it's not a standard `Exception`. In `backend.py`, wrapped the AI session closure in a `try...finally` block to guarantee execution of `await asyncio.shield(self._resources.cleanup())` even if the former is cancelled, maintaining the correct propagation of `asyncio.CancelledError`.

## 2026-07-20 - [Daemon Process Tracking and Context-Aware API Parameter Validation]

Learning:
Blindly validating string arguments in APIs (e.g. `safe_command`) as generic strings can restrict valid Windows paths or query URLs while also missing path traversal checks. It is critical to use `inspect.signature` to map both positional and keyword arguments to their parameter names, and then apply targeted validators (`validate_url`, `validate_path`, `validate_search_query`) recursively. In background daemons, missing pre-checks on optional system binaries (like `notify-send`) can cause FileNotFoundError, and failing to track subprocesses and tasks globally can result in zombie/orphaned processes upon daemon shutdown.

Action:
Refined `safe_command` in `python/core/backend.py` to use `inspect.signature` for context-aware string validation and recursive validation of nested parameters. Refined `python/daemon_main.py` by importing `shutil`, fixing undefined notification variables, implementing an `asyncio.Lock` for update checks, sanitizing configuration variables dynamically, and adding robust task and subprocess tracking to terminate all resources on exit.
## 2026-07-25 - [Async Lifecycle Crashes in Dialogs]

Learning:
Missing `if (!mounted) return;` checks after awaiting futures before accessing state, widget properties or BuildContext can lead to crashes if the widget is disposed before the future resolves. However, adding these checks at the very end of a function (where no further state is accessed) is unnecessary and violates the directive against "theoretical paranoia fixes". Adding them before vital cleanup tasks (like window closing/exiting) can cause regressions where cleanup is skipped entirely if the widget unmounts.

Action:
Only ensure that async gaps in StatefulWidgets are immediately followed by `if (!mounted) return;` checks *when* they are followed by mutating state or accessing the context. Added a missing `if (!mounted) return;` check before using `ScaffoldMessenger.of(context)` in `add_source_dialog.dart` to prevent potential lifecycle crashes when adding a custom source.

## 2026-07-26 - [Exit Flow Async Lifecycle Tail Guard Refinement]

Learning:
Adding `if (!mounted) return;` at the very end of a function or right before vital cleanup tasks (like window closing/exiting) can cause regressions where cleanup is skipped entirely if the widget unmounts. This is an unnecessary "paranoia fix". Async gaps should only be followed by `mounted` checks when mutating state or accessing the context.

Action:
Removed the unnecessary `if (!mounted) return;` guard immediately before `windowManager.setPreventClose(false)` and `windowManager.close()` in `_handleFullExit` within `FlutterUI/lib/app/main_navigation.dart`. This ensures that final window destruction and exit commands are executed even if the widget unmounts during the backend shutdown awaits.
## 2026-08-04 - [Async Lifecycle Crashes in Onboarding]

Learning:
Extensive audit revealed asynchronous gaps where state (`setState`) or context (`widget`) was accessed after an `await` without verifying `mounted` status in `FlutterUI/lib/features/onboarding/welcome_page.dart`. This is a classic async lifecycle violation that can result in errors if the onboarding screen is navigated away from or disposed before the async operations (e.g. backend checking, AI connection testing) complete. Care must also be taken within `finally` blocks to use `if (mounted)` rather than `if (!mounted) return;` so that the method doesn't exit prematurely or silently swallow other cleanup code, although `mounted` checks should still be applied.

Action:
Implemented a strict `if (!mounted) return;` guard immediately before `setState` in `_checkEnvironment` and `_testAIConnection` (including `try`, `catch` and an `if (mounted)` within `finally`). Added a `if (!mounted) return;` guard before `widget.onFinish()` in `_finishOnboarding`.
## 2026-08-06 - [Zombie Process Leak on Async Cancellation - Fix Refinement 3]

Learning:
While adding a background task to a set (`self._background_tasks.add(task)`) correctly holds a strong reference, the standard `task.add_done_callback(self._background_tasks.discard)` approach breaks if `task` is added *after* execution has started (or if it's already done). Also, ensuring resource cleanup doesn't get cancelled by putting it inside `_background_tasks` ensures it runs to completion even if the main block is cancelled.

Action:
Modified `OmnistoreBackend.__aexit__` in `python/core/backend.py` to correctly track `cleanup_task` by adding it to `self._background_tasks` and registering the `discard` callback before awaiting it. This ensures it retains a strong reference during cancellation unwinding.

## 2026-08-07 - [Zombie Process Leak on Async Cancellation - Fix Refinement 2]

Learning:
While explicitly creating tasks and shielding them (`asyncio.shield(task)`) correctly prevents the task from being destroyed mid-execution *during* a timeout catch block, it fails to protect the task if the outer function exits entirely (e.g. from an `asyncio.CancelledError` unwinding the stack). Because local variables go out of scope, the tasks lose their strong references and are still garbage-collected. To ensure true async lifecycle safety for background shielded tasks, a strong reference must be maintained in a persistent collection (e.g. a class-level `set` or a global module-level `set`) until completion.

Action:
Modified `OmnistoreBackend` in `python/core/backend.py` to add `self._background_tasks = set()`. Replaced shielded AI closure calls with explicit tasks that are added to this set and discard themselves on completion via `add_done_callback`. Applied the same fix in `python/core/subprocess_utils.py`, adding a global `_background_tasks = set()` to persist the subprocess `wait()` tasks if `_cleanup_proc` is cancelled.

## 2026-08-10 - [Async Lifecycle Crashes in Onboarding Callbacks]

Learning:
Extensive audit revealed asynchronous gaps where state (`setState`) was accessed without verifying `mounted` status inside asynchronous stream callbacks (like `onError` and `onDone` in `_startBootstrap`) and inside `catch` blocks in `FlutterUI/lib/features/onboarding/welcome_page.dart`. While standard `await` gaps had guards, these alternative asynchronous paths are equally vulnerable to lifecycle violations if the user navigates away or closes the app during the onboarding setup.

Action:
Implemented strict `if (!mounted) return;` guards immediately before `setState` in all `catch` blocks and stream listener callbacks (`onError`, `onDone`, and custom line parsers) in `WelcomePage` to prevent "setState() called after dispose()" crashes.

## 2026-08-18 - [AppImageSearch ThreadPoolExecutor Leak]

Learning:
Custom `ThreadPoolExecutor` instances attached to class instances (like `AppImageSearch`) will leak threads if they are never explicitly `.shutdown()` when the class instance is destroyed or the application exits. For simple, one-off synchronous disk reads during an async search flow, it is safer and more efficient to use the default `asyncio` event loop executor (`loop.run_in_executor(None, ...)`) which is automatically managed by the event loop's lifecycle.

Action:
Removed the custom `ThreadPoolExecutor(max_workers=2)` from `AppImageSearch` in `python/core/search/appimage.py`. Refactored `search()` to use `loop.run_in_executor(None, self.get_installed_appimages)` so that the default executor is used, preventing potential resource leaks on backend restart or shutdown.
