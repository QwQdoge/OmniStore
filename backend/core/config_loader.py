import yaml
import os
from pathlib import Path

class ConfigManager:
    def __init__(self, config_path="config.yaml"):
        self.config_path = Path(config_path)
        # 默认配置：防止文件丢失时程序崩溃
        self.default_config = {
            "search": {
                "sources": {
                    "pacman": True,
                    "aur": False,
                    "flatpak": True,
                    "appimage": False
                },
                "default_sort": "smart",
                "max_results": 100
            },
            "priority": {
                "pacman": 100,
                "aur": 80,
                "flatpak": 60,
                "appimage": 40
            }
        }
        self.current_config = self.load()

    def load(self):
        """从磁盘读取配置，如果不存在则创建默认的"""
        if not self.config_path.exists():
            self.save(self.default_config)
            return self.default_config
        
        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                user_cfg = yaml.safe_load(f) or {}
                # 合并默认配置，防止用户漏写某些项
                return {**self.default_config, **user_cfg}
        except Exception as e:
            print(f"Config Load Error: {e}, using defaults.")
            return self.default_config

    def save(self, new_config=None):
        """将当前内存配置或新配置写入磁盘"""
        cfg = new_config or self.current_config
        try:
            with open(self.config_path, "w", encoding="utf-8") as f:
                yaml.dump(cfg, f, allow_unicode=True, sort_keys=False)
            self.current_config = cfg
        except Exception as e:
            print(f"Config Save Error: {e}")

    def get(self, key_path, default=None):
        """快捷获取配置，支持 'search.sources.aur' 这种写法"""
        keys = key_path.split('.')
        value = self.current_config
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k)
            else:
                return default
        return value if value is not None else default

    def update_source(self, source_name: str, enabled: bool):
        """专门给前端调用的：动态开关某个源"""
        if "sources" in self.current_config["search"]:
            self.current_config["search"]["sources"][source_name] = enabled
            self.save() # 实时持久化