import asyncio
import json
import logging
import io
import inspect
import os
from typing import Any
from pydantic import BaseModel, Field, field_validator, ValidationError
from core.backend import OmnistoreBackend, captured_output_var
from core.transaction_manager import TransactionManager


class PydanticEncoder(json.JSONEncoder):
    """Murphy-proof: JSON encoder that handles Pydantic models automatically."""
    def default(self, obj: Any) -> Any:
        if isinstance(obj, BaseModel):
            return obj.model_dump(exclude_none=True)
        return super().default(obj)


class DaemonRequest(BaseModel):
    action: str = Field(..., min_length=1, max_length=100)
    args: list = Field(default_factory=list)
    kwargs: dict = Field(default_factory=dict)

    @field_validator("args")
    @classmethod
    def validate_args(cls, v):
        if not isinstance(v, list):
            raise ValueError("args must be a list")
        if len(str(v)) > 50000:
            raise ValueError("args payload too large (max 50,000 characters)")
        return v

    @field_validator("kwargs")
    @classmethod
    def validate_kwargs(cls, v):
        if not isinstance(v, dict):
            raise ValueError("kwargs must be a dict")
        if len(str(v)) > 100000:
            raise ValueError("kwargs payload too large (max 100,000 characters)")
        return v

    @field_validator("action")
    @classmethod
    def validate_action(cls, v):
        # Package mutation entry points are intentionally absent here. A daemon
        # client must use transaction.plan + task.submit so ownership transfers
        # to TransactionManager before the client receives a response. The
        # standalone CLI can still call backend mutation commands explicitly.
        ALLOWED_ACTIONS = {
            "run_search", "run_check_updates", "run_recommendations", "run_app_details",
            "run_list_installed", "run_list_custom_repos", "run_add_custom_repo",
            "run_remove_custom_repo", "run_launch", "run_locate",
            "run_list_installed_sources", "run_list_plugins",
            "run_set_plugin_enabled", "run_remove_plugin",
            "run_get_storage_info", "run_clean_system", "run_get_essentials",
            "run_import_packages", "run_export_packages",
            "run_update_env", "run_save_config", "config.data", "run_check_env", "env.check_env",
            "transaction.plan", "task.submit", "task.get", "task.list",
            "ping", "shutdown"
        }
        if v not in ALLOWED_ACTIONS:
            raise ValueError(f"Forbidden Action: {v}")
        return v


def _transaction_manager_for(backend: OmnistoreBackend) -> TransactionManager:
    manager = getattr(backend, "_omnistore_transaction_manager", None)
    if manager is None:
        manager = TransactionManager(backend)
        setattr(backend, "_omnistore_transaction_manager", manager)
    return manager


def _task_id_from_request(cmd_data: DaemonRequest) -> str:
    if "task_id" in cmd_data.kwargs:
        return str(cmd_data.kwargs.get("task_id") or "").strip()
    if cmd_data.args:
        return str(cmd_data.args[0] or "").strip()
    return ""


