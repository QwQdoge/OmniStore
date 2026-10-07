from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SETTINGS = ROOT / "NativeUI" / "qml" / "pages" / "SettingsPage.qml"


def text() -> str:
    return SETTINGS.read_text(encoding="utf-8")


def test_product_source_groups_are_explicit_but_state_is_runtime_driven():
    source = text()

    assert 'id === "builtin.pacman"' in source
    assert 'id === "builtin.flatpak"' in source
    assert 'id === "builtin.aur"' in source
    for group in ("system", "apps", "community", "advanced"):
        assert f'root.sourceRows("{group}")' in source

    assert "plugin.available" in source
    assert "plugin.enabled" in source
    assert "plugin.trusted" in source
    assert "plugin.requires_review" in source
    assert "plugin.capabilities" in source


def test_advanced_unavailable_sources_do_not_pollute_normal_settings():
    source = text()
    assert 'if (group === "advanced" && !plugin.available)' in source
    assert "continue" in source


def test_review_required_source_needs_confirmation_before_enable():
    source = text()
    assert "value && plugin.requires_review" in source
    assert "sourceReviewDialog.open()" in source
    assert 'confirmText: qsTr("Enable source")' in source
    assert "backend.setPluginEnabled(root.pendingPluginId, true)" in source


def test_normal_settings_do_not_dump_raw_backend_json():
    source = text()
    assert "JSON.stringify(backend.config" not in source
    assert "JSON.stringify(backend.storageInfo" not in source
    assert "info.disk_free" in source
    assert "info.disk_used" in source
