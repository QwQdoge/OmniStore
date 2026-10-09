from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_arb_update_tool_uses_the_legacy_flutter_location():
    updater = (ROOT / "python" / "update_arb.py").read_text(encoding="utf-8")

    assert "legacy/flutter-ui/lib/l10n/app_{lang}.arb" in updater
    assert "legacy/flutter-ui/lib/l10n/app_en.arb" in updater
    assert "FlutterUI/" not in updater