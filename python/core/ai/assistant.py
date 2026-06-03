import json
import asyncio
import aiohttp
import os
import re
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

    def _extract_json(self, text: str) -> str:
        """
        Extract JSON content from a messy AI response string.
        Looks for blocks starting with ###JSON_START### or just standard [ ] blocks.
        """
        # Try explicit marker first
        if "###JSON_START###" in text:
            parts = text.split("###JSON_START###")
            if len(parts) > 1:
                return parts[-1].strip()

        # Fallback to finding the last [ ] block
        try:
            start_idx = text.rfind('[')
            end_idx = text.rfind(']')
            if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
                return text[start_idx:end_idx+1]
        except:
            pass

        return text

    async def _post_request(self, system_prompt: str, user_prompt: str, is_json_request: bool = False) -> str:
        """
        Generic POST request handler for AI providers.
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
            if not endpoint and provider != "gemini":
                return f"Error: AI Endpoint is not configured for {provider}."

            timeout = aiohttp.ClientTimeout(total=45)
            connector = aiohttp.TCPConnector(ssl=False) if proxy else None

            async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
                async with session.post(url, headers=headers, json=payload, proxy=proxy or None) as resp:
                    if resp.status != 200:
                        err_text = await resp.text()
                        return f"AI Provider ({provider}) returned error status {resp.status}: {err_text}"
                    
                    data = await resp.json()
                    response_text = ""

                    if provider == "ollama":
                        response_text = data.get("response", "").strip()
                    elif provider == "gemini":
                        candidates = data.get("candidates", [])
                        if candidates and "content" in candidates[0]:
                            parts = candidates[0]["content"].get("parts", [])
                            if parts:
                                response_text = parts[0].get("text", "").strip()
                    else:
                        choices = data.get("choices", [])
                        if choices:
                            response_text = choices[0].get("message", {}).get("content", "").strip()

                    if is_json_request:
                        return self._extract_json(response_text)
                    return response_text

        except asyncio.TimeoutError:
            return "Error: AI request timed out (45s)."
        except Exception as e:
            return f"Failed to connect to AI Provider ({provider}): {str(e)}"

    async def explain_app(self, app_name: str, app_description: str = "") -> str:
        """Generate a detailed explanation for a specific application."""
        lang = self._get_language()
        system_prompt = (
            f"You are the OmniStore Expert. Provide responses in {lang}.\n"
            "Explain specifically why this app exists and how it improves a user's workflow."
        )
        user_prompt = f"Expert overview of '{app_name}'. Context: {app_description}"
        return await self._post_request(system_prompt, user_prompt)

    async def recommend_apps(self, query: str, available_apps: List[Dict]) -> str:
        """Analyze user intent and recommend the best matching apps."""
        lang = self._get_language()
        system_prompt = (
            f"You are the OmniStore Software Curator. Provide response in {lang}.\n"
            "Select the 3 best apps from the list. Priority: Flatpak > Native > AUR.\n"
            "MANDATORY: You MUST include exactly one JSON array of app names at the very end of your response, prefixed with ###JSON_START###."
        )
        app_list_str = "\n".join([f"- {app.get('name')}: {app.get('description')}" for app in available_apps[:40]])
        user_prompt = f"User Request: {query}\n\nAvailable Apps:\n{app_list_str}"
        return await self._post_request(system_prompt, user_prompt)

    async def analyze_error(self, error_log: str) -> str:
        """Analyze a technical error log."""
        lang = self._get_language()
        system_prompt = f"You are the OmniStore System Diagnostician. Provide response in {lang}.\nExplain the root cause and provide exact commands to fix it."
        user_prompt = f"Error Log:\n{error_log}"
        return await self._post_request(system_prompt, user_prompt)

    async def compare_variants(self, app_name: str, variants: List[Dict]) -> str:
        """Compare different installation sources."""
        lang = self._get_language()
        system_prompt = f"You are OmniStore AI assistant. Provide response in {lang}.\nCompare variants (Flatpak vs AUR vs Native) and give a final recommendation."
        variants_str = json.dumps(variants)
        user_prompt = f"App: {app_name}\nVariants: {variants_str}"
        return await self._post_request(system_prompt, user_prompt)

    async def suggest_correction(self, query: str) -> str:
        """Suggest better search terms."""
        lang = self._get_language()
        system_prompt = f"You are OmniStore AI assistant. Provide response in {lang}.\nSuggest 3-5 alternative keywords as a JSON array prefixed with ###JSON_START###."
        user_prompt = f"Query: {query}"
        return await self._post_request(system_prompt, user_prompt, is_json_request=True)

    async def pick_of_the_day(self, trending_apps: List[Dict]) -> str:
        """Select one app as 'AI Pick of the Day'."""
        lang = self._get_language()
        system_prompt = (
            f"You are the OmniStore Software Curator. Provide response in {lang}.\n"
            "Select one compelling app. End with a JSON array containing ONLY the app name, prefixed with ###JSON_START###."
        )
        apps_str = json.dumps([{"name": a.get("name"), "desc": a.get("description")} for a in trending_apps[:15]])
        user_prompt = f"Candidates: {apps_str}"
        return await self._post_request(system_prompt, user_prompt)

    async def summarize_changelog(self, app_name: str, current_ver: str, new_version: str) -> str:
        """Explain what's new in an update."""
        lang = self._get_language()
        system_prompt = f"You are the OmniStore Expert Curator. Provide response in {lang}.\nSummarize the human impact of updating '{app_name}' from {current_ver} to {new_version}."
        user_prompt = f"Update: {current_ver} -> {new_version}"
        return await self._post_request(system_prompt, user_prompt)

    async def generate_cli_command(self, app_name: str, source: str) -> str:
        """Generate a terminal command to install the app."""
        system_prompt = "Return ONLY the raw terminal command to install the app from the source on Arch Linux. No markdown."
        user_prompt = f"App: {app_name}, Source: {source}"
        return await self._post_request(system_prompt, user_prompt)

    async def detect_conflicts(self, app_name: str, system_packages: List[str]) -> str:
        """Detect potential conflicts."""
        lang = self._get_language()
        system_prompt = f"You are OmniStore AI assistant. Provide response in {lang}.\nAnalyze if '{app_name}' might conflict with system packages."
        user_prompt = f"App: {app_name}\nSystem Packages: {', '.join(system_packages[:40])}"
        return await self._post_request(system_prompt, user_prompt)
