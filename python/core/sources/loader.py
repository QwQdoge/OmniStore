import os
import importlib.util
import sys
from typing import List, Dict, Any
from core.sources.base import UnifiedSource

class PluginLoader:
    def __init__(self, search_manager):
        self.sm = search_manager
        self.plugin_dir = os.path.join(os.getcwd(), "plugins")
        if not os.path.exists(self.plugin_dir):
            os.makedirs(self.plugin_dir)

    def load_plugins(self):
        """Dynamically load .py files from the plugins directory."""
        sys.path.append(self.plugin_dir)

        for filename in os.listdir(self.plugin_dir):
            if filename.endswith(".py") and not filename.startswith("__"):
                module_name = filename[:-3]
                file_path = os.path.join(self.plugin_dir, filename)

                try:
                    spec = importlib.util.spec_from_file_location(module_name, file_path)
                    module = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(module)

                    # Look for a class that inherits from UnifiedSource
                    for attr_name in dir(module):
                        attr = getattr(module, attr_name)
                        if (isinstance(attr, type) and
                            issubclass(attr, UnifiedSource) and
                            attr is not UnifiedSource):

                            # Instantiate and add to SearchManager
                            try:
                                # Plugins might need session or config, try to provide what they need
                                # This is a simple instantiation, can be expanded
                                plugin_instance = attr()
                                self.sm.sources[plugin_instance.name.lower()] = plugin_instance
                                sys.stderr.write(f"[PluginLoader] Loaded plugin: {plugin_instance.name}\n")
                            except Exception as e:
                                sys.stderr.write(f"[PluginLoader] Failed to instantiate {attr_name}: {e}\n")
                except Exception as e:
                    sys.stderr.write(f"[PluginLoader] Failed to load module {module_name}: {e}\n")
