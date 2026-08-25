import importlib.util
import json
from pathlib import Path

import pytest


_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
_SPEC = importlib.util.spec_from_file_location(
    "release_exporter_contract", _REPOSITORY_ROOT / "verify_release_exporter_contract.py"
)
assert _SPEC is not None and _SPEC.loader is not None
contract = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(contract)


def _snapshot(**overrides):
    result = {
        "schema": "org.meo.omnistore.installed-usage",
        "version": 1,
        "status": "success",
        "generatedAt": "2026-08-23T00:00:00Z",
        "applicationCount": 0,
        "knownSizeBytes": 0,
        "unknownSizeCount": 0,
        "sources": [],
        "applications": [],
    }
    result.update(overrides)
    return result


def test_release_contract_requires_the_named_public_flag():
    assert contract.advertises_exporter("usage: python_server --export-installed-usage --json")
    assert not contract.advertises_exporter("usage: python_server --list-installed --json")


def test_release_contract_accepts_the_minimal_schema_v1_snapshot():
    payload = json.dumps(_snapshot()).encode("utf-8")
    assert contract.validate_snapshot(payload)["schema"] == "org.meo.omnistore.installed-usage"


def test_release_contract_requires_builtin_source_manifests(tmp_path):
    backend = tmp_path / "backends" / "python_server"
    backend.parent.mkdir()
    backend.write_text("placeholder", encoding="utf-8")
    with pytest.raises(ValueError, match="required built-in source manifests"):
        contract.bundle_root_for(backend)

    for manifest in contract.REQUIRED_SOURCE_MANIFESTS:
        destination = tmp_path / manifest
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text("{}", encoding="utf-8")
    assert contract.bundle_root_for(backend) == tmp_path


@pytest.mark.parametrize(
    "overrides",
    [
        {"status": "error"},
        {"version": 2},
        {"applicationCount": True},
        {"sources": {}},
        {"applications": {}},
    ],
)
def test_release_contract_rejects_unsupported_or_unsafe_responses(overrides):
    with pytest.raises(ValueError):
        contract.validate_snapshot(json.dumps(_snapshot(**overrides)).encode("utf-8"))
