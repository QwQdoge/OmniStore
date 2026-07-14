import yaml
from pathlib import Path
from typing import Any, Dict, Optional
import os
from copy import deepcopy
from pydantic import BaseModel, Field

class SearchSourcesModel(BaseModel):
    pacman: bool = True
    aur: bool = True
    flatpak: bool = True
    appimage: bool = True
    snap: bool = True
    github: bool = True
    bitu: bool = True
    winget: bool = True
    scoop: bool = True
    brew: bool = True
    ai: bool = True

class SearchModel(BaseModel):
    sources: SearchSourcesModel = Field(default_factory=SearchSourcesModel)
    max_results: int = Field(default=100, ge=1, le=500)

class UIModel(BaseModel):
    appearance: str = Field(default="system")
    color_seed: str = Field(default="#4E7EEF")
    language: str = Field(default="zh-CN")
    enable_system_tray: bool = True
    close_to_tray: bool = True
    font_family: str = "System"
    font_scale: float = Field(default=1.0, ge=0.5, le=2.0)

class AIModel(BaseModel):
    enabled: bool = False
    provider: str = Field(default="ollama")
    endpoint: str = Field(default="http://localhost:11434")
    model: str = Field(default="qwen2.5:7b")
    api_key: str = ""
    temperature: float = Field(default=0.7, ge=0.0, le=2.0)
    max_tokens: int = Field(default=2048, ge=1)
    proxy: str = ""

class PluginsModel(BaseModel):
    enabled: Dict[str, bool] = Field(default_factory=dict)
    config: Dict[str, Any] = Field(default_factory=dict)

class SourcesModel(BaseModel):
    order: list = Field(default_factory=list)
    priority: Dict[str, int] = Field(default_factory=dict)

class ConfigModel(BaseModel):
    first_run: bool = True
    search: SearchModel = Field(default_factory=SearchModel)
    priority: Dict[str, int] = Field(default_factory=dict)
    ui: UIModel = Field(default_factory=UIModel)
    logging: Dict[str, str] = Field(default_factory=dict)
    notifications: Dict[str, bool] = Field(default_factory=dict)
    updates: Dict[str, Any] = Field(default_factory=dict)
    ai: AIModel = Field(default_factory=AIModel)
    custom_repos: Dict[str, list] = Field(default_factory=dict)
    mirrors: Dict[str, Any] = Field(default_factory=dict)
    daemon: Dict[str, Any] = Field(default_factory=dict)
    plugins: PluginsModel = Field(default_factory=PluginsModel)
    sources: SourcesModel = Field(default_factory=SourcesModel)

class ConfigManager:
    def __init__(self, config_name="config.yaml"):
        # 遵循 XDG 规范
        xdg_config = os.environ.get('XDG_CONFIG_HOME')
        if xdg_config:
            self.config_dir = Path(xdg_config) / "omnistore"
        else:
            self.config_dir = Path.home() / ".config" / "omnistore"

        self.config_path = self.config_dir / config_name

        self.default_config = {
            "first_run": True,
            "search": {
                "sources": {
                    "pacman": True,
                    "aur": True,
                    "flatpak": True,
                    "appimage": True,
                    "snap": True,
                    "github": True,
                    "bitu": True,
                    "winget": True,
                    "scoop": True,
                    "brew": True,
                    "ai": True
                },
                "max_results": 100
            },
            "priority": {
                "pacman": 100, "aur": 80, "flatpak": 60, "appimage": 40, "snap": 30
            },
            "ui": {
                "appearance": "system",
                "color_seed": "#4E7EEF",
                "language": "zh-CN",
                "enable_system_tray": True,
                "close_to_tray": True
            },
            "logging": {
                "level": "INFO"
            },
            "notifications": {
                "enabled": True,
                "progress": True,
                "completion": True
            },
            "updates": {
                "check_interval_hours": 1,
                "remind_updates": True,
                "include_aur_in_update_all": True,
                "enable_systemd_service": False
            },
            "ai": {
                "enabled": False,
                "provider": "ollama",  # ollama, openai, gemini, custom
                "endpoint": "http://localhost:11434",
                "model": "qwen2.5:7b",
                "api_key": "",
                "temperature": 0.7,
                "max_tokens": 2048,
                "proxy": ""
            },
            "custom_repos": {
                "flatpak": [],
                "pacman": [],
                "appimage": []
            },
            "mirrors": {
                "pacman": "/etc/pacman.d/mirrorlist",
                "flatpak_remotes": ["https://dl.flathub.org/repo/flathub.flatpakrepo"]
            },
            "daemon": {
                "enabled": True,
                "check_interval_hours": 4,
                "auto_update": False,
                "notifications": True
            },
            "plugins": {
                "enabled": {},
                "config": {}
            },
            "sources": {
                "order": ["github", "bitu", "pacman", "aur", "flatpak", "appimage", "winget", "scoop", "brew"],
                "priority": {
                    "pacman": 100, "aur": 80, "flatpak": 60, "appimage": 40,
                    "winget": 90, "scoop": 70, "brew": 70, "github": 30, "bitu": 30
                }
            }
        }
        # 初始化加载
        self.current_config = self.load()
        self.backend = None

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
                merged = self._deep_update(deepcopy(self.default_config), user_cfg)
                try:
                    validated = ConfigModel(**merged).model_dump()
                    return validated
                except Exception as ve:
                    print(f"[Config] Validation Warning: {ve}")
                    return merged
        except Exception as e:
            print(f"[Config] Load Error (falling back to default): {e}")
            return self.default_config

    def save(self, new_config: Optional[dict] = None) -> bool:
        """
        Murphy-proof configuration save logic.
        Ensures strict schema validation, directory existence, and atomic file replacement
        to prevent configuration corruption during mid-write crashes or power failures.
        """
        cfg = new_config if new_config is not None else self.current_config
        try:
            # 1. Rigorous Schema Validation
            try:
                cfg = ConfigModel(**cfg).model_dump()
            except Exception as ve:
                print(f"[Config] Save Validation Error: {ve}")
                # Fault Isolation: Refuse to save invalid config to protect system stability
                return False
            
            # 2. Preparation: Ensure directory exists
            self.config_dir.mkdir(parents=True, exist_ok=True)

            # 3. Atomic Write Pattern: Write to temporary file first
            temp_file = self.config_path.with_suffix(".tmp")
            try:
                with open(temp_file, "w", encoding="utf-8") as f:
                    yaml.dump(cfg, f, allow_unicode=True,
                              sort_keys=False, default_flow_style=False)

                # Force sync to disk if supported to ensure data integrity
                if hasattr(os, "fdatasync"):
                    with open(temp_file, "a") as f:
                        os.fdatasync(f.fileno())

                # 4. Atomic Swap: Atomic replace ensures the original file is either
                # unchanged or completely updated, never in a partial state.
                temp_file.replace(self.config_path)
                self.current_config = cfg
                return True
            except Exception as write_e:
                print(f"[Config] File Write Error: {write_e}")
                if temp_file.exists():
                    try: temp_file.unlink()
                    except Exception: pass
                return False

        except Exception as e:
            print(f"[Config] Save Fatal Error: {e}")
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
