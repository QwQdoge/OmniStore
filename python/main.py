import sys
import argparse
import logging
import asyncio
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

# Shared event for shutdown signaling
stop_event = asyncio.Event()

def setup_logging(level="INFO", json_mode=False):
    log_level = getattr(logging, level.upper(), logging.INFO)
    if json_mode:
        logging.basicConfig(
            level=log_level,
            format="%(message)s",
            handlers=[logging.StreamHandler(sys.stderr)]
        )
    else:
        from rich.logging import RichHandler
        logging.basicConfig(
            level=log_level,
            format="%(message)s",
            datefmt="[%X]",
            handlers=[RichHandler(console=console, rich_tracebacks=True)]
        )

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

    parser.add_argument("--json", action="store_true")
    parser.add_argument("--source", default="AUR")
    parser.add_argument("--url")
    parser.add_argument("--ai-desc")
    parser.add_argument("--force-refresh", action="store_true")

    args = parser.parse_args()

    json_mode = args.json
    setattr(hijacked_print, "json_mode_active", json_mode)
    setup_stdout_hijack()

    backend = OmnistoreBackend(json_mode=json_mode)
    setup_logging(backend.config.get("logging.level", "INFO"), json_mode)

    if not json_mode:
        console.print(Panel.fit(f"[bold blue]OmniStore[/bold blue] v0.1.0\n[dim]{get_friendly_message()}[/dim]", border_style="blue"))
        if not sys.platform.startswith("linux"):
            console.print("[bold yellow]Warning: OmniStore is optimized for Linux (Arch).[/bold yellow]")

    # Register signal handlers for graceful shutdown
    loop = asyncio.get_running_loop()
    def _shutdown(sig_name):
        logging.info(f"Received exit signal {sig_name}. Shutting down...")
        stop_event.set()
        if backend.executor:
            backend.executor.stop()

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, lambda s=sig: _shutdown(s.name))
        except NotImplementedError: pass

    # Try handling as CLI command first
    executed = await handle_cli(backend, args)
    if executed:
        return

    # If not a CLI command, check if it's daemon mode
    if args.daemon:
        try:
            async with backend:
                server = await asyncio.start_server(
                    lambda r, w: handle_daemon_client(backend, r, w, stop_event),
                    '127.0.0.1', 9081,
                    limit=512 * 1024
                )
                logging.info("Python daemon started on 127.0.0.1:9081")
                async with server:
                    watchdog_task = asyncio.create_task(daemon_watchdog(stop_event))
                    serve_task = asyncio.create_task(server.serve_forever())
                    wait_task = asyncio.create_task(stop_event.wait())

                    done, pending = await asyncio.wait(
                        [serve_task, wait_task, watchdog_task],
                        return_when=asyncio.FIRST_COMPLETED
                    )
                    for task in pending: task.cancel()
                    logging.info("Stopping daemon server...")
        except Exception as e:
            await backend._handle_error("Daemon Fatal Error", e, json_mode)
            sys.exit(1)
    else:
        if not any(vars(args).values()):
            parser.print_help()

if __name__ == "__main__":
    try: asyncio.run(main())
    except KeyboardInterrupt: pass
    except Exception:
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
