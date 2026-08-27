"""Built-in package sources, imported only when the registry requests them.

Keeping this package initializer lazy is important for narrow helpers such as
the Meo channel manager: importing ``core.sources.utils`` must not also import
every network plugin and its optional runtime dependencies.
"""

from importlib import import_module

__all__ = [
    "PacmanSource",
    "AurSource",
    "FlatpakSource",
    "AppImageSource",
    "GitHubSource",
    "BituSource",
]

_SOURCES = {
    "PacmanSource": (".pacman", "PacmanSource"),
    "AurSource": (".aur.aur", "AurSource"),
    "FlatpakSource": (".flatpak.flatpak", "FlatpakSource"),
    "AppImageSource": (".appimage.appimage", "AppImageSource"),
    "GitHubSource": (".github.github", "GitHubSource"),
    "BituSource": (".bitu.bitu", "BituSource"),
}


def __getattr__(name):
    try:
        module_name, attribute = _SOURCES[name]
    except KeyError as error:
        raise AttributeError(name) from error
    value = getattr(import_module(module_name, __name__), attribute)
    globals()[name] = value
    return value
