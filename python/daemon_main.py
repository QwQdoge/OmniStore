import os
import sys
import json
import yaml
import asyncio
import subprocess
import logging
from pathlib import Path
from datetime import datetime, timezone

from core.subprocess_utils import safe_subprocess

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="[Daemon] %(asctime)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)

def get_config_path() -> Path:
    home = Path(os.environ.get("HOME", "/"))
    return home / ".config" / "omnistore" / "config.yaml"

def get_status_path() -> Path:
    home = Path(os.environ.get("HOME", "/"))
    return home / ".config" / "omnistore" / "update_status.json"

def load_config():
    config_path = get_config_path()
    defaults = {
        "enabled": True,
        "check_interval_hours": 4,
        "auto_update": False,
        "notifications": True
    }
    
    if not config_path.exists():
        return defaults

    try:
        with open(config_path, "r", encoding="utf-8") as f:
            cfg = yaml.safe_load(f) or {}
            daemon_cfg = cfg.get("daemon", {})
            return {
                "enabled": daemon_cfg.get("enabled", True),
                "check_interval_hours": daemon_cfg.get("check_interval_hours", 4),
                "auto_update": daemon_cfg.get("auto_update", False),
                "notifications": daemon_cfg.get("notifications", True)
            }
    except Exception as e:
        logging.error(f"Failed to load/parse config, falling back to defaults: {e}")
        return defaults

def send_notification(summary: str, body: str):
    logging.info(f"Sending notification: {summary} - {body}")
    try:
        # Use notify-send which is standard on Linux desktops
        subprocess.run(
            ["notify-send", "-a", "OmniStore", "-t", "5000", summary, body],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception as e:
        logging.error(f"Failed to send notification via notify-send: {e}")

def get_python_cmd():
    # If packaged via PyInstaller, sys.executable is the packaged binary (omnistore-daemon)
    # The parent directory of it is the 'backends' folder, containing 'python_server'
    exe_dir = Path(sys.executable).parent
    python_server = exe_dir / "python_server"
    if python_server.exists():
        return [str(python_server)]

    # Development fallback
    current_dir = Path(__file__).resolve().parent
    script_path = current_dir / "main.py"
    venv_python = current_dir / ".venv" / "bin" / "python"
    
    if venv_python.exists():
        return [str(venv_python), str(script_path)]
    return ["python3", str(script_path)]

async def run_auto_updates(updates):
    logging.info("Auto-update is enabled. Starting updates...")
    
    has_flatpaks = any(u.get("source") == "Flatpak" for u in updates)
    if has_flatpaks:
        logging.info("Auto-updating Flatpak applications...")
        try:
            async with safe_subprocess(
                "flatpak", "update", "-y", "--user",
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            ) as proc:
                await proc.wait()
        except Exception as e:
            logging.error(f"Flatpak auto-update failed: {e}")

    # Check if running as root for native package updates
    try:
        is_root = os.getuid() == 0
    except AttributeError:
        is_root = False

    if is_root:
        has_natives = any(u.get("source") in ("Native", "AUR") for u in updates)
        if has_natives:
            logging.info("Running as root. Auto-updating native packages...")
            try:
                async with safe_subprocess(
                    "pacman", "-Syu", "--noconfirm",
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                ) as proc:
                    await proc.wait()
            except Exception as e:
                logging.error(f"Pacman auto-update failed: {e}")
    else:
        logging.info("Not running as root. Skipping native pacman/aur auto-updates.")

async def run_update_check(config):
    logging.info("Running update check...")
    cmd = get_python_cmd()
    cmd_args = cmd + ["-C", "--json"]
    
    try:
        async with safe_subprocess(
            *cmd_args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        ) as proc:
            stdout, stderr = await proc.communicate()
        
        if proc.returncode == 0:
            try:
                updates = json.loads(stdout.decode().strip())
                count = len(updates)
                logging.info(f"Found {count} updates")

                status = {
                    "last_checked": datetime.now(timezone.utc).isoformat(),
                    "updates_count": count,
                    "updates": updates
                }

                status_path = get_status_path()
                status_path.parent.mkdir(parents=True, exist_ok=True)
                with open(status_path, "w", encoding="utf-8") as f:
                    json.dump(status, f, indent=2)

                if count > 0 and config.get("notifications"):
                    msg = f"您有 {count} 个可用的软件更新项目，点击进入商店查看并更新。"
                    send_notification("OmniStore 软件更新提示", msg)

                if count > 0 and config.get("auto_update"):
                    await run_auto_updates(updates)

            except Exception as e:
                logging.error(f"Failed to parse update check JSON or write status: {e}")
        else:
            logging.error(f"Update check failed with code {proc.returncode}: {stderr.decode()}")
    except Exception as e:
        logging.error(f"Failed to execute update check: {e}")

async def main():
    logging.info("====================================================")
    logging.info("       OmniStore Background Daemon Starting         ")
    logging.info("====================================================")

    config = load_config()
    if not config.get("enabled"):
        logging.info("Daemon is disabled in configuration. Exiting.")
        return

    logging.info("Running initial update check...")
    await run_update_check(config)

    logging.info(f"Starting background loop. Checking every {config['check_interval_hours']} hour(s).")
    
    try:
        while True:
            # Sleep in 60s chunks so we can check for shutdown or config reload/disabled sooner
            sleep_hours = config.get("check_interval_hours", 4)
            sleep_seconds = sleep_hours * 3600
            elapsed = 0
            
            while elapsed < sleep_seconds:
                await asyncio.sleep(60)
                elapsed += 60
                # Check config dynamically to see if daemon got disabled
                current_config = load_config()
                if not current_config.get("enabled"):
                    logging.info("Daemon was disabled in configuration. Stopping.")
                    return
                # If interval decreased, adjust sleep
                new_sleep_hours = current_config.get("check_interval_hours", 4)
                if new_sleep_hours != sleep_hours:
                    logging.info(f"Interval changed from {sleep_hours} to {new_sleep_hours} hour(s). Re-adjusting timer.")
                    config = current_config
                    break
            else:
                # Timer completed naturally
                config = load_config()
                if not config.get("enabled"):
                    logging.info("Daemon was disabled in configuration. Stopping.")
                    return
                await run_update_check(config)
    except asyncio.CancelledError:
        logging.info("Background loop cancelled.")

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logging.info("Daemon stopped via KeyboardInterrupt.")
