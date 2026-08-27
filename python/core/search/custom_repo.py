import sys
import logging
import os
import re
import asyncio
import tempfile
import shutil
from typing import Dict, List, Any, Optional
from core.subprocess_utils import safe_subprocess

logger = logging.getLogger(__name__)


class CustomRepoManager:
    """
    自定义软件源管理器 (Flatpak Remotes, Pacman Repos, AppImage Feeds)
    设计原则：绝对安全、拒绝崩溃、零内存泄漏、防呆机制与状态互斥防护
    """
    OFFICIAL_MEO_REPOSITORIES = frozenset({"meo", "meo-beta"})

    def __init__(self, config_manager: Any, executor: Any):
        self.cm = config_manager
        self.executor = executor
        # 防呆机制与状态互斥防护：使用 asyncio.Lock 避免并发写冲突与死锁
        self._lock = asyncio.Lock()

    # --- 辅助方法：入参防御性校验与安全回调 ---

    @staticmethod
    def _validate_name(name: Any) -> bool:
        """防呆机制：极端校验 repository/remote 名称，防止 shell 注入或格式错误"""
        if not name or not isinstance(name, str):
            return False
        name_str = name.strip()
        if not (1 <= len(name_str) <= 128):
            return False
        return bool(re.fullmatch(r"[A-Za-z0-9@._+:-]+", name_str))

    @staticmethod
    def _validate_url(url: Any) -> bool:
        """防呆机制：极端校验 URL 入参，确保协议合法且长度在安全区间"""
        if not url or not isinstance(url, str):
            return False
        url_str = url.strip()
        if not (1 <= len(url_str) <= 2048):
            return False
        return url_str.startswith(("http://", "https://", "file://"))

    async def _safe_callback(self, callback: Any, message: str) -> None:
        """安全执行回调，保留完整 Traceback 日志，避免隐匿编程错误"""
        if callback and callable(callback):
            try:
                res = callback(message)
                if asyncio.iscoroutine(res):
                    await res
            except Exception as e:
                logger.exception(f"Callback execution failed for message '{message}': {e}")
                raise

    # --- Flatpak Custom Remotes ---

    async def list_flatpak_remotes(self) -> List[Dict[str, str]]:
        """
        获取 Flatpak remotes 列表。
        防御机制：包含平台检测、二进制文件检查及完整异常捕获，确保降级为返回空列表。
        """
        if sys.platform != "linux" or not shutil.which("flatpak"):
            logger.debug("Flatpak is not available on this platform.")
            return []

        try:
            async with safe_subprocess(
                "flatpak", "remotes", "--columns=name,url",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.DEVNULL
            ) as proc:
                stdout, _ = await proc.communicate()
                if not stdout:
                    return []

                remotes: List[Dict[str, str]] = []
                for line in stdout.decode("utf-8", errors="replace").strip().splitlines():
                    if not line.strip():
                        continue
                    parts = line.split("\t")
                    if len(parts) >= 2:
                        name_part = parts[0].strip()
                        url_part = parts[1].strip()
                        if name_part and url_part:
                            remotes.append({"name": name_part, "url": url_part})
                return remotes
        except (OSError, asyncio.SubprocessError) as e:
            logger.error(f"Failed to list flatpak remotes: {e}")
            return []
        except Exception as e:
            logger.exception(f"Unexpected error listing flatpak remotes: {e}")
            raise

    async def add_flatpak_remote(self, name: str, url: str, callback: Any = None) -> bool:
        """
        添加自定义 Flatpak remote。
        防御机制：并发互斥锁、环境检查、入参校验及配置持久化失败回滚。
        """
        async with self._lock:
            if not self._validate_name(name) or not self._validate_url(url):
                await self._safe_callback(callback, f"[ERROR] Invalid remote name '{name}' or URL '{url}'.")
                return False

            if sys.platform != "linux" or not shutil.which("flatpak"):
                await self._safe_callback(callback, "[ERROR] Flatpak CLI is not available on this system.")
                return False

            name_clean = name.strip()
            url_clean = url.strip()

            try:
                await self._safe_callback(callback, f"[INFO] Adding Flatpak remote '{name_clean}' ({url_clean})...")

                async with safe_subprocess(
                    "flatpak", "remote-add", "--user", "--if-not-exists", name_clean, url_clean,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.STDOUT
                ) as proc:
                    stdout, _ = await proc.communicate()
                    success = (proc.returncode == 0)

                    if success:
                        if self.cm is not None:
                            try:
                                custom_flatpaks = self.cm.get("custom_repos.flatpak", [])
                                if not isinstance(custom_flatpaks, list):
                                    custom_flatpaks = []
                                for r in custom_flatpaks:
                                    if isinstance(r, dict) and r.get("name") == name_clean:
                                        break
                                else:
                                    custom_flatpaks.append({"name": name_clean, "url": url_clean})
                                    self.cm.set("custom_repos.flatpak", custom_flatpaks)
                            except Exception as cfg_err:
                                logger.error(f"Failed to update config for flatpak remote, rolling back remote: {cfg_err}")
                                try:
                                    async with safe_subprocess(
                                        "flatpak", "remote-delete", "--user", "--force", name_clean,
                                        stdout=asyncio.subprocess.PIPE,
                                        stderr=asyncio.subprocess.DEVNULL
                                    ) as rb_proc:
                                        await rb_proc.communicate()
                                except Exception as rb_err:
                                    logger.error(f"Rollback failed for flatpak remote '{name_clean}': {rb_err}")
                                await self._safe_callback(callback, f"[ERROR] Configuration persistence failed: {cfg_err}")
                                return False
                        await self._safe_callback(callback, f"[INFO] Successfully added Flatpak remote '{name_clean}'.")
                        return True
                    else:
                        err_msg = stdout.decode("utf-8", errors="replace").strip() if stdout else "Unknown error"
                        await self._safe_callback(callback, f"[ERROR] Failed to add remote: {err_msg}")
                        return False
            except (OSError, asyncio.SubprocessError) as e:
                logger.error(f"Exception in add_flatpak_remote: {e}")
                await self._safe_callback(callback, f"[ERROR] Failed to add flatpak remote: {e}")
                return False
            except Exception as e:
                logger.exception(f"Unexpected error in add_flatpak_remote: {e}")
                raise

    async def remove_flatpak_remote(self, name: str, callback: Any = None) -> bool:
        """
        移除自定义 Flatpak remote。
        防御机制：并发互斥锁、入参校验、配置持久化失败回滚 (Re-add deleted remote)。
        """
        async with self._lock:
            if not self._validate_name(name):
                await self._safe_callback(callback, f"[ERROR] Invalid remote name '{name}'.")
                return False

            if sys.platform != "linux" or not shutil.which("flatpak"):
                await self._safe_callback(callback, "[ERROR] Flatpak CLI is not available on this system.")
                return False

            name_clean = name.strip()

            # 寻找旧的 URL 以备配置写入失败时回滚
            old_url: Optional[str] = None
            if self.cm is not None:
                try:
                    custom_flatpaks = self.cm.get("custom_repos.flatpak", [])
                    if isinstance(custom_flatpaks, list):
                        for item in custom_flatpaks:
                            if isinstance(item, dict) and item.get("name") == name_clean:
                                old_url = item.get("url")
                                break
                except Exception as e:
                    logger.debug(f"Could not read existing remote URL from config: {e}")

            try:
                await self._safe_callback(callback, f"[INFO] Removing Flatpak remote '{name_clean}'...")

                async with safe_subprocess(
                    "flatpak", "remote-delete", "--user", "--force", name_clean,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.STDOUT
                ) as proc:
                    stdout, _ = await proc.communicate()
                    success = (proc.returncode == 0)

                    if success:
                        if self.cm is not None:
                            try:
                                custom_flatpaks = self.cm.get("custom_repos.flatpak", [])
                                if isinstance(custom_flatpaks, list):
                                    custom_flatpaks = [r for r in custom_flatpaks if isinstance(r, dict) and r.get("name") != name_clean]
                                    self.cm.set("custom_repos.flatpak", custom_flatpaks)
                            except Exception as cfg_err:
                                logger.error(f"Failed to update config after removing flatpak remote, attempting rollback: {cfg_err}")
                                if old_url:
                                    try:
                                        async with safe_subprocess(
                                            "flatpak", "remote-add", "--user", "--if-not-exists", name_clean, old_url,
                                            stdout=asyncio.subprocess.PIPE,
                                            stderr=asyncio.subprocess.DEVNULL
                                        ) as rb_proc:
                                            await rb_proc.communicate()
                                    except Exception as rb_err:
                                        logger.error(f"Rollback re-adding flatpak remote '{name_clean}' failed: {rb_err}")
                                await self._safe_callback(callback, f"[ERROR] Configuration persistence failed: {cfg_err}")
                                return False
                        await self._safe_callback(callback, f"[INFO] Successfully removed Flatpak remote '{name_clean}'.")
                        return True
                    else:
                        err_msg = stdout.decode("utf-8", errors="replace").strip() if stdout else "Unknown error"
                        await self._safe_callback(callback, f"[ERROR] Failed to remove remote: {err_msg}")
                        return False
            except (OSError, asyncio.SubprocessError) as e:
                logger.error(f"Exception in remove_flatpak_remote: {e}")
                await self._safe_callback(callback, f"[ERROR] Failed to remove flatpak remote: {e}")
                return False
            except Exception as e:
                logger.exception(f"Unexpected error in remove_flatpak_remote: {e}")
                raise

    # --- Pacman Custom Repositories (/etc/pacman.conf) ---

    async def list_pacman_repos(self) -> List[Dict[str, str]]:
        """
        解析 /etc/pacman.conf 获取自定义 Pacman 软件源。
        防御机制：使用 surrogateescape 确保非 UTF-8 字节不被误损坏，异常时降级返回空列表。
        """
        repos: List[Dict[str, str]] = []
        if sys.platform != "linux" or not os.path.exists("/etc/pacman.conf"):
            return repos

        try:
            with open("/etc/pacman.conf", "r", encoding="utf-8", errors="surrogateescape") as f:
                content = f.read()

            pattern = re.compile(r"^\[([^\]\s]+)\]", re.MULTILINE)
            matches = list(pattern.finditer(content))
            standard_repos = {"options", "core", "extra", "community", "multilib"}

            for i, match in enumerate(matches):
                repo_name = match.group(1).strip()
                if repo_name in standard_repos:
                    continue

                start = match.end()
                end = matches[i + 1].start() if i + 1 < len(matches) else len(content)
                block = content[start:end]

                server_match = re.search(r"^\s*Server\s*=\s*(.+)$", block, re.MULTILINE)
                url = server_match.group(1).strip() if server_match else ""

                repos.append({"name": repo_name, "url": url})
        except OSError as e:
            logger.error(f"Failed to parse pacman custom repos: {e}")
        except Exception as e:
            logger.exception(f"Unexpected error listing pacman repos: {e}")
            raise
        return repos

    async def add_pacman_repo(self, name: str, url: str, callback: Any = None) -> bool:
        """
        拒绝未签名的自定义 Pacman 软件源（Fail-closed 安全机制）。
        """
        async with self._lock:
            await self._safe_callback(
                callback,
                "[ERROR] Custom Pacman repositories are disabled until "
                "signature verification and keyring enrollment are implemented."
            )
            return False

    async def remove_pacman_repo(self, name: str, callback: Any = None) -> bool:
        """
        从 /etc/pacman.conf 中安全移除自定义源。
        防御机制：
        - 互斥锁防止并发写死锁
        - 使用 errors="surrogateescape" 无损保留非 UTF-8 字节，严禁使用 errors="replace" 写入 \ufffd 损坏文件
        - 提权准备检查
        - 原子写入与备份回滚：如果配置写失败，通过备份恢复 /etc/pacman.conf
        """
        async with self._lock:
            if not name or not isinstance(name, str) or not self._validate_name(name):
                await self._safe_callback(callback, "[ERROR] Invalid Pacman repository name.")
                return False

            name_clean = name.strip()
            normalized_name = name_clean.casefold()

            if normalized_name in self.OFFICIAL_MEO_REPOSITORIES:
                await self._safe_callback(
                    callback,
                    "[ERROR] Official Meo repositories are managed by the update "
                    "channel package (disabled). Use OmniStore's Update channel controls."
                )
                return False

            if sys.platform != "linux" or not shutil.which("pacman"):
                await self._safe_callback(callback, "[ERROR] Pacman package manager is not available.")
                return False

            await self._safe_callback(callback, "[INFO] Requesting authorization to modify /etc/pacman.conf...")

            if not self.executor or not hasattr(self.executor, "_ensure_privileged"):
                await self._safe_callback(callback, "[ERROR] Privilege executor is not available.")
                return False

            if not await self.executor._ensure_privileged(callback):
                return False

            temp_fd = None
            temp_path = None
            backup_fd = None
            backup_path = None
            try:
                if not os.path.exists("/etc/pacman.conf"):
                    await self._safe_callback(callback, "[ERROR] /etc/pacman.conf does not exist.")
                    return False

                # 使用 surrogateescape 无损保留非 UTF-8 字节
                with open("/etc/pacman.conf", "r", encoding="utf-8", errors="surrogateescape") as f:
                    conf = f.read()

                if f"[{name_clean}]" not in conf:
                    await self._safe_callback(callback, f"[WARNING] Repository [{name_clean}] does not exist in pacman.conf.")
                    return True

                pattern = re.compile(rf"^\s*\[{re.escape(name_clean)}\].*?((?=^\s*\[)|$)", re.MULTILINE | re.DOTALL)
                modified_conf = pattern.sub("", conf)
                modified_conf = re.sub(r"\n{3,}", "\n\n", modified_conf)

                # 创建旧 pacman.conf 备份文件
                backup_fd, backup_path = tempfile.mkstemp()
                with os.fdopen(backup_fd, "w", encoding="utf-8", errors="surrogateescape") as bkf:
                    bkf.write(conf)
                backup_fd = None

                # 创建修改后的 pacman.conf 临时文件
                temp_fd, temp_path = tempfile.mkstemp()
                with os.fdopen(temp_fd, "w", encoding="utf-8", errors="surrogateescape") as tmpf:
                    tmpf.write(modified_conf)
                temp_fd = None

                async with safe_subprocess(
                    "sudo", "cp", temp_path, "/etc/pacman.conf",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.STDOUT
                ) as proc:
                    await proc.communicate()
                    copy_success = (proc.returncode == 0)

                if copy_success:
                    if self.cm is not None:
                        try:
                            custom_pacman = self.cm.get("custom_repos.pacman", [])
                            if isinstance(custom_pacman, list):
                                custom_pacman = [r for r in custom_pacman if isinstance(r, dict) and r.get("name") != name_clean]
                                self.cm.set("custom_repos.pacman", custom_pacman)
                        except Exception as cfg_err:
                            logger.error(f"Failed to sync custom pacman config, restoring pacman.conf backup: {cfg_err}")
                            if backup_path and os.path.exists(backup_path):
                                try:
                                    async with safe_subprocess(
                                        "sudo", "cp", backup_path, "/etc/pacman.conf",
                                        stdout=asyncio.subprocess.PIPE,
                                        stderr=asyncio.subprocess.DEVNULL
                                    ) as rb_proc:
                                        await rb_proc.communicate()
                                except Exception as rb_err:
                                    logger.error(f"Rollback pacman.conf failed: {rb_err}")
                            await self._safe_callback(callback, f"[ERROR] Configuration persistence failed: {cfg_err}")
                            return False

                    await self._safe_callback(callback, f"[INFO] Successfully removed Pacman repository [{name_clean}]. Syncing databases...")

                    async with safe_subprocess(
                        "sudo", "pacman", "-Sy",
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.STDOUT
                    ) as sync_proc:
                        await sync_proc.communicate()
                        return True
                else:
                    await self._safe_callback(callback, "[ERROR] Failed to write /etc/pacman.conf.")
                    return False

            except (OSError, asyncio.SubprocessError) as e:
                logger.error(f"Failed to remove pacman repo: {e}")
                await self._safe_callback(callback, f"[ERROR] Failed to remove pacman repo: {e}")
                return False
            except Exception as e:
                logger.exception(f"Unexpected error in remove_pacman_repo: {e}")
                raise
            finally:
                for fd in (temp_fd, backup_fd):
                    if fd is not None:
                        try:
                            os.close(fd)
                        except Exception:
                            pass
                for path in (temp_path, backup_path):
                    if path and os.path.exists(path):
                        try:
                            os.remove(path)
                        except Exception as clean_err:
                            logger.warning(f"Failed to remove temporary file {path}: {clean_err}")

    # --- AppImage Custom Feeds ---

    def list_appimage_feeds(self) -> List[str]:
        """
        获取 AppImage 自定义订阅源列表。
        防御机制：配置读取容错，确保返回 List[str]。
        """
        if self.cm is None:
            return []
        try:
            feeds = self.cm.get("custom_repos.appimage", [])
            if isinstance(feeds, list):
                return [str(item) for item in feeds if isinstance(item, str) and item.strip()]
            return []
        except (KeyError, TypeError, ValueError) as e:
            logger.error(f"Failed to list appimage feeds: {e}")
            return []
        except Exception as e:
            logger.exception(f"Unexpected error listing appimage feeds: {e}")
            raise

    def add_appimage_feed(self, url: str) -> bool:
        """
        添加 AppImage 自定义订阅源。
        防御机制：URL 极端校验、配置写失败 Fail-closed。
        """
        if not self._validate_url(url):
            logger.warning(f"Invalid AppImage feed URL: {url}")
            return False

        if self.cm is None:
            logger.error("ConfigManager is not initialized.")
            return False

        try:
            url_clean = url.strip()
            feeds = self.list_appimage_feeds()
            if url_clean not in feeds:
                feeds.append(url_clean)
                self.cm.set("custom_repos.appimage", feeds)
                return True
            return False
        except (KeyError, TypeError, ValueError, OSError) as e:
            logger.error(f"Failed to add appimage feed: {e}")
            return False
        except Exception as e:
            logger.exception(f"Unexpected error in add_appimage_feed: {e}")
            raise

    def remove_appimage_feed(self, url: str) -> bool:
        """
        移除 AppImage 自定义订阅源。
        防御机制：入参校验与配置写失败 Fail-closed。
        """
        if not url or not isinstance(url, str):
            return False

        if self.cm is None:
            logger.error("ConfigManager is not initialized.")
            return False

        try:
            url_clean = url.strip()
            feeds = self.list_appimage_feeds()
            if url_clean in feeds:
                feeds.remove(url_clean)
                self.cm.set("custom_repos.appimage", feeds)
                return True
            return False
        except (KeyError, TypeError, ValueError, OSError) as e:
            logger.error(f"Failed to remove appimage feed: {e}")
            return False
        except Exception as e:
            logger.exception(f"Unexpected error in remove_appimage_feed: {e}")
            raise
