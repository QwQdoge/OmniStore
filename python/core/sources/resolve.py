from typing import Any, Mapping, Optional


def resolve_source(sources: Mapping[str, Any], name: str) -> Optional[Any]:
    """Find a source by registry key, plugin id or display name ("Homebrew Cask" -> brewcask)."""
    wanted = str(name or "").strip().lower()
    if not wanted or not sources:
        return None
    if wanted in sources:
        return sources[wanted]
    squashed = wanted.replace(" ", "")
    for key, source in sources.items():
        ids = {
            str(key).lower(),
            str(getattr(source, "source_id", "")).lower().removeprefix("builtin.").removeprefix("legacy."),
            str(getattr(source, "name", "")).lower(),
            str(getattr(source, "display_name", "")).lower(),
        }
        if wanted in ids or squashed in {i.replace(" ", "") for i in ids}:
            return source
    return None
