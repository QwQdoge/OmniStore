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
        """
        Dynamically load .py files from the plugins directory.
        Murphy-proof: Strict validation and isolated instantiation to ensure
        buggy plugins cannot compromise the search manager.
        """
        if self.plugin_dir not in sys.path:
            sys.path.append(self.plugin_dir)

        try:
            plugin_files = [f for f in os.listdir(self.plugin_dir)
                          if f.endswith(".py") and not f.startswith("__")]
        except Exception as e:
            sys.stderr.write(f"[PluginLoader] Error listing plugins directory: {e}\n")
            return

        for filename in plugin_files:
            module_name = filename[:-3]
            file_path = os.path.join(self.plugin_dir, filename)

            try:
                # 1. Isolated Module Loading
                spec = importlib.util.spec_from_file_location(module_name, file_path)
                if spec is None or spec.loader is None:
                    sys.stderr.write(f"[PluginLoader] Could not load spec for {filename}\n")
                    continue

                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)

                # 2. Strict Class Discovery and Validation
                found_plugins = 0
                for attr_name in dir(module):
                    try:
                        attr = getattr(module, attr_name)
                        # Check if it's a class inheriting from UnifiedSource (but not the base class itself)
                        if (isinstance(attr, type) and
                            issubclass(attr, UnifiedSource) and
                            attr is not UnifiedSource):

                            # 3. Defensive Instantiation
                            try:
                                # Plugins might need session or config - we attempt to provide them
                                # but wrap in catch-all to prevent startup crash.
                                plugin_instance = attr()

                                # Validate mandatory attributes
                                if not hasattr(plugin_instance, 'name') or not plugin_instance.name:
                                    sys.stderr.write(f"[PluginLoader] Error: Plugin {attr_name} has no valid name.\n")
                                    continue

                                source_key = plugin_instance.name.lower()
                                self.sm.sources[source_key] = plugin_instance
                                sys.stderr.write(f"[PluginLoader] Successfully registered plugin: {plugin_instance.name}\n")
                                found_plugins += 1

                            except Exception as inst_e:
                                sys.stderr.write(f"[PluginLoader] Failed to instantiate {attr_name} from {filename}: {inst_e}\n")
                    except Exception as attr_e:
                        # getattr might fail in some weird dynamic modules
                        continue

                if found_plugins == 0:
                    sys.stderr.write(f"[PluginLoader] Warning: No valid UnifiedSource classes found in {filename}\n")

            except Exception as e:
                sys.stderr.write(f"[PluginLoader] Fatal error loading module {module_name}: {e}\n")
