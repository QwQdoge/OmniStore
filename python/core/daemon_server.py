import asyncio
import json
import logging
import io
import inspect
from pydantic import BaseModel, Field, field_validator, ValidationError
from core.backend import OmnistoreBackend, captured_output_var

class DaemonRequest(BaseModel):
    action: str = Field(..., min_length=1, max_length=100)
    args: list = Field(default_factory=list)
    kwargs: dict = Field(default_factory=dict)

    @field_validator("action")
    @classmethod
    def validate_action(cls, v):
        ALLOWED_ACTIONS = {
            "run_search", "run_install", "run_uninstall", "run_update",
            "run_check_updates", "run_recommendations", "run_app_details",
            "run_list_installed", "run_list_custom_repos", "run_add_custom_repo",
            "run_remove_custom_repo", "run_launch", "run_locate",
            "run_get_storage_info", "run_clean_system", "run_get_essentials",
            "run_import_packages", "run_export_packages", "run_ai_test",
            "run_ai_explain", "run_ai_recommend", "run_ai_analyze_error", "run_ai_pick",
            "run_ai_changelog", "run_ai_cli", "run_ai_conflicts", "run_ai_correct",
            "run_ai_compare", "run_ai_health",
            "run_update_env", "run_save_config", "config.data", "env.check_env", "shutdown"
        }
        if v not in ALLOWED_ACTIONS:
            raise ValueError(f"Forbidden Action: {v}")
        return v

async def handle_daemon_client(backend: OmnistoreBackend, reader: asyncio.StreamReader, writer: asyncio.StreamWriter, stop_event: asyncio.Event):
    """
    Murphy-proof daemon client handler.
    Ensures per-client isolation, payload limits, and robust error recovery.
    """
    client_addr = writer.get_extra_info('peername')
    logging.debug(f"New daemon client connected: {client_addr}")

    try:
        while True:
            try:
                line_bytes = await asyncio.wait_for(reader.readline(), timeout=300)
                if not line_bytes:
                    break

                line = line_bytes.decode('utf-8', errors='replace').strip()
                if not line:
                    continue

                try:
                    cmd_data = DaemonRequest.model_validate_json(line)
                except ValidationError as ve:
                    logging.error(f"Daemon Validation error from {client_addr}: {ve}")
                    writer.write(json.dumps({"status": "error", "error": f"Validation Failed: {ve.errors()[0]['msg']}"}).encode('utf-8') + b'\n')
                    await writer.drain()
                    continue
                except json.JSONDecodeError as je:
                    logging.error(f"Daemon JSON error from {client_addr}: {je}")
                    writer.write(json.dumps({"status": "error", "error": "Invalid JSON format"}).encode('utf-8') + b'\n')
                    await writer.drain()
                    continue
            except (asyncio.LimitOverrunError, ValueError):
                logging.error(f"Payload size limit exceeded from {client_addr}")
                writer.write(json.dumps({"status": "error", "error": "Payload size limit exceeded (max 512KB)"}).encode('utf-8') + b'\n')
                await writer.drain()
                break
            except asyncio.TimeoutError:
                logging.debug(f"Daemon client {client_addr} connection timed out")
                break
            except Exception as ex:
                logging.error(f"Unexpected daemon request error from {client_addr}: {ex}")
                try:
                    writer.write(json.dumps({"status": "error", "error": f"Protocol Violation: {str(ex)}"}).encode('utf-8') + b'\n')
                    await writer.drain()
                except: pass
                break

            captured_stdout = io.StringIO()
            token = captured_output_var.set(captured_stdout)

            try:
                action = cmd_data.action
                if action == "shutdown":
                    stop_event.set()
                    writer.write(json.dumps({"status": "success", "response": True}).encode('utf-8') + b'\n')
                    continue

                try:
                    async with backend:
                        args = cmd_data.args
                        kwargs = cmd_data.kwargs
                        obj = backend
                        parts = action.split('.')
                        for part in parts:
                            obj = getattr(obj, part, None)
                            if obj is None: break

                        if obj is not None:
                            try:
                                if callable(obj):
                                    if inspect.iscoroutinefunction(obj):
                                        res = await asyncio.wait_for(obj(*args, **kwargs), timeout=120)
                                    else:
                                        res = obj(*args, **kwargs)
                                else:
                                    res = obj

                                stdout_content = captured_stdout.getvalue()
                                response_payload = json.dumps({
                                    "status": "success",
                                    "response": res,
                                    "stdout": stdout_content
                                }, ensure_ascii=False).encode('utf-8') + b'\n'
                                writer.write(response_payload)
                            except asyncio.TimeoutError:
                                writer.write(json.dumps({"status": "error", "error": f"Action '{action}' timed out after 120s"}).encode('utf-8') + b'\n')
                            except Exception as action_e:
                                logging.error(f"Murphy-proof Action Exception [{action}]: {action_e}")
                                writer.write(json.dumps({
                                    "status": "error",
                                    "error": str(action_e),
                                    "stdout": captured_stdout.getvalue()
                                }).encode('utf-8') + b'\n')
                        else:
                            writer.write(json.dumps({"status": "error", "error": f"Method not found: {action}"}).encode('utf-8') + b'\n')
                except Exception as e:
                    import traceback
                    err_trace = traceback.format_exc()
                    logging.error(f"Daemon Action Logic Error [{action}]: {e}\n{err_trace}")
                    try:
                        writer.write(json.dumps({
                            "status": "error",
                            "error": str(e),
                            "stdout": captured_stdout.getvalue(),
                            "traceback": err_trace if backend.config.get("logging.level") == "DEBUG" else None
                        }).encode('utf-8') + b'\n')
                    except: pass
            finally:
                captured_output_var.reset(token)

            try:
                await writer.drain()
            except ConnectionError:
                break
    except asyncio.CancelledError:
        pass
    except Exception as e:
        logging.error(f"Daemon client handler fatal error: {e}")
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except: pass

async def daemon_watchdog(stop_event: asyncio.Event):
    """Murphy-proof watchdog that monitors the parent process."""
    import os
    import time
    parent_pid = os.getppid()
    if parent_pid == 1: return

    while not stop_event.is_set():
        try:
            os.kill(parent_pid, 0)
        except OSError:
            logging.error(f"Murphy-proof Watchdog: Parent process {parent_pid} vanished. Self-terminating...")
            stop_event.set()
            break
        await asyncio.sleep(10)
