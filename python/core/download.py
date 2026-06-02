import asyncio
from typing import Dict, Any, List, Optional, Callable

async def unified_install(source_name: str, package: Dict[str, Any], callback: Callable = None) -> bool:
    """Aggregated install logic that routes to the specific source download module."""
    if source_name.lower() == "pacman":
        from core.sources.pacman.download import install_pacman
        return await install_pacman(package, callback)
    # Add other sources as they are refactored
    return False

async def unified_uninstall(source_name: str, package: Dict[str, Any], callback: Callable = None) -> bool:
    """Aggregated uninstall logic that routes to the specific source download module."""
    if source_name.lower() == "pacman":
        from core.sources.pacman.download import uninstall_pacman
        return await uninstall_pacman(package, callback)
    return False
