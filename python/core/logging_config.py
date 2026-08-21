from __future__ import annotations

import json
import logging
import sys
from datetime import datetime, timezone
from typing import Optional


class _JsonFormatter(logging.Formatter):
    """Machine-readable logs for IPC/daemon mode.

    Log severity is metadata instead of being embedded into the human message.
    Output is always written to stderr so stdout can remain a clean protocol
    channel for JSON command responses.
    """

    def __init__(self, component: str):
        super().__init__()
        self.component = component

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.fromtimestamp(
                record.created, tz=timezone.utc
            ).isoformat(),
            "level": record.levelname.lower(),
            "component": self.component,
            "logger": record.name,
            "message": record.getMessage(),
        }

        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)

        return json.dumps(payload, ensure_ascii=False)


def _coerce_level(level: str | int | None) -> int:
    if isinstance(level, int):
        return level
    if isinstance(level, str):
        resolved = logging.getLevelName(level.strip().upper())
        if isinstance(resolved, int):
            return resolved
    return logging.INFO


def configure_logging(
    level: str | int | None = "INFO",
    *,
    json_mode: bool = False,
    component: str = "omnistore",
) -> None:
    """Configure application logging exactly once per process entry point.

    The root logger is intentionally configured here because many existing
    modules still use ``logging.info(...)`` style calls. Centralizing the
    handler makes those calls consistent without forcing an unsafe big-bang
    migration across the entire backend.
    """

    root = logging.getLogger()
    root.setLevel(_coerce_level(level))

    # Entry points own logging configuration. Replacing handlers prevents
    # duplicate lines when main() is invoked repeatedly in tests or embedding.
    for handler in list(root.handlers):
        root.removeHandler(handler)
        try:
            handler.close()
        except Exception:
            pass

    if json_mode:
        handler: logging.Handler = logging.StreamHandler(sys.stderr)
        handler.setFormatter(_JsonFormatter(component))
    else:
        try:
            from rich.logging import RichHandler

            handler = RichHandler(
                show_time=True,
                show_level=True,
                show_path=False,
                rich_tracebacks=True,
                markup=False,
            )
            handler.setFormatter(logging.Formatter(f"{component} · %(message)s"))
        except Exception:
            handler = logging.StreamHandler(sys.stderr)
            handler.setFormatter(
                logging.Formatter(
                    f"%(asctime)s %(levelname)s {component} · %(message)s"
                )
            )

    root.addHandler(handler)
    logging.captureWarnings(True)
