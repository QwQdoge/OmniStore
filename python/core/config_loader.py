import yaml
from pathlib import Path
from typing import Any, Dict, Optional


class ConfigManager:
    def __init__(self, config_name="config.yaml"):
        # 遵循 XDG 规范
        self.config_dir = Path.home() / ".config" / "omnistore"
        self.config_path = self.config_dir / config_name

        self.default_config = {
            "search": {
                "sources": {
                    "pacman": True,
                    "aur": True,
                    "flatpak": True,
                    "appimage": True
                },
                "max_results": 100
            },
            "priority": {
                "pacman": 100, "aur": 80, "flatpak": 60, "appimage": 40
            },
            "ui": {
                "appearance": "system",
                "color_seed": "#4E7EEF"
            },
            "logging": {
                "level": "INFO"
            }
        }
        # 初始化加载
        self.current_config = self.load()

    @property
    def data(self) -> Dict:
        """提供给 Backend 获取全量配置"""
        return self.current_config

    def _deep_update(self, base: dict, overrides: dict) -> dict:
        """
        递归合并字典。
        将 overrides 类型声明为 dict 以解决类型不匹配问题。
        """
        for k, v in overrides.items():
            # 使用 isinstance(v, dict) 代替 Mapping，更加直观且符合类型检查
            if isinstance(v, dict) and k in base and isinstance(base[k], dict):
                self._deep_update(base[k], v)
            else:
                base[k] = v
        return base

    def load(self) -> dict:
        """加载逻辑：确保目录存在，并合并默认值"""
        if not self.config_path.exists():
            self.config_dir.mkdir(parents=True, exist_ok=True)
            self.save(self.default_config)
            return self.default_config

        try:
            with open(self.config_path, "r", encoding="utf-8") as f:
                user_cfg = yaml.safe_load(f) or {}
                # 递归合并，保证用户缺少的配置项由默认值补齐
                return self._deep_update(self.default_config.copy(), user_cfg)
        except Exception as e:
            print(f"[Config] Load Error (falling back to default): {e}")
            return self.default_config

    def save(self, new_config: Optional[dict] = None) -> bool:
        """保存配置：原子写入 + 实时更新内存内存缓存"""
        cfg = new_config if new_config is not None else self.current_config
        try:
            self.config_dir.mkdir(parents=True, exist_ok=True)
            temp_file = self.config_path.with_suffix(".tmp")

            with open(temp_file, "w", encoding="utf-8") as f:
                # 不排序 Key，保持 yaml 的易读性
                yaml.dump(cfg, f, allow_unicode=True,
                          sort_keys=False, default_flow_style=False)

            # 原子重命名，防止保存时断电损坏原始文件
            temp_file.replace(self.config_path)
            self.current_config = cfg
            return True
        except Exception as e:
            print(f"[Config] Save Error: {e}")
            return False

    def get(self, key_path: str, default: Any = None) -> Any:
        """支持 'ui.appearance' 路径式获取"""
        keys = key_path.split('.')
        value = self.current_config
        try:
            for k in keys:
                value = value[k]
            return value
        except (KeyError, TypeError):
            return default

    def set(self, key_path: str, value: Any):
        """支持 'search.sources.aur' 路径式修改"""
        keys = key_path.split('.')
        target = self.current_config
        for k in keys[:-1]:
            target = target.setdefault(k, {})
        target[keys[-1]] = value
        self.save()
