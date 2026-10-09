from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DETAILS = ROOT / "src" / "native-ui" / "qml" / "components" / "AppDetailsPane.qml"


def test_selected_variant_controls_package_identity_source_and_plan():
    text = DETAILS.read_text(encoding="utf-8")

    assert 'property string selectedSource: ""' in text
    assert "function selectedVariant()" in text
    assert "variant.id || variant.name || """ in text
    assert "function packageIdentity()" in text
    assert "transactions.planInstall(root.packageIdentity(), root.sourceName(), root.installUrl())" in text
    assert 'String(currentPlanRequest.name || "") === root.packageIdentity()' in text
    assert 'sourceKey(currentPlanRequest.source || "") === sourceKey(root.sourceName())' in text


def test_switching_source_invalidates_reviewed_plan():
    text = DETAILS.read_text(encoding="utf-8")

    assert "function chooseSource(source, packageId)" in text
    assert "transactions.clearInstallPlan()" in text
    assert "selectedSource = next" in text
    assert "onFallbackAppChanged" in text


def test_variant_rows_are_interactive_and_locked_during_mutation():
    text = DETAILS.read_text(encoding="utf-8")

    assert 'text: qsTr("Choose source")' in text
    assert "interactive: true" in text
    assert "!transactions.planning && !transactions.busy" in text
    assert 'String(modelData.id || modelData.name || "") === root.packageIdentity()' in text
    assert 'onClicked: root.chooseSource(String(modelData.source || ""), String(modelData.id || modelData.name || ""))' in text
