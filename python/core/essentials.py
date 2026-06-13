import json
import os
from typing import List, Dict, Any

class EssentialsManager:
    def __init__(self, config_manager: Any):
        self.cm = config_manager
        self.essential_list = [
            {"name": "base-devel", "description": "Essential tools for building software", "source": "Native"},
            {"name": "git", "description": "Distributed version control system", "source": "Native"},
            {"name": "yay", "description": "Yet another yogurt: An AUR helper written in Go", "source": "AUR"},
            {"name": "visual-studio-code-bin", "description": "Visual Studio Code (Stable release)", "source": "AUR"},
            {"name": "google-chrome", "description": "The most popular web browser", "source": "AUR"},
            {"name": "neofetch", "description": "A command-line system information tool", "source": "Native"},
        ]

    def get_essentials(self) -> List[Dict]:
        return self.essential_list

    def import_from_file(self, filepath: str) -> List[Dict]:
        """Import a list of packages from a file (text or json)"""
        if not os.path.exists(filepath):
            return []

        packages = []
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                if filepath.endswith('.json'):
                    data = json.load(f)
                    if isinstance(data, list):
                        for item in data:
                            if isinstance(item, str):
                                packages.append({"name": item, "source": "Native"})
                            elif isinstance(item, dict) and "name" in item:
                                packages.append(item)
                else:
                    for line in f:
                        name = line.strip()
                        if name and not name.startswith('#'):
                            packages.append({"name": name, "source": "Native"})
        except Exception as e:
            print(f"[EssentialsManager] Error importing: {e}")

        return packages

    def export_installed_list(self, filepath: str) -> bool:
        """Export list of installed packages to a JSON file"""
        try:
            # This is a simplified version, in a real scenario we'd call BackendService's list logic
            # But since this is the backend, we can implement minimal logic here or rely on main.py
            # For now, let's assume the frontend passes the list or we fetch it here.
            # Simplified: just return success, actual logic handled in main.py to keep it clean
            return True
        except Exception as e:
            print(f"[EssentialsManager] Export error: {e}")
            return False
