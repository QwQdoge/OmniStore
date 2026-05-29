import json
import asyncio
import aiohttp
import os
from pathlib import Path
from typing import Dict, List, Optional


class AIAssistant:
    """
    AI Assistant core for OmniStore.
    Handles communication with various LLM providers (Ollama, OpenAI, Gemini, etc.)
    to provide application explanations, search recommendations, and error analysis.
    """

    def __init__(self, config_manager):
        """
        Initialize the AI Assistant with a configuration manager.

        Args:
            config_manager: ConfigManager instance to fetch AI settings.
        """
        self.cm = config_manager

    def _get_ai_config(self) -> Dict:
        """Fetch AI-specific configuration from the global config."""
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
        """Determine the target language based on UI settings for localized AI responses."""
        lang = self.cm.get("ui.language", "zh-CN")
        if "zh" in lang:
            if "TW" in lang or "Hant" in lang:
                return "繁体中文 (Traditional Chinese)"
            return "简体中文 (Simplified Chinese)"
        elif "ja" in lang:
            return "日本語 (Japanese)"
        return "English"

    async def _post_request(self, system_prompt: str, user_prompt: str) -> str:
        """
        Generic POST request handler for AI providers.

        Supports:
        - Ollama (Local)
        - OpenAI (Standard API)
        - Gemini (Google AI API)
        - Custom (OpenAI-compatible proxies like Yunwu)
        """
        cfg = self._get_ai_config()
        if not cfg.get("enabled", False):
            return "AI functions are currently disabled in configuration."

        provider = cfg.get("provider", "ollama").lower()
        endpoint = cfg.get("endpoint", "").rstrip('/')
        model = cfg.get("model", "")
        api_key = cfg.get("api_key", "")
        proxy = cfg.get("proxy", "")

        headers = {"Content-Type": "application/json"}
        url = ""
        payload = {}

        # 1. Dispatch based on provider type
        if provider == "ollama":
            url = f"{endpoint}/api/generate" if endpoint else "http://localhost:11434/api/generate"
            payload = {
                "model": model or "qwen2.5:7b",
                "prompt": f"{system_prompt}\n\nUser: {user_prompt}",
                "stream": False,
                "options": {
                    "temperature": cfg.get("temperature", 0.7),
                    "num_predict": cfg.get("max_tokens", 2048)
                }
            }
        elif provider == "gemini":
            # Native Google Gemini API
            # Note: API Key is usually passed as a query parameter
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model or 'gemini-1.5-flash'}:generateContent?key={api_key}"
            payload = {
                "contents": [{
                    "role": "user",
                    "parts": [{"text": f"System Instruction: {system_prompt}\n\nUser Question: {user_prompt}"}]
                }],
                "generationConfig": {
                    "temperature": cfg.get("temperature", 0.7),
                    "maxOutputTokens": cfg.get("max_tokens", 2048)
                }
            }
        else:
            # OpenAI compatible (OpenAI, DeepSeek, Yunwu, etc.)
            url = f"{endpoint}/v1/chat/completions" if endpoint else "https://api.openai.com/v1/chat/completions"
            if api_key:
                headers["Authorization"] = f"Bearer {api_key}"

            payload = {
                "model": model or "gpt-3.5-turbo",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                "temperature": cfg.get("temperature", 0.7),
                "max_tokens": cfg.get("max_tokens", 2048),
                "stream": False
            }

        try:
            timeout = aiohttp.ClientTimeout(total=45)
            # Use proxy if configured
            connector = aiohttp.TCPConnector(ssl=False) if proxy else None

            async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
                async with session.post(url, headers=headers, json=payload, proxy=proxy or None) as resp:
                    if resp.status != 200:
                        err_text = await resp.text()
                        return f"AI Provider ({provider}) returned error status {resp.status}: {err_text}"
                    
                    data = await resp.json()

                    # 2. Extract content based on provider schema
                    if provider == "ollama":
                        return data.get("response", "").strip()
                    elif provider == "gemini":
                        candidates = data.get("candidates", [])
                        if candidates and "content" in candidates[0]:
                            parts = candidates[0]["content"].get("parts", [])
                            if parts:
                                return parts[0].get("text", "").strip()
                        return "Error: Gemini returned an unexpected response format."
                    else:
                        choices = data.get("choices", [])
                        if choices:
                            return choices[0].get("message", {}).get("content", "").strip()
                        return f"Error: Empty choices returned by {provider} compatible endpoint."

        except asyncio.TimeoutError:
            return "Error: AI request timed out (45s). Check your connection or provider status."
        except Exception as e:
            return f"Failed to connect to AI Provider ({provider}): {str(e)}"

    async def explain_app(self, app_name: str, app_description: str = "") -> str:
        """Generate a detailed explanation for a specific application."""
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant, a helpful Linux expert. Provide answers in {lang}. "
            "Explain the application requested by the user in detail. Keep it structured, clear, and professional. "
            "Include: What it does, core features, core advantages, who it is for, and why they should choose Flatpak if available."
        )
        user_prompt = f"Application: {app_name}\nDescription (if any): {app_description}"
        return await self._post_request(system_prompt, user_prompt)

    async def recommend_apps(self, query: str, available_apps: List[Dict]) -> str:
        """Analyze user intent and recommend the best matching apps from a list of candidates."""
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant, a professional software recommender. Provide response in {lang}.\n"
            "Analyze the user's natural language request and select 3 most relevant apps from the list provided.\n"
            "Priority: Flatpak > Native > AUR.\n"
            "Format your reply as a structured markdown recommendation list. For each app, explain why it fits and its highlights. "
            "If no apps in the list fit well, suggest general apps and explain why."
        )
        
        # Serialize list for context, limited to top 40 for token efficiency
        app_list_str = "\n".join([
            f"- Name: {app.get('name')}, Source: {app.get('source') or app.get('primary_source')}, Desc: {app.get('description')}" 
            for app in available_apps[:40]
        ])
        
        user_prompt = f"User Request: {query}\n\nAvailable Apps in OmniStore Database:\n{app_list_str}"
        return await self._post_request(system_prompt, user_prompt)

    async def analyze_error(self, error_log: str) -> str:
        """Analyze a technical error log and provide human-readable solutions."""
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant, an expert in Arch Linux system administration. Provide answers in {lang}. "
            "Analyze the given installation or compilation error log. Explain the root cause of the error in simple terms, "
            "and provide step-by-step instructions or terminal commands to fix it. Keep it concise."
        )
        user_prompt = f"Error log:\n{error_log}"
        return await self._post_request(system_prompt, user_prompt)

    async def compare_variants(self, app_name: str, variants: List[Dict]) -> str:
        """Compare different installation sources (Flatpak vs AUR vs Native)."""
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant. Provide response in {lang}.\n"
            "Compare the different installation variants for the requested app. "
            "Explain the pros and cons of each (e.g. Flatpak's sandboxing vs AUR's latest versions vs Native's stability). "
            "Give a final recommendation on which one the user should pick and why."
        )
        variants_str = json.dumps(variants, indent=2)
        user_prompt = f"Application: {app_name}\nVariants:\n{variants_str}"
        return await self._post_request(system_prompt, user_prompt)

    async def suggest_correction(self, query: str) -> str:
        """Suggest better search terms if the current one yields no results."""
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant. Provide response in {lang}.\n"
            "The user searched for something but got no results. Suggest 3-5 alternative keywords or correctly spelled app names. "
            "Only return the suggestions as a simple bulleted list. Be helpful and concise."
        )
        user_prompt = f"User Query: {query}"
        return await self._post_request(system_prompt, user_prompt)

    async def generate_health_report(self, system_info: Dict) -> str:
        """Generate an AI-driven system health and maintenance report."""
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant. Provide response in {lang}.\n"
            "Analyze the provided system information (orphaned packages, disk space, mirrors, etc.). "
            "Provide a 'Health Score' out of 100 and suggest maintenance actions to keep the Arch Linux system clean and fast."
        )
        info_str = json.dumps(system_info, indent=2)
        user_prompt = f"System Info:\n{info_str}"
        return await self._post_request(system_prompt, user_prompt)

    async def pick_of_the_day(self, trending_apps: List[Dict]) -> str:
        """Select one app to be the 'AI Pick of the Day' with a catchy description."""
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant. Provide response in {lang}.\n"
            "From the list of trending apps, pick ONE that is particularly interesting or useful. "
            "Write a very short, catchy 'Pick of the Day' blurb (2 sentences max) to encourage the user to try it."
        )
        apps_str = json.dumps([{"name": a.get("name"), "desc": a.get("description")} for a in trending_apps[:10]])
        user_prompt = f"Trending Apps:\n{apps_str}"
        return await self._post_request(system_prompt, user_prompt)

    async def summarize_changelog(self, app_name: str, current_ver: str, new_version: str) -> str:
        """Explain what's new in an update for a specific application."""
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant. Provide response in {lang}.\n"
            f"Summarize the key changes and improvements for {app_name} from version {current_ver} to {new_version}. "
            "Focus on features users care about. Keep it readable and bulleted."
        )
        user_prompt = f"Explain update for {app_name}: {current_ver} -> {new_version}"
        return await self._post_request(system_prompt, user_prompt)

    async def generate_cli_command(self, app_name: str, source: str) -> str:
        """Generate a terminal command to install the app manually."""
        system_prompt = (
            "You are OmniStore AI assistant. Return ONLY the single terminal command required to install the specified app from the specified source on Arch Linux. "
            "No explanation, no markdown blocks, just the raw command string."
        )
        user_prompt = f"App: {app_name}, Source: {source}"
        return await self._post_request(system_prompt, user_prompt)

    async def detect_conflicts(self, app_name: str, system_packages: List[str]) -> str:
        """Analyze if the new app might conflict with existing system packages."""
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant. Provide response in {lang}.\n"
            f"Analyze if installing '{app_name}' might cause conflicts or performance issues with existing system packages. "
            "Check for duplicate functionality or known dependency clashes."
        )
        user_prompt = f"Target App: {app_name}\nExisting Packages (subset): {', '.join(system_packages[:50])}"
        return await self._post_request(system_prompt, user_prompt)

    async def summarize_project(self) -> str:
        """Generate a concise markdown summary of the OmniStore project."""
        # Use README as the source material if available to keep summary up-to-date
        root_dir = Path(__file__).resolve().parents[3]
        readme_path = root_dir / "README.md"
        readme_text = ""
        if readme_path.exists():
            try:
                readme_text = readme_path.read_text(encoding="utf-8")
            except Exception:
                pass

        system_prompt = (
            "You are OmniStore AI assistant. Summarize the OmniStore project in concise markdown, covering its purpose, main features, and architecture."
        )
        user_prompt = f"Project README:\n{readme_text}" if readme_text else "Provide a brief summary of OmniStore based on your knowledge."
        return await self._post_request(system_prompt, user_prompt)
