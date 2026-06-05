import os
import sys
import importlib.util
import logging
from typing import Dict, List, Type
from core.base_source import BaseSource

class SourceManager:
    """
    Dynamically scans and loads all valid Source plugins from the python/source/ directory.
    """
    def __init__(self, sources_dir: str = None):
        if sources_dir is None:
            # Default to python/source relative to this file's grand-parent
            current_dir = os.path.dirname(os.path.abspath(__file__))
            self.sources_dir = os.path.join(os.path.dirname(current_dir), "source")
        else:
            self.sources_dir = sources_dir

        self.sources: Dict[str, BaseSource] = {}
        self._load_all_sources()

    def _load_all_sources(self):
        """Scans the source directory and loads plugins."""
        if not os.path.exists(self.sources_dir):
            logging.warning(f"Source directory not found: {self.sources_dir}")
            return

        sys.path.append(self.sources_dir)

        # Each folder in python/source/ represents a source plugin
        for item in os.listdir(self.sources_dir):
            plugin_path = os.path.join(self.sources_dir, item)

            if os.path.isdir(plugin_path) and not item.startswith("__"):
                self._load_plugin_folder(item, plugin_path)

    def _load_plugin_folder(self, folder_name: str, folder_path: str):
        """
        Loads the main module from a plugin folder.
        We expect the entry point to be a Python file matching the folder name (e.g., github/github.py)
        or __init__.py.
        """
        # Strategy 1: Look for folder_name.py
        entry_file = os.path.join(folder_path, f"{folder_name}.py")
        if not os.path.exists(entry_file):
            # Strategy 2: Look for __init__.py
            entry_file = os.path.join(folder_path, "__init__.py")
            if not os.path.exists(entry_file):
                logging.debug(f"Skipping {folder_name}: No valid entry point found ({folder_name}.py or __init__.py)")
                return

        module_name = f"source.{folder_name}"

        try:
            spec = importlib.util.spec_from_file_location(module_name, entry_file)
            if spec and spec.loader:
                module = importlib.util.module_from_spec(spec)
                sys.modules[module_name] = module  # Add to sys.modules to resolve intra-package imports
                spec.loader.exec_module(module)

                # Find classes inheriting from BaseSource
                for attr_name in dir(module):
                    attr = getattr(module, attr_name)
                    if (isinstance(attr, type) and
                        issubclass(attr, BaseSource) and
                        attr is not BaseSource):

                        try:
                            # Instantiate the source
                            instance = attr()
                            self.sources[instance.name.lower()] = instance
                            logging.info(f"Loaded source plugin: {instance.name} from {folder_name}")
                        except Exception as e:
                            logging.error(f"Failed to instantiate source {attr_name} from {folder_name}: {e}")

        except Exception as e:
            logging.error(f"Failed to load plugin module {module_name} from {entry_file}: {e}")

    def get_source(self, name: str) -> BaseSource:
        """Get a specific source by name."""
        return self.sources.get(name.lower())

    def get_all_sources(self) -> List[BaseSource]:
        """Get all loaded sources."""
        return list(self.sources.values())

    def get_enabled_sources(self) -> List[BaseSource]:
        """Get all currently enabled sources."""
        return [s for s in self.sources.values() if s.enabled]
