import yaml
from pathlib import Path
from typing import Any, Dict, Optional
import os
import tempfile
import threading
import logging
from copy import deepcopy
from pydantic import BaseModel, Field

class SearchSourcesModel(BaseModel):
    pacman: bool = True
    aur: bool = False
    flatpak: bool = True
    appimage: bool = False
    snap: bool = False
    github: bool = False
    bitu: bool = False
    winget: bool = False
    scoop: bool = False
    brew: bool = False
    apt: bool = False
    dnf: bool = False
    zypper: bool = False
    apk: bool = False
    chocolatey: bool = False
    fdroid: bool = False
    ai: bool = False

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
                    "aur": False,
                    "flatpak": True,
                    "appimage": False,
                    "snap": False,
                    "github": False,
                    "bitu": False,
                    "winget": False,
                    "scoop": False,
                    "brew": False,
                    "apt": False,
                    "dnf": False,
                    "zypper": False,
                    "apk": False,
                    "chocolatey": False,
                    "fdroid": False,
                    "ai": False
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
                "include_aur_in_update_all": False,
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
                "appimage": [],
                "apt": [],
                "dnf": [],
                "zypper": [],
                "apk": [],
                "chocolatey": [],
                "fdroid": []
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
                "order": ["github", "bitu", "pacman", "aur", "flatpak", "appimage", "apt", "dnf", "zypper", "apk", "winget", "scoop", "chocolatey", "brew", "fdroid"],
                "priority": {
                    "pacman": 100, "aur": 80, "flatpak": 60, "appimage": 40,
                    "winget": 90, "scoop": 70, "chocolatey": 70, "brew": 70,
                    "apt": 85, "dnf": 85, "zypper": 85, "apk": 75, "fdroid": 55,
                    "github": 30, "bitu": 30
                }
            }
        }
        # Serialize reload/read-modify-write within this process.
        self._lock = threading.RLock()
        self._signature = None
        # 初始化加载
        self.current_config = self.load()
        self.backend = None

    @property
    def data(self) -> Dict:
        """提供给 Backend 获取全量配置"""
        with self._lock:
            self._reload_if_changed()
            return self.current_config

    def _reload_if_changed(self):
        try:
            stat = self.config_path.stat()
            signature = (stat.st_ino, stat.st_mtime_ns, stat.st_size)
        except OSError:
            return
        if signature != self._signature:
            self.current_config = self.load()

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
        with self._lock:
            if not self.config_path.exists():
                if not hasattr(self, "current_config"):
                    self.save(deepcopy(self.default_config))
                return deepcopy(getattr(self, "current_config", self.default_config))
            try:
                with self.config_path.open("r", encoding="utf-8") as stream:
                    user_config = yaml.safe_load(stream) or {}
                    stat = os.fstat(stream.fileno())
                if not isinstance(user_config, dict):
                    raise ValueError("Configuration must be a mapping")
                merged = self._deep_update(deepcopy(self.default_config), user_config)
                validated = ConfigModel(**merged).model_dump()
                # Bind the signature to the descriptor actually read, so a
                # replacement during this read is observed on the next access.
                self._signature = (stat.st_ino, stat.st_mtime_ns, stat.st_size)
                return validated
            except Exception:
                logging.getLogger("omnistore").warning(
                    "Invalid configuration; keeping the last valid settings"
                )
                return deepcopy(getattr(self, "current_config", self.default_config))

    def save(self, new_config: Optional[dict] = None) -> bool:
        with self._lock:
            temporary = None
            try:
                cfg = ConfigModel(**(new_config if new_config is not None
                                     else self.current_config)).model_dump()
                self.config_dir.mkdir(parents=True, exist_ok=True)
                # Exclusive, private, distinct files prevent concurrent saves
                # from truncating or replacing each other's temporary output.
                with tempfile.NamedTemporaryFile(
                    mode="w", encoding="utf-8", dir=self.config_dir,
                    prefix=".omnistore-config-", suffix=".tmp", delete=False,
                ) as stream:
                    temporary = Path(stream.name)
                    yaml.safe_dump(cfg, stream, allow_unicode=True, sort_keys=False)
                    stream.flush()
                    os.fsync(stream.fileno())
                    stat = os.fstat(stream.fileno())
                os.replace(temporary, self.config_path)
                self._signature = (stat.st_ino, stat.st_mtime_ns, stat.st_size)
                self.current_config = cfg
                return True
            except Exception:
                logging.getLogger("omnistore").warning("Configuration save failed")
                return False
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)

    def get(self, key_path: str, default: Any = None) -> Any:
        """支持 'ui.appearance' 路径式获取"""
        with self._lock:
            self._reload_if_changed()
            value = self.current_config
            try:
                keys = key_path.split('.')
                for index, key in enumerate(keys):
                    remainder = '.'.join(keys[index:])
                    if isinstance(value, dict) and remainder in value:
                        return value[remainder]
                    value = value[key]
                return value
            except (KeyError, TypeError):
                return default

    def set(self, key_path: str, value: Any):
        with self._lock:
            self._reload_if_changed()
            updated = deepcopy(self.current_config)
            keys = key_path.split('.')
            target = updated
            for key in keys[:-1]:
                target = target.setdefault(key, {})
            target[keys[-1]] = value
            return self.save(updated)
