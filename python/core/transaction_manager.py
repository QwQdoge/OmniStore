from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from datetime import datetime, timezone
import json
from typing import Any
from uuid import uuid4

from core.backend import captured_output_var


_MAX_LOG_CHARS = 256 * 1024
_MAX_COMPLETED_TASKS = 64
_ALLOWED_KINDS = {"install", "remove", "update", "update_all"}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _json_safe(value: Any) -> Any:
    if hasattr(value, "model_dump"):
        return value.model_dump(exclude_none=True)
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    if isinstance(value, dict):
        return {str(key): _json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(item) for item in value]
    return str(value)


@dataclass
class TransactionRecord:
    task_id: str
    kind: str
    name: str
    source: str
    url: str | None = None
    status: str = "queued"
    created_at: str = field(default_factory=_utc_now)
    updated_at: str = field(default_factory=_utc_now)
    progress: float | None = None
    stage: str = ""
    speed: str = ""
    log: str = ""
    error: str = ""
    result: Any = None

    def snapshot(self) -> dict[str, Any]:
        data: dict[str, Any] = {
            "schema": "org.meo.omnistore.transaction-task",
            "version": 1,
            "taskId": self.task_id,
            "kind": self.kind,
            "name": self.name,
            "source": self.source,
            "status": self.status,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at,
            "stage": self.stage,
            "speed": self.speed,
            "log": self.log,
        }
        if self.progress is not None:
            data["progress"] = self.progress
        if self.error:
            data["error"] = self.error
        if self.result is not None:
            data["result"] = _json_safe(self.result)
        return data


class _TaskCapture:
    """File-like capture target that also extracts existing callback metadata."""

    def __init__(self, record: TransactionRecord):
        self._record = record
        self._partial = ""

    def write(self, data: Any) -> int:
        text = str(data)
        self._partial += text
        while "\n" in self._partial:
            line, self._partial = self._partial.split("\n", 1)
            self._consume_line(line.strip())
        return len(text)

    def flush(self) -> None:
        if self._partial.strip():
            self._consume_line(self._partial.strip())
            self._partial = ""

    def _append_log(self, line: str) -> None:
        if not line:
            return
        if self._record.log:
            self._record.log += "\n"
        self._record.log += line[:8192]
        if len(self._record.log) > _MAX_LOG_CHARS:
            self._record.log = self._record.log[-_MAX_LOG_CHARS:]
        self._record.updated_at = _utc_now()

    def _consume_line(self, line: str) -> None:
        if not line:
            return
        callback_prefix = "[CALLBACK] "
        if line.startswith(callback_prefix):
            try:
                payload = json.loads(line[len(callback_prefix):])
            except json.JSONDecodeError:
                self._append_log(line)
                return
            kind = str(payload.get("type") or "")
            if kind == "progress":
                try:
                    value = float(payload.get("progress"))
                    if value > 1.0:
                        value /= 100.0
                    self._record.progress = max(0.0, min(1.0, value))
                except (TypeError, ValueError):
                    pass
            elif kind == "stage":
                self._record.stage = str(payload.get("stage") or "")[:512]
            elif kind == "speed":
                self._record.speed = str(payload.get("speed") or "")[:256]
            else:
                message = str(payload.get("message") or "")
                if message:
                    self._append_log(message)
            self._record.updated_at = _utc_now()
            return
        self._append_log(line)


class TransactionManager:
    """Owns package mutations independently from any graphical client connection."""

    def __init__(self, backend: Any):
        self._backend = backend
        self._records: dict[str, TransactionRecord] = {}
        self._tasks: dict[str, asyncio.Task] = {}
        self._mutation_lock = asyncio.Lock()

    def submit(
        self,
        *,
        kind: str,
        name: str = "",
        source: str = "Native",
        url: str | None = None,
    ) -> dict[str, Any]:
        normalized_kind = str(kind or "").strip().lower()
        if normalized_kind not in _ALLOWED_KINDS:
            raise ValueError("unsupported_transaction_kind")

        normalized_name = str(name or "").strip()
        normalized_source = str(source or "Native").strip() or "Native"
        if normalized_kind == "update_all":
            normalized_name = "all"
            normalized_source = "all"
        elif not normalized_name:
            raise ValueError("missing_package_name")

        task_id = uuid4().hex
        record = TransactionRecord(
            task_id=task_id,
            kind=normalized_kind,
            name=normalized_name[:512],
            source=normalized_source[:128],
            url=(str(url).strip()[:4096] if url else None),
        )
        self._records[task_id] = record
        task = asyncio.create_task(self._run(record), name=f"omnistore-transaction-{task_id}")
        self._tasks[task_id] = task
        task.add_done_callback(lambda _: self._tasks.pop(task_id, None))
        self._trim_completed()
        return record.snapshot()

    def get(self, task_id: str) -> dict[str, Any]:
        record = self._records.get(str(task_id or "").strip())
        if record is None:
            raise KeyError("transaction_not_found")
        return record.snapshot()

    def list(self) -> list[dict[str, Any]]:
        records = sorted(self._records.values(), key=lambda item: item.created_at, reverse=True)
        return [record.snapshot() for record in records]

    async def _run(self, record: TransactionRecord) -> None:
        async with self._mutation_lock:
            record.status = "running"
            record.updated_at = _utc_now()
            capture = _TaskCapture(record)
            token = captured_output_var.set(capture)
            try:
                if record.kind == "install":
                    result = await self._backend.run_install(
                        record.name, record.source, record.url, True
                    )
                elif record.kind == "remove":
                    result = await self._backend.run_uninstall(
                        record.name, record.source, True
                    )
                elif record.kind == "update":
                    result = await self._backend.run_update(
                        record.name, record.source, True
                    )
                else:
                    result = await self._backend.run_update("all", "all", True)

                capture.flush()
                record.result = _json_safe(result)
                if isinstance(result, dict) and result.get("status") == "error":
                    record.status = "failed"
                    record.error = str(
                        result.get("message") or result.get("error") or "transaction_failed"
                    )[:2048]
                elif result is False:
                    record.status = "failed"
                    record.error = "transaction_failed"
                else:
                    record.status = "succeeded"
                    record.progress = 1.0
            except asyncio.CancelledError:
                record.status = "cancelled"
                record.error = "transaction_cancelled"
                raise
            except Exception as exc:
                record.status = "failed"
                record.error = str(exc)[:2048] or "transaction_failed"
            finally:
                capture.flush()
                record.updated_at = _utc_now()
                captured_output_var.reset(token)
                self._trim_completed()

    def _trim_completed(self) -> None:
        completed = [
            record for record in self._records.values()
            if record.status in {"succeeded", "failed", "cancelled"}
        ]
        if len(completed) <= _MAX_COMPLETED_TASKS:
            return
        completed.sort(key=lambda item: item.updated_at)
        for record in completed[: len(completed) - _MAX_COMPLETED_TASKS]:
            self._records.pop(record.task_id, None)
