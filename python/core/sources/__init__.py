__all__ = [
    "PacmanSource",
    "AurSource",
    "FlatpakSource",
    "AppImageSource",
    "GitHubSource",
    "BituSource",
]


def __getattr__(name):
    """Load source plugins only when the registry asks for one.

    Channel discovery imports the lightweight privilege helper from this
    package.  Eager plugin imports would otherwise pull optional network
    dependencies (AUR/GitHub/etc.) into an offline channel operation.
    """
    modules = {
        "PacmanSource": (".pacman", "PacmanSource"),
        "AurSource": (".aur.aur", "AurSource"),
        "FlatpakSource": (".flatpak.flatpak", "FlatpakSource"),
        "AppImageSource": (".appimage.appimage", "AppImageSource"),
        "GitHubSource": (".github.github", "GitHubSource"),
        "BituSource": (".bitu.bitu", "BituSource"),
    }
    try:
        module_name, attribute = modules[name]
    except KeyError as error:
        raise AttributeError(name) from error
    from importlib import import_module

    value = getattr(import_module(module_name, __name__), attribute)
    globals()[name] = value
    return value
