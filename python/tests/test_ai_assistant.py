import pytest
from aiohttp import web

from core.ai.assistant import AIAssistant


class DummyConfig:
    def __init__(self, config=None):
        self.config = config or {}

    def get(self, key, default=None):
        if key == "ai":
            return self.config.get("ai", default)
        if key == "ui.language":
            return self.config.get("ui", {}).get("language", "zh-CN")
        return default


@pytest.mark.asyncio
async def test_openai_compatible_env_overrides(monkeypatch):
    seen = {}

    async def chat_completions(request):
        seen["path"] = request.path
        seen["auth"] = request.headers.get("Authorization")
        seen["payload"] = await request.json()
        return web.json_response(
            {"choices": [{"message": {"content": "CONNECTION_OK"}}]}
        )

    app = web.Application()
    app.router.add_post("/v1/chat/completions", chat_completions)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0)
    await site.start()
    port = site._server.sockets[0].getsockname()[1]

    monkeypatch.setenv("OMNISTORE_AI_ENABLED", "true")
    monkeypatch.setenv("OMNISTORE_AI_PROVIDER", "openai")
    monkeypatch.setenv("OMNISTORE_AI_ENDPOINT", f"http://127.0.0.1:{port}/v1")
    monkeypatch.setenv("OMNISTORE_AI_MODEL", "test-model")
    monkeypatch.setenv("OMNISTORE_AI_API_KEY", "test-key")

    assistant = AIAssistant(DummyConfig())
    try:
        assert await assistant.test_connection() == "success"
    finally:
        await assistant.close()
        await runner.cleanup()

    assert seen["path"] == "/v1/chat/completions"
    assert seen["auth"] == "Bearer test-key"
    assert seen["payload"]["model"] == "test-model"
    assert seen["payload"]["messages"][0]["role"] == "system"


@pytest.mark.asyncio
async def test_all_ai_assistant_features_call_provider(monkeypatch):
    calls = []

    async def chat_completions(request):
        payload = await request.json()
        calls.append(payload)
        system = payload["messages"][0]["content"]
        if "connection tester" in system:
            content = "CONNECTION_OK"
        elif "terminal command" in system:
            content = "pacman -S example"
        elif "alternative keywords" in system:
            content = 'try example\n###JSON_START### ["example"]'
        elif "Pick one app" in system:
            content = 'Daily pick\nPICK_JSON: ["Example"]'
        elif "Recommend 3 apps" in system:
            content = 'Recommended apps\n###JSON_START### ["Example"]'
        else:
            content = "AI_OK"
        return web.json_response({"choices": [{"message": {"content": content}}]})

    app = web.Application()
    app.router.add_post("/v1/chat/completions", chat_completions)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0)
    await site.start()
    port = site._server.sockets[0].getsockname()[1]

    monkeypatch.setenv("OMNISTORE_AI_ENABLED", "true")
    monkeypatch.setenv("OMNISTORE_AI_PROVIDER", "openai")
    monkeypatch.setenv("OMNISTORE_AI_ENDPOINT", f"http://127.0.0.1:{port}/v1")
    monkeypatch.setenv("OMNISTORE_AI_MODEL", "test-model")
    monkeypatch.setenv("OMNISTORE_AI_API_KEY", "test-key")

    assistant = AIAssistant(DummyConfig())
    try:
        results = [
            await assistant.test_connection(),
            await assistant.explain_app("Example", "A useful app"),
            await assistant.recommend_apps(
                "editor",
                [{"name": "Example", "source": "Winget", "description": "Editor"}],
            ),
            await assistant.analyze_error("Traceback: boom"),
            await assistant.compare_variants(
                "Example",
                [{"source": "Winget", "id": "Example.App"}],
            ),
            await assistant.suggest_correction("edtor"),
            await assistant.generate_health_report({"os": "Windows"}),
            await assistant.pick_of_the_day([{"name": "Example", "description": "Editor"}]),
            await assistant.summarize_changelog("Example", "1.0", "1.1"),
            await assistant.generate_cli_command("Example", "Winget"),
            await assistant.detect_conflicts("Example", ["dependency-a"]),
            await assistant.summarize_project(),
        ]
    finally:
        await assistant.close()
        await runner.cleanup()

    assert results[0] == "success"
    assert all(result for result in results)
    assert len(calls) == 12
    assert {call["model"] for call in calls} == {"test-model"}


def test_ai_error_redaction():
    assistant = AIAssistant(DummyConfig())
    redacted = assistant._redact_sensitive("bad key sk-secret123456789 Bearer token123456789")
    assert "sk-secret" not in redacted
    assert "token123" not in redacted


@pytest.mark.asyncio
async def test_installation_decision_falls_back_deterministically_when_disabled():
    assistant = AIAssistant(DummyConfig({"ai": {"enabled": False}}))
    decision = await assistant.installation_decision("Example", [{"source": "AUR"}, {"source": "Flatpak"}])
    assert decision.recommendedVariant == "Flatpak"
    assert decision.preflightChecks


@pytest.mark.asyncio
async def test_installation_decision_rejects_invalid_ai_json(monkeypatch):
    assistant = AIAssistant(DummyConfig({"ai": {"enabled": True}}))

    async def invalid_response(*_args):
        return '{"recommendedVariant":"Untrusted","reasons":"not an array"}'

    monkeypatch.setattr(assistant, "_post_request", invalid_response)
    decision = await assistant.installation_decision("Example", [{"source": "Flatpak"}])
    assert decision.recommendedVariant == "Flatpak"