async def handle_daemon_client(backend: OmnistoreBackend, reader: asyncio.StreamReader, writer: asyncio.StreamWriter, stop_event: asyncio.Event):
    """
    Murphy-proof daemon client handler.
    Ensures per-client isolation, payload limits, and robust error recovery.

    Package installs use transaction.plan followed by task.submit(plan_hash).
    Remove/update actions still use task.submit directly. Transaction ownership
    always transfers to TransactionManager before returning, so a disconnected
    UI does not implicitly cancel package work.
    """
    client_addr = writer.get_extra_info('peername')
    logging.debug(f"New daemon client connected: {client_addr}")
    transaction_manager = _transaction_manager_for(backend)

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
                try:
                    writer.write(json.dumps({"status": "error", "error": "Payload size limit exceeded (max 512KB)"}).encode('utf-8') + b'\n')
                    await writer.drain()
                except Exception:
                    pass
                break
            except asyncio.TimeoutError:
                logging.debug(f"Daemon client {client_addr} connection timed out")
                break
            except Exception as ex:
                logging.error(f"Unexpected daemon request error from {client_addr}: {ex}")
                try:
                    writer.write(json.dumps({"status": "error", "error": f"Protocol Violation: {str(ex)}"}).encode('utf-8') + b'\n')
                    await writer.drain()
                except Exception:
                    pass
                break

            captured_stdout = io.StringIO()
            token = captured_output_var.set(captured_stdout)

            try:
                async def execute_action():
                    action = cmd_data.action
                    if action == "ping":
                        return {
                            "status": "success",
                            "response": {
                                "protocol": 3,
                                "pid": os.getpid(),
                                "transactions": True,
                                "plans": True,
                            },
                        }
                    if action == "shutdown":
                        stop_event.set()
                        return {"status": "success", "response": True}

                    if action == "transaction.plan":
                        if cmd_data.args:
                            return {"status": "error", "error": "transaction.plan accepts keyword arguments only"}
                        kwargs = dict(cmd_data.kwargs)
                        kind = str(kwargs.pop("kind", "install") or "install").strip().lower()
                        if kind != "install":
                            return {"status": "error", "error": "unsupported_plan_kind"}
                        try:
                            plan = await transaction_manager.plan_install(**kwargs)
                        except (TypeError, ValueError) as exc:
                            return {"status": "error", "error": str(exc)}
                        return {"status": "success", "response": plan}

                    if action == "task.submit":
                        if cmd_data.args:
                            return {"status": "error", "error": "task.submit accepts keyword arguments only"}
                        kwargs = dict(cmd_data.kwargs)
                        plan_hash = str(kwargs.pop("plan_hash", "") or "").strip()
                        try:
                            if plan_hash:
                                if kwargs:
                                    return {"status": "error", "error": "planned task.submit accepts only plan_hash"}
                                task = transaction_manager.submit_planned(plan_hash)
                            else:
                                if str(kwargs.get("kind") or "").strip().lower() == "install":
                                    return {"status": "error", "error": "install_requires_reviewed_plan"}
                                task = transaction_manager.submit(**kwargs)
                        except (TypeError, ValueError) as exc:
                            return {"status": "error", "error": str(exc)}
                        return {"status": "success", "response": task}

                    if action == "task.get":
                        task_id = _task_id_from_request(cmd_data)
                        if not task_id:
                            return {"status": "error", "error": "missing_task_id"}
                        try:
                            task = transaction_manager.get(task_id)
                        except KeyError:
                            return {"status": "error", "error": "transaction_not_found"}
                        return {"status": "success", "response": task}

                    if action == "task.list":
                        if cmd_data.args or cmd_data.kwargs:
                            return {"status": "error", "error": "task.list accepts no arguments"}
                        return {"status": "success", "response": transaction_manager.list()}

                    # Protect normal backend calls with the established backend
                    # reference-counted context. The daemon's outer context keeps
                    # shared resources alive for persistent transaction tasks.
                    try:
                        async with backend:
                            args = cmd_data.args
                            kwargs = cmd_data.kwargs
                            obj = backend
                            parts = action.split('.')
                            for part in parts:
                                try:
                                    obj = getattr(obj, part, None)
                                except Exception as ge:
                                    return {"status": "error", "error": f"Attribute access error on '{part}': {str(ge)}"}
                                if obj is None:
                                    break

                            if obj is not None:
                                if callable(obj):
                                    try:
                                        if inspect.iscoroutinefunction(obj):
                                            res = await obj(*args, **kwargs)
                                        else:
                                            res = obj(*args, **kwargs)
                                    except TypeError as te:
                                        return {"status": "error", "error": f"Argument mismatch for '{action}': {str(te)}"}
                                else:
                                    res = obj

                                if isinstance(res, BaseModel):
                                    res = res.model_dump(exclude_none=True)
                                if isinstance(res, dict) and res.get("status") in {"success", "error"}:
                                    result = dict(res)
                                    result.setdefault("stdout", captured_stdout.getvalue())
                                    return result
                                return {"status": "success", "response": res,
                                        "stdout": captured_stdout.getvalue()}
                            return {"status": "error", "error": f"Method or attribute not found: {action}"}
                    except Exception as ae:
                        return {"status": "error", "error": f"Backend context error: {str(ae)}"}

                try:
                    result = await asyncio.wait_for(execute_action(), timeout=120)
                    writer.write(json.dumps(result, ensure_ascii=False, cls=PydanticEncoder).encode('utf-8') + b'\n')
                except asyncio.TimeoutError:
                    writer.write(json.dumps({
                        "status": "error",
                        "error": f"Action '{cmd_data.action}' timed out after 120s watchdog",
                        "stdout": captured_stdout.getvalue()
                    }).encode('utf-8') + b'\n')
                except Exception as e:
                    import traceback
                    err_trace = traceback.format_exc()
                    logging.error(f"Daemon Action Execution Error: {e}\n{err_trace}")
                    writer.write(json.dumps({
                        "status": "error",
                        "error": str(e),
                        "stdout": captured_stdout.getvalue(),
                        "traceback": err_trace if backend.config.get("logging.level") == "DEBUG" else None
                    }).encode('utf-8') + b'\n')
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
        except Exception:
            pass


async def daemon_watchdog(stop_event: asyncio.Event):
    """Murphy-proof watchdog that monitors the parent process."""
    import os
    parent_pid = os.getppid()
    if parent_pid == 1:
        return

    while not stop_event.is_set():
        try:
            os.kill(parent_pid, 0)
        except OSError:
            logging.error(f"Murphy-proof Watchdog: Parent process {parent_pid} vanished. Self-terminating...")
            stop_event.set()
            break
        await asyncio.sleep(10)
