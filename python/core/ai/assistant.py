import json
import asyncio
import aiohttp
import logging
import os
import re
from pathlib import Path
from typing import Dict, List, Optional
from pydantic import ValidationError
from core.models import InstallationDecision


import time


class AIProviderError(RuntimeError):
    """A user-safe provider failure with a stable machine-readable code."""

    def __init__(self, code: str, message: str, suggestion: str = ""):
        super().__init__(message)
        self.code = code
        self.message = message
        self.suggestion = suggestion

class AIAssistant:
    """
    AI Assistant core for OmniStore.
    Handles communication with various LLM providers with high resilience.
    Ensures zero-hang execution and graceful failure modes.
    """

    def __init__(self, config_manager):
        self.cm = config_manager
        self._session: Optional[aiohttp.ClientSession] = None
        # Murphy-proof: Circuit breaker state
        self._failure_count = 0
        self._last_failure_time = 0
        self._circuit_threshold = 3
        self._cooldown_period = 60 # seconds
        self._circuit_config_key = ""

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
        cfg = dict(self.cm.get("ai", {
            "enabled": False,
            "provider": "ollama",
            "endpoint": "http://localhost:11434",
            "model": "qwen2.5:7b",
            "api_key": "",
            "temperature": 0.7,
            "max_tokens": 2048,
            "proxy": ""
        }))
        env_overrides = {
            "enabled": os.environ.get("OMNISTORE_AI_ENABLED"),
            "provider": os.environ.get("OMNISTORE_AI_PROVIDER"),
            "endpoint": os.environ.get("OMNISTORE_AI_ENDPOINT"),
            "model": os.environ.get("OMNISTORE_AI_MODEL"),
            "api_key": os.environ.get("OMNISTORE_AI_API_KEY"),
            "temperature": os.environ.get("OMNISTORE_AI_TEMPERATURE"),
            "max_tokens": os.environ.get("OMNISTORE_AI_MAX_TOKENS"),
            "proxy": os.environ.get("OMNISTORE_AI_PROXY"),
        }
        for key, value in env_overrides.items():
            if value in (None, ""):
                continue
            if key == "enabled":
                cfg[key] = str(value).lower() in {"1", "true", "yes", "on"}
            elif key == "temperature":
                try:
                    cfg[key] = float(value)
                except ValueError:
                    pass
            elif key == "max_tokens":
                try:
                    cfg[key] = int(value)
                except ValueError:
                    pass
            else:
                cfg[key] = value
        return cfg

    def _redact_sensitive(self, text: str) -> str:
        """Redact likely API keys from provider errors before logging."""
        if not text:
            return text
        text = re.sub(r"sk-[A-Za-z0-9_\-]{12,}", "sk-***", text)
        text = re.sub(r"(Bearer\s+)[A-Za-z0-9_\-\.]{12,}", r"\1***", text, flags=re.IGNORECASE)
        return text

    def _get_language(self) -> str:
        lang = str(self.cm.get("ui.language", "zh-CN"))
        if "zh" in lang:
            return "繁体中文" if ("TW" in lang or "Hant" in lang) else "简体中文"
        if "ja" in lang: return "日本語"
        if "es" in lang: return "Español"
        return "English"

    def _is_circuit_open(self) -> bool:
        """Check if the AI circuit breaker is currently open."""
        if self._failure_count >= self._circuit_threshold:
            elapsed = time.time() - self._last_failure_time
            if elapsed < self._cooldown_period:
                return True
            else:
                # Cooldown period passed, reset circuit
                self._failure_count = 0
        return False

    @staticmethod
    def _openai_url(endpoint: str, suffix: str) -> str:
        base = (endpoint or "https://api.openai.com/v1").rstrip("/")
        if base.endswith("/chat/completions"):
            base = base.removesuffix("/chat/completions")
        if not base.endswith("/v1"):
            base = f"{base}/v1"
        return f"{base}/{suffix.lstrip('/')}"

    @staticmethod
    def _friendly_http_error(status: int) -> tuple[str, str]:
        if status in (401, 403):
            return "authentication_failed", "认证失败，请检查 API 密钥是否有效。"
        if status == 404:
            return "model_or_endpoint_not_found", "接口或模型不存在，请检查地址和模型名称。"
        if status == 429:
            return "rate_limited", "服务商限流或额度不足，请稍后重试并检查账户额度。"
        if status >= 500:
            return "provider_unavailable", "AI 服务商暂时不可用，请稍后重试。"
        return "provider_rejected_request", f"AI 服务商拒绝了请求（HTTP {status}）。"

    def _circuit_key(self, cfg: Dict) -> str:
        return "|".join(str(cfg.get(key, "")) for key in ("provider", "endpoint", "model"))

    async def diagnose_connection(self) -> Dict:
        """Check provider reachability and model readiness without exposing secrets."""
        started = time.monotonic()
        cfg = self._get_ai_config()
        provider = str(cfg.get("provider", "ollama")).lower().strip()
        endpoint = str(cfg.get("endpoint", "")).strip().rstrip("/")
        model = str(cfg.get("model", "")).strip()
        api_key = str(cfg.get("api_key", ""))
        proxy = str(cfg.get("proxy", "")) or None
        result = {
            "ok": False,
            "provider": provider,
            "endpoint": endpoint,
            "model": model,
            "service_reachable": False,
            "model_ready": False,
            "models": [],
            "code": "unknown",
            "message": "AI 连接检查失败。",
            "suggestion": "",
        }

        if not cfg.get("enabled", False):
            result.update(code="disabled", message="AI 功能尚未启用。", suggestion="请先开启 AI 功能。")
            return result
        if provider not in {"ollama", "openai", "gemini"}:
            result.update(code="unsupported_provider", message=f"不支持的 AI 服务商：{provider}。")
            return result
        if provider != "ollama" and not api_key:
            result.update(code="missing_api_key", message="尚未保存 API 密钥。", suggestion="请填写密钥后重试。")
            return result

        headers = {"Accept": "application/json"}
        if provider == "openai" and api_key:
            headers["Authorization"] = f"Bearer {api_key}"
        try:
            session = await self._get_session()
            if provider == "ollama":
                url = f"{endpoint or 'http://localhost:11434'}/api/tags"
                async with session.get(url, headers=headers, proxy=proxy) as resp:
                    if resp.status != 200:
                        code, message = self._friendly_http_error(resp.status)
                        result.update(code=code, message=message)
                        return result
                    data = await resp.json()
                models = [str(item.get("name", "")) for item in data.get("models", []) if isinstance(item, dict)]
                result["service_reachable"] = True
                result["models"] = models
                result["model_ready"] = bool(model and (model in models or any(name.split(":")[0] == model for name in models)))
                if not model:
                    result.update(code="missing_model", message="Ollama 已连接，但尚未选择模型。", suggestion="请选择或下载一个模型。")
                elif not result["model_ready"]:
                    result.update(code="model_not_installed", message=f"Ollama 已连接，但模型 {model} 尚未下载。", suggestion=f"运行 ollama pull {model}，或选择已安装模型。")
                else:
                    result.update(ok=True, code="ready", message="Ollama 和所选模型均已就绪。")
            elif provider == "openai":
                url = self._openai_url(endpoint, "models")
                async with session.get(url, headers=headers, proxy=proxy) as resp:
                    if resp.status != 200:
                        code, message = self._friendly_http_error(resp.status)
                        result.update(code=code, message=message)
                        return result
                    data = await resp.json()
                models = [str(item.get("id", "")) for item in data.get("data", []) if isinstance(item, dict)]
                result["service_reachable"] = True
                result["models"] = models[:200]
                result["model_ready"] = bool(model and (not models or model in models))
                if not model:
                    result.update(code="missing_model", message="服务已连接，但尚未填写模型名称。")
                elif models and model not in models:
                    result.update(code="model_not_found", message=f"服务已连接，但未找到模型 {model}。", suggestion="请从服务商支持的模型中选择。")
                else:
                    result.update(ok=True, code="ready", message="OpenAI-compatible 服务和模型均已就绪。")
            else:
                selected = model or "gemini-1.5-flash"
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{selected}?key={api_key}"
                async with session.get(url, proxy=proxy) as resp:
                    if resp.status != 200:
                        code, message = self._friendly_http_error(resp.status)
                        result.update(code=code, message=message)
                        return result
                result.update(ok=True, service_reachable=True, model_ready=True, model=selected, code="ready", message="Gemini 服务和模型均已就绪。")
        except asyncio.TimeoutError:
            result.update(code="timeout", message="连接 AI 服务超时。", suggestion="请检查网络、代理或本地服务状态。")
        except aiohttp.ClientConnectorError:
            result.update(code="connection_refused", message="无法连接到 AI 服务。", suggestion="如果使用 Ollama，请先启动 ollama serve；云端服务请检查地址和网络。")
        except (aiohttp.ClientError, ValueError, TypeError, json.JSONDecodeError):
            result.update(code="invalid_response", message="AI 服务返回了无法识别的响应。", suggestion="请检查接口是否兼容 OpenAI API。")
        finally:
            result["latency_ms"] = round((time.monotonic() - started) * 1000)
        return result

    async def _post_request(self, system_prompt: str, user_prompt: str) -> str:
        """
        Generic POST request handler with circuit-breaker-like resilience.
        """
        if self._is_circuit_open():
            return "AI 服务暂时不可用（触发熔断）。请在 60 秒后再试。"

        cfg = self._get_ai_config()
        circuit_key = self._circuit_key(cfg)
        if circuit_key != self._circuit_config_key:
            self._circuit_config_key = circuit_key
            self._failure_count = 0
        if not cfg.get("enabled", False):
            return "AI 服务当前未启用。请在设置中开启以使用智能功能。"

        provider = str(cfg.get("provider", "ollama")).lower()
        endpoint = str(cfg.get("endpoint", "")).rstrip('/')
        model = str(cfg.get("model", ""))
        api_key = str(cfg.get("api_key", ""))
        if api_key == "******":
            api_key = os.environ.get("OMNISTORE_AI_API_KEY", "")
        proxy = str(cfg.get("proxy", ""))

        headers = {"Content-Type": "application/json"}
        url, payload = "", {}

        # 1. Provider Logic Mapping
        try:
            if provider == "ollama":
                url = f"{endpoint}/api/chat" if endpoint else "http://localhost:11434/api/chat"
                payload = {
                    "model": model or "qwen2.5:7b",
                    "messages": [{"role": "system", "content": system_prompt}, {"role": "user", "content": user_prompt}],
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
                if endpoint:
                    url = self._openai_url(endpoint, "chat/completions")
                else:
                    url = "https://api.openai.com/v1/chat/completions"
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
                    self._failure_count += 1
                    self._last_failure_time = time.time()
                    err_body = self._redact_sensitive(await resp.text())
                    logging.error(f"AI Provider Error ({resp.status}): {err_body}")
                    return f"AI 服务商返回错误 ({resp.status})。请检查 API 密钥或网络连接。"

                try:
                    data = await resp.json()
                except Exception as json_err:
                    self._failure_count += 1
                    self._last_failure_time = time.time()
                    raw_txt = self._redact_sensitive(await resp.text())
                    logging.error(f"AI response JSON decode error: {json_err}. Raw text: {raw_txt[:200]}")
                    return "AI 服务商返回了无法解析的数据格式。"

                if not isinstance(data, dict):
                    self._failure_count += 1
                    self._last_failure_time = time.time()
                    return "AI 服务商返回的数据结构异常。"

                # Success: reset circuit
                self._failure_count = 0
                if provider == "ollama":
                    message = data.get("message")
                    return str(message.get("content") if isinstance(message, dict) else "").strip()
                if provider == "gemini":
                    candidates = data.get("candidates")
                    if isinstance(candidates, list) and candidates:
                        parts = candidates[0].get("content", {}).get("parts", []) if isinstance(candidates[0], dict) else []
                        if parts and isinstance(parts, list) and isinstance(parts[0], dict):
                            return str(parts[0].get("text") or "").strip()
                    return "Gemini 未能生成有效回复。"

                choices = data.get("choices")
                if isinstance(choices, list) and choices and isinstance(choices[0], dict):
                    msg = choices[0].get("message")
                    if isinstance(msg, dict):
                        return str(msg.get("content") or "").strip()
                return "AI 服务商未返回有效内容。"

        except asyncio.TimeoutError:
            self._failure_count += 1
            self._last_failure_time = time.time()
            return "AI 请求超时（45秒）。这可能是由于网络不稳定或本地模型加载过慢导致的。"
        except Exception as e:
            self._failure_count += 1
            self._last_failure_time = time.time()
            logging.error("AI connection failed for provider %s: %s", provider, type(e).__name__)
            return f"无法连接到 AI 服务商 ({provider})。请检查服务地址、网络和运行状态。"

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

    def _fallback_installation_decision(self, variants: List[Dict]) -> InstallationDecision:
        """Deterministic source selection used when AI is disabled or unreliable."""
        names = [str(v.get("source", "")) for v in variants if isinstance(v, dict)]
        preferred = next(
            (
                source
                for source in (
                    "Flatpak",
                    "Winget",
                    "Native",
                    "Pacman",
                    "Scoop",
                    "Chocolatey",
                    "AUR",
                    "AppImage",
                )
                if source in names
            ),
            None,
        )
        return InstallationDecision(
            recommendedVariant=preferred,
            reasons=["Uses OmniStore's deterministic source priority."],
            risks=["Review the publisher and requested permissions before installing."],
            alternatives=[source for source in names if source != preferred][:3],
            preflightChecks=["Confirm available disk space.", "Confirm the selected source is enabled."],
        )

    async def installation_decision(self, app_name: str, variants: List[Dict]) -> InstallationDecision:
        fallback = self._fallback_installation_decision(variants)
        if not variants or not self._get_ai_config().get("enabled", False):
            return fallback
        lang = self._get_language()
        system = (f"You are OmniStore's install decision assistant. Respond in {lang}. "
                  "Return only one JSON object with exactly these keys: recommendedVariant, reasons, risks, alternatives, preflightChecks. "
                  "All values except recommendedVariant must be arrays of short strings. Only recommend a source present in variants.")
        response = await self._post_request(system, json.dumps({"app": app_name, "variants": variants[:10]}))
        try:
            match = re.search(r"\{.*\}", response, re.DOTALL)
            parsed = InstallationDecision.model_validate(json.loads(match.group(0) if match else response))
            if parsed.recommendedVariant not in {str(v.get("source")) for v in variants if isinstance(v, dict)}:
                raise ValueError("AI recommended an unavailable source")
            return parsed
        except (ValueError, TypeError, json.JSONDecodeError, ValidationError):
            return fallback

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
        except Exception: readme = ""
        system = "Summarize the OmniStore project in concise markdown."
        return await self._post_request(system, f"README:\n{readme}" if readme else "OmniStore project summary.")

    async def test_connection(self) -> Dict:
        """Return structured, non-secret connection diagnostics."""
        return await self.diagnose_connection()
