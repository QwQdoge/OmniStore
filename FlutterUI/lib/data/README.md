# `data/` — Python bridge layer

Spawns **`python/main.py`** (dev) or **`backends/python_server`** (release) via `Process.run`.

| File | Purpose |
|------|---------|
| `python_bridge.dart` | `PythonBridge` — resolves executable, cwd, CLI args |
| `repositories/config_repository.dart` | Read/write `config.yaml` |
| `repositories/package_repository.dart` | Search, details, recommendations |
| `repositories/task_repository.dart` | Install, update, clean |
| `repositories/ai_repository.dart` | AI explain/compare/CLI helpers |

**Do not** put widgets here. **Do not** confuse with `/python` — that directory is the backend implementation.
