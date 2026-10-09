from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DETAILS = ROOT / "src" / "native-ui" / "qml" / "components" / "AppDetailsPane.qml"


def test_selected_variant_controls_package_identity_source_and_plan():
    text = DETAILS.read_text(encoding="utf-8")

    assert 'property string selectedSource: ""' in text
    assert "function selectedVariant()" in text
    assert "variant.id || variant.name || app.id || app.name" in text
    assert "function packageIdentity()" in text
    assert "transactions.planInstall(root.packageIdentity(), root.sourceName(), root.installUrl())" in text
    assert 'String(currentPlanRequest.name || "") === root.packageIdentity()' in text
    assert 'String(currentPlanRequest.source || "") === root.sourceName()' in text


def test_switching_source_invalidates_reviewed_plan():
    text = DETAILS.read_text(encoding="utf-8")

    assert "function chooseSource(source)" in text
    assert "transactions.clearInstallPlan()" in text
    assert "selectedSource = next" in text
    assert "onFallbackIdentityChanged" in text


def test_variant_rows_are_interactive_and_locked_during_mutation():
    text = DETAILS.read_text(encoding="utf-8")

    assert 'text: qsTr("Choose source")' in text
    assert "interactive: true" in text
    assert "enabled: !transactions.planning && !transactions.busy" in text
    assert 'selected: String(modelData.source || "") === root.sourceName()' in text
    assert 'onClicked: root.chooseSource(String(modelData.source || ""))' in text
