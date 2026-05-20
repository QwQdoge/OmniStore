import json
import aiohttp
from typing import Dict, List, Optional


class AIAssistant:
    def __init__(self, config_manager):
        self.cm = config_manager

    def _get_ai_config(self) -> Dict:
        return self.cm.get("ai", {
            "enabled": False,
            "provider": "ollama",
            "endpoint": "http://localhost:11434",
            "model": "qwen2.5:7b",
            "api_key": ""
        })

    def _get_language(self) -> str:
        lang = self.cm.get("ui.language", "zh-CN")
        if "zh" in lang:
            if "TW" in lang or "Hant" in lang:
                return "繁体中文 (Traditional Chinese)"
            return "简体中文 (Simplified Chinese)"
        elif "ja" in lang:
            return "日本語 (Japanese)"
        return "English"

    async def _post_request(self, system_prompt: str, user_prompt: str) -> str:
        cfg = self._get_ai_config()
        if not cfg.get("enabled", False):
            return "AI functions are currently disabled in configuration."

        provider = cfg.get("provider", "ollama").lower()
        endpoint = cfg.get("endpoint", "").rstrip('/')
        model = cfg.get("model", "")
        api_key = cfg.get("api_key", "")

        # Prepare headers & body based on provider
        headers = {"Content-Type": "application/json"}
        
        if provider == "ollama":
            url = f"{endpoint}/api/generate"
            payload = {
                "model": model,
                "prompt": f"{system_prompt}\n\nUser: {user_prompt}",
                "stream": False
            }
            # Ollama response path is json_data['response']
        else:  # openai compatible
            url = f"{endpoint}/v1/chat/completions"
            if api_key:
                headers["Authorization"] = f"Bearer {api_key}"
            payload = {
                "model": model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                "stream": False
            }
            # OpenAI response path is json_data['choices'][0]['message']['content']

        try:
            # Set a standard timeout
            timeout = aiohttp.ClientTimeout(total=45)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(url, headers=headers, json=payload) as resp:
                    if resp.status != 200:
                        err_text = await resp.text()
                        return f"AI Provider returned error status {resp.status}: {err_text}"
                    
                    data = await resp.json()
                    if provider == "ollama":
                        return data.get("response", "").strip()
                    else:
                        choices = data.get("choices", [])
                        if choices:
                            return choices[0].get("message", {}).get("content", "").strip()
                        return "Error: Empty choices returned by OpenAI compatible endpoint."
        except Exception as e:
            return f"Failed to connect to AI Provider: {str(e)}"

    async def explain_app(self, app_name: str, app_description: str = "") -> str:
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant, a helpful app expert. Provide answers in {lang}. "
            "Explain the application requested by the user. Keep it structured, clear, and professional. "
            "Include: What it does, core features, who it is for, and a brief safety/reliability review."
        )
        user_prompt = f"Application: {app_name}\nDescription (if any): {app_description}"
        return await self._post_request(system_prompt, user_prompt)

    async def recommend_apps(self, query: str, available_apps: List[Dict]) -> str:
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant, an application recommender. Provide response in {lang}.\n"
            "Analyze the user's natural language request and select the most relevant apps from the list provided.\n"
            "Format your reply as a structured markdown recommendation list. If no apps in the list fit well, suggest general apps "
            "that the user can look up, and briefly explain why."
        )
        
        # Serialize list for context
        app_list_str = "\n".join([
            f"- Name: {app.get('name')}, Source: {app.get('source') or app.get('primary_source')}, Desc: {app.get('description')}" 
            for app in available_apps[:40]
        ])
        
        user_prompt = f"User Request: {query}\n\nAvailable Apps in OmniStore Database:\n{app_list_str}"
        return await self._post_request(system_prompt, user_prompt)

    async def analyze_error(self, error_log: str) -> str:
        lang = self._get_language()
        system_prompt = (
            f"You are OmniStore AI assistant, an expert in Arch Linux system administration. Provide answers in {lang}. "
            "Analyze the given installation or compilation error log. Explain the root cause of the error in simple terms, "
            "and provide step-by-step instructions or terminal commands to fix it. Keep it concise."
        )
        user_prompt = f"Error log:\n{error_log}"
        return await self._post_request(system_prompt, user_prompt)
