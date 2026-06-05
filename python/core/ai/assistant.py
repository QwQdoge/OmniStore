import json
import asyncio
import aiohttp
import os
import logging
from pathlib import Path
from typing import Dict, List, Optional


class AIAssistant:
    """
    AI Assistant core for OmniStore.
    Handles communication with various LLM providers with high resilience.
    Ensures zero-hang execution and graceful failure modes.
    """

    def __init__(self, config_manager):
        self.cm = config_manager
        self._session: Optional[aiohttp.ClientSession] = None

    async def _get_session(self) -> aiohttp.ClientSession:
        """Lazy session initialization with proper timeout defaults."""
        if self._session is None or self._session.closed:
            timeout = aiohttp.ClientTimeout(total=45, connect=10)
            self._session = aiohttp.ClientSession(timeout=timeout)
        return self._session

    async def close(self):
        """Explicitly close the session to prevent memory/connection leaks."""
        if self._session and not self._session.closed:
            await self._session.close()
            self._session = None

    def _get_ai_config(self) -> Dict:
        """Fetch AI-specific configuration with safe defaults."""
        return self.cm.get("ai", {
            "enabled": False,
            "provider": "ollama",
            "endpoint": "http://localhost:11434",
            "model": "qwen2.5:7b",
            "api_key": "",
            "temperature": 0.7,
            "max_tokens": 2048,
            "proxy": ""
        })

    def _get_language(self) -> str:
        lang = str(self.cm.get("ui.language", "zh-CN"))
        if "zh" in lang:
            return "繁体中文" if ("TW" in lang or "Hant" in lang) else "简体中文"
        if "ja" in lang: return "日本語"
        if "es" in lang: return "Español"
        return "English"

    async def _post_request(self, system_prompt: str, user_prompt: str) -> str:
        """
        Generic POST request handler with circuit-breaker-like resilience.
        """
        cfg = self._get_ai_config()
        if not cfg.get("enabled", False):
            return "AI 服务当前未启用。请在设置中开启以使用智能功能。"

        provider = str(cfg.get("provider", "ollama")).lower()
        endpoint = str(cfg.get("endpoint", "")).rstrip('/')
        model = str(cfg.get("model", ""))
        api_key = str(cfg.get("api_key", ""))
        proxy = str(cfg.get("proxy", ""))

        headers = {"Content-Type": "application/json"}
        url, payload = "", {}

        # 1. Provider Logic Mapping
        try:
            if provider == "ollama":
                url = f"{endpoint}/api/generate" if endpoint else "http://localhost:11434/api/generate"
                payload = {
                    "model": model or "qwen2.5:7b",
                    "prompt": f"{system_prompt}\n\nUser: {user_prompt}",
                    "stream": False,
                    "options": {"temperature": cfg.get("temperature", 0.7), "num_predict": cfg.get("max_tokens", 2048)}
                }
            elif provider == "gemini":
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{model or 'gemini-1.5-flash'}:generateContent?key={api_key}"
                payload = {
                    "contents": [{"role": "user", "parts": [{"text": f"Instruction: {system_prompt}\n\nUser: {user_prompt}"}]}],
                    "generationConfig": {"temperature": cfg.get("temperature", 0.7), "maxOutputTokens": cfg.get("max_tokens", 2048)}
                }
            else: # OpenAI Compatible
                url = f"{endpoint}/v1/chat/completions" if endpoint else "https://api.openai.com/v1/chat/completions"
                if api_key: headers["Authorization"] = f"Bearer {api_key}"
                payload = {
                    "model": model or "gpt-3.5-turbo",
                    "messages": [{"role": "system", "content": system_prompt}, {"role": "user", "content": user_prompt}],
                    "temperature": cfg.get("temperature", 0.7), "max_tokens": cfg.get("max_tokens", 2048), "stream": False
                }

            # 2. Resilient Execution
            session = await self._get_session()
            async with session.post(url, headers=headers, json=payload, proxy=proxy or None) as resp:
                if resp.status != 200:
                    err_body = await resp.text()
                    logging.error(f"AI Provider Error ({resp.status}): {err_body}")
                    return f"AI 服务商返回错误 ({resp.status})。请检查 API 密钥或网络连接。"

                data = await resp.json()
                if provider == "ollama": return data.get("response", "").strip()
                if provider == "gemini":
                    parts = data.get("candidates", [{}])[0].get("content", {}).get("parts", [])
                    return parts[0].get("text", "").strip() if parts else "Gemini 未能生成有效回复。"
                return data.get("choices", [{}])[0].get("message", {}).get("content", "").strip()

        except asyncio.TimeoutError:
            return "AI 请求超时（45秒）。这可能是由于网络不稳定或本地模型加载过慢导致的。"
        except Exception as e:
            logging.error(f"AI Connection Failed: {e}")
            return f"无法连接到 AI 服务商 ({provider}): {str(e)}"

    async def explain_app(self, app_name: str, app_description: str = "") -> str:
        """Fail-safe app explanation."""
        if not app_name: return "无效的应用名称。"
        lang = self._get_language()
        system = f"You are the OmniStore Expert. Provide responses in {lang}. Explain the purpose and value of the app professionally."
        user = f"Overview for '{app_name}'. Context: {app_description}"
        return await self._post_request(system, user)

    async def recommend_apps(self, query: str, available_apps: List[Dict]) -> str:
        """Resilient recommendation with fallback."""
        if not query: return "请输入搜索关键词。"
        lang = self._get_language()
        system = (f"You are the OmniStore Software Curator. Language: {lang}. Recommend 3 apps. "
                  "Include ###JSON_START### followed by a JSON array of names at the end.")
        app_list = "\n".join([f"- {a.get('name')} ({a.get('source')}): {a.get('description')}" for a in available_apps[:30]])
        user = f"Query: {query}\nDatabase:\n{app_list}"
        return await self._post_request(system, user)

    async def analyze_error(self, error_log: str) -> str:
        if not error_log: return "无可用错误日志。"
        lang = self._get_language()
        system = f"You are the OmniStore Diagnostician. Language: {lang}. Analyze the log and provide a clear solution."
        return await self._post_request(system, error_log)

    async def compare_variants(self, app_name: str, variants: List[Dict]) -> str:
        lang = self._get_language()
        system = f"You are OmniStore AI. Language: {lang}. Compare variants (Flatpak vs AUR vs Native) and recommend one."
        return await self._post_request(system, f"App: {app_name}, Variants: {json.dumps(variants)}")

    async def suggest_correction(self, query: str) -> str:
        lang = self._get_language()
        system = f"You are OmniStore AI. Language: {lang}. Suggest 3-5 alternative keywords. End with ###JSON_START### and a JSON array."
        return await self._post_request(system, f"No results for: {query}")

    async def generate_health_report(self, system_info: Dict) -> str:
        lang = self._get_language()
        system = f"You are OmniStore AI. Language: {lang}. Generate a health report with a score and maintenance tips."
        return await self._post_request(system, f"System Info: {json.dumps(system_info)}")

    async def pick_of_the_day(self, trending_apps: List[Dict]) -> str:
        lang = self._get_language()
        system = (f"You are the Curator. Language: {lang}. Pick one app of the day. "
                  "End with ###JSON_START### and a JSON array [\"name\"].")
        apps = [{"name": a.get("name"), "desc": a.get("description")} for a in trending_apps[:15]]
        return await self._post_request(system, f"Candidates: {json.dumps(apps)}")

    async def summarize_changelog(self, app_name: str, cur: str, new: str) -> str:
        lang = self._get_language()
        system = f"You are the Curator. Language: {lang}. Summarize what's new in {app_name} ({cur} -> {new})."
        return await self._post_request(system, f"Update {app_name}: {cur} to {new}")

    async def generate_cli_command(self, app_name: str, source: str) -> str:
        system = "Return ONLY the terminal command for Arch Linux. No markdown, no explanation."
        return await self._post_request(system, f"Install {app_name} via {source}")

    async def detect_conflicts(self, app_name: str, sys_pkgs: List[str]) -> str:
        lang = self._get_language()
        system = f"You are OmniStore AI. Language: {lang}. Detect conflicts for {app_name}."
        return await self._post_request(system, f"App: {app_name}, System (subset): {', '.join(sys_pkgs[:50])}")

    async def summarize_project(self) -> str:
        try:
            readme = (Path(__file__).resolve().parents[3] / "README.md").read_text(encoding="utf-8")
        except: readme = ""
        system = "Summarize the OmniStore project in concise markdown."
        return await self._post_request(system, f"README:\n{readme}" if readme else "OmniStore project summary.")
