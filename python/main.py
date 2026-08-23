import sys
import argparse
import logging
import asyncio
import json
import signal
from pathlib import Path
from rich.panel import Panel

# Path handling optimization
BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from core.backend import OmnistoreBackend, console, setup_stdout_hijack, hijacked_print
from core.daemon_server import handle_daemon_client, daemon_watchdog
from core.cli_handler import handle_cli
from core.friendly_messages import get_friendly_message
from core.logging_config import configure_logging
from core.apps_usage_export import SCHEMA, SCHEMA_VERSION, export_installed_usage

logger = logging.getLogger(__name__)

# Shared event for shutdown signaling
stop_event = asyncio.Event()


async def main():
    parser = argparse.ArgumentParser(description="Omnistore Backend")

    cmd = parser.add_mutually_exclusive_group()
    cmd.add_argument("-S", "--search")
    cmd.add_argument("-I", "--install")
    cmd.add_argument("-R", "--remove")
    cmd.add_argument("-U", "--update")
    cmd.add_argument("-C", "--check-updates", action="store_true")
    cmd.add_argument("-L", "--list-installed", action="store_true")
    cmd.add_argument("--recommend", action="store_true")
    cmd.add_argument("--details")
    cmd.add_argument("--clean-system", action="store_true")
    cmd.add_argument("--ai-summary", action="store_true")
    cmd.add_argument("--get-config", action="store_true")
    cmd.add_argument("--set-config")
    cmd.add_argument("--check-env", action="store_true")
    cmd.add_argument("--bootstrap", action="store_true")
    cmd.add_argument("--list-custom-repos", action="store_true")
    cmd.add_argument("--list-plugins", action="store_true")
    cmd.add_argument("--set-plugin-enabled")
    cmd.add_argument("--remove-plugin")
    cmd.add_argument("--add-custom-repo")
    cmd.add_argument("--remove-custom-repo")
    cmd.add_argument("--ai-explain")
    cmd.add_argument("--ai-recommend")
    cmd.add_argument("--ai-analyze-error")
    cmd.add_argument("--ai-compare")
    cmd.add_argument("--ai-health", action="store_true")
    cmd.add_argument("--ai-test", action="store_true")
    cmd.add_argument("--ai-pick", action="store_true")
    cmd.add_argument("--ai-correct")
    cmd.add_argument("--ai-changelog")
    cmd.add_argument("--ai-cli")
    cmd.add_argument("--ai-conflicts")
    cmd.add_argument("--essentials", action="store_true")
    cmd.add_argument("--import-packages")
    cmd.add_argument("--export-packages")
    cmd.add_argument("--launch")
    cmd.add_argument("--locate")
    cmd.add_argument("--daemon", action="store_true")
    cmd.add_argument("--storage-info", action="store_true")
    cmd.add_argument("--export-installed-usage", action="store_true")

    parser.add_argument("--json", action="store_true")
    parser.add_argument("--source", default="AUR")
    parser.add_argument("--url")
    parser.add_argument("--ai-desc")
    parser.add_argument("--force-refresh", action="store_true")

    args = parser.parse_args()

    # The cross-application export is intentionally always machine-readable:
    # Meo Settings must never parse Rich UI output or daemon traffic.
    json_mode = args.json or args.export_installed_usage
    setattr(hijacked_print, "json_mode_active", json_mode)
    setup_stdout_hijack()

    backend = OmnistoreBackend(json_mode=json_mode, emit_stdout=not args.daemon)
    configure_logging(
        backend.config.get("logging.level", "INFO"),
        json_mode=json_mode,
        component="omnistore.backend",
    )

    if args.export_installed_usage:
        try:
            snapshot = await export_installed_usage(backend)
        except Exception:
            # Do not expose filesystem paths, backend diagnostics, credentials,
            # or arbitrary plugin output through this cross-application ABI.
            failure = {
                "schema": SCHEMA,
                "version": SCHEMA_VERSION,
                "status": "error",
                "error": "installed_usage_unavailable",
            }
            sys.stdout.write(json.dumps(failure, ensure_ascii=False) + "\n")
            sys.stdout.flush()
            raise SystemExit(1)
        sys.stdout.write(json.dumps(snapshot, ensure_ascii=False) + "\n")
        sys.stdout.flush()
        return

    if not json_mode:
        console.print(
            Panel.fit(
                f"[bold blue]OmniStore[/bold blue] v0.1.0\n"
                f"[dim]{get_friendly_message()}[/dim]",
                border_style="blue",
            )
        )
        if not sys.platform.startswith("linux"):
            console.print(
                "[bold yellow]Warning: OmniStore is optimized for Linux (Arch).[/bold yellow]"
            )

    # Register signal handlers for graceful shutdown.
    loop = asyncio.get_running_loop()

    def _shutdown(sig_name: str):
        logger.info("Received exit signal %s. Shutting down...", sig_name)
        stop_event.set()

        # Do not touch the lazy `backend.executor` property here: constructing
        # a new executor while the process is shutting down creates resources at
        # exactly the wrong time.
        executor = getattr(backend, "_executor", None)
        if executor is not None:
            try:
                executor.stop()
            except Exception:
                logger.exception("Failed to stop install executor during shutdown")

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, lambda s=sig: _shutdown(s.name))
        except NotImplementedError:
            logger.debug("Signal handlers are not supported on this event loop")

    # Try handling as CLI command first.
    executed = await handle_cli(backend, args)
    if executed:
        return

    if args.daemon:
        try:
            async with backend:
                server = await asyncio.start_server(
                    lambda r, w: handle_daemon_client(backend, r, w, stop_event),
                    "127.0.0.1",
                    9081,
                    limit=512 * 1024,
                )
                logger.info("Python daemon started on 127.0.0.1:9081")

                async with server:
                    watchdog_task = asyncio.create_task(
                        daemon_watchdog(stop_event),
                        name="omnistore-daemon-watchdog",
                    )
                    serve_task = asyncio.create_task(
                        server.serve_forever(),
                        name="omnistore-daemon-server",
                    )
                    wait_task = asyncio.create_task(
                        stop_event.wait(),
                        name="omnistore-daemon-stop-event",
                    )

                    done, pending = await asyncio.wait(
                        [serve_task, wait_task, watchdog_task],
                        return_when=asyncio.FIRST_COMPLETED,
                    )

                    # Surface unexpected task failures instead of silently
                    # continuing with a half-dead daemon.
                    for task in done:
                        if task is wait_task or task.cancelled():
                            continue
                        exc = task.exception()
                        if exc is not None:
                            raise exc

                    for task in pending:
                        task.cancel()
                    if pending:
                        await asyncio.gather(*pending, return_exceptions=True)

                    logger.info("Stopping daemon server...")
        except Exception as exc:
            logger.exception("Daemon fatal error")
            await backend._handle_error("Daemon Fatal Error", exc, json_mode)
            raise SystemExit(1) from exc
    elif not any(vars(args).values()):
        parser.print_help()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
    except SystemExit:
        raise
    except Exception:
        logger.exception("OmniStore backend crashed")
        sys.exit(1)
