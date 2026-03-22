from typing import Any
import yaml
from pathlib import Path
from collections.abc import Mapping

class ConfigManager:
    def __init__(self, config_name="config.yaml"):
        # 1. 强制 XDG 规范：确保配置文件永远在 ~/.config/omniarch/
        self.config_dir = Path.home() / ".config" / "omniarch"
        self.config_path = self.config_dir / config_name
        
        self.default_config = {
            "search": {
                "sources": {
                    "pacman": True, "aur": True, "flatpak": True, "appimage": True
                },
                "max_results": 100
            },
            "priority": {
                "pacman": 100, "aur": 80, "flatpak": 60, "appimage": 40
            },
            "ui": {
                "appearance": "system",
                "color_seed": "#CA6ECF"
            }
        }
        self.current_config = self.load()

    def _deep_update(self, base, overrides):
        """递归合并字典，防止子项被整个覆盖"""
        for k, v in overrides.items():
            if isinstance(v, Mapping) and k in base and isinstance(base[k], Mapping):
                self._deep_update(base[k], v)
            else:
                base[k] = v
        return base

    def load(self):
        """加载并确保目录存在"""
        if not self.config_path.exists():
            self.config_dir.mkdir(parents=True, exist_ok=True)
            self.save(self.default_config)
            return self.default_config
        
        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                user_cfg = yaml.safe_load(f) or {}
                # 使用深拷贝合并，确保 search.sources 不会因为用户改了 max_results 而消失
                return self._deep_update(self.default_config.copy(), user_cfg)
        except Exception as e:
            print(f"[Config] Load Error: {e}")
            return self.default_config

    def save(self, new_config=None):
        """保存时增加备份逻辑，防止断电导致配置损坏"""
        cfg = new_config or self.current_config
        try:
            # 先写临时文件再重命名，这是 Linux 程序的常规稳健做法
            temp_file = self.config_path.with_suffix(".tmp")
            with open(temp_file, "w", encoding="utf-8") as f:
                yaml.dump(cfg, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
            temp_file.replace(self.config_path)
            self.current_config = cfg
        except Exception as e:
            print(f"[Config] Save Error: {e}")

    # --- 你的 update_source 函数建议改写为通用更新 ---
    def set(self, key_path, value):
        """通用设置方法：支持 'search.sources.aur'"""
        keys = key_path.split('.')
        target = self.current_config
        for k in keys[:-1]:
            target = target.setdefault(k, {})
        target[keys[-1]] = value
        self.save()

    def get(self, key_path: str, default: Any = None) -> Any:
        """
        支持 'search.sources.aur' 这种路径式获取配置
        """
        keys = key_path.split('.')
        value = self.current_config
        
        try:
            for k in keys:
                if isinstance(value, dict):
                    value = value.get(k)
                else:
                    return default
            return value if value is not None else default
        except Exception:
            return default