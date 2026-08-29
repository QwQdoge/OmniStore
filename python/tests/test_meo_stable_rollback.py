import json

import pytest

from helpers import meo_stable_rollback as rollback


def test_request_protocol_has_no_target_or_command_injection_surface():
    assert rollback._read_request('{"version":1,"operation":"preview"}') == {
        "version": 1,
        "operation": "preview",
    }
    with pytest.raises(rollback.RollbackError, match="invalid_request"):
        rollback._read_request('{"version":1,"operation":"preview","package":"bash"}')
    with pytest.raises(rollback.RollbackError, match="invalid_request"):
        rollback._read_request('{"version":1,"operation":"commit","planHash":"not-a-hash"}')


def test_catalog_accepts_only_the_installed_release_schemas(tmp_path):
    catalog = tmp_path / "catalog.json"
    catalog.write_text(json.dumps({"officialPackages": ["meoui-qml", "omnistore-bin"]}), encoding="utf-8")
    assert rollback._catalog_packages(catalog) == ("meoui-qml", "omnistore-bin")
    catalog.write_text(json.dumps({"packages": {"meoui-qml": {}, "bad;name": {}}}), encoding="utf-8")
    with pytest.raises(rollback.RollbackError, match="catalog_invalid"):
        rollback._catalog_packages(catalog)


def test_plan_hash_binds_name_versions_and_download_hashes(tmp_path):
    package = tmp_path / "meoui-qml-1.0-1-x86_64.pkg.tar.zst"
    package.write_bytes(b"signed Meo package")
    plan = rollback._canonical_plan(
        [{"name": "meoui-qml", "installed": "1.1-1", "stable": "1.0-1"}],
        {"meoui-qml": package},
    )
    assert plan["planHash"] == rollback._canonical_plan(
        [{"name": "meoui-qml", "installed": "1.1-1", "stable": "1.0-1"}],
        {"meoui-qml": package},
    )["planHash"]
    package.write_bytes(b"different package")
    changed = rollback._canonical_plan(
        [{"name": "meoui-qml", "installed": "1.1-1", "stable": "1.0-1"}],
        {"meoui-qml": package},
    )
    assert changed["planHash"] != plan["planHash"]


def test_transaction_change_guard_rejects_removals_and_non_catalog_additions():
    class Package:
        def __init__(self, name, version="1"):
            self.name = name
            self.version = version

    class Transaction:
        to_remove = []
        to_add = [Package("bash")]

    with pytest.raises(rollback.RollbackError, match="non_meo"):
        rollback._changes(Transaction(), {"meoui-qml"}, {})

    class RemovalTransaction:
        to_remove = [Package("bash")]
        to_add = []

    with pytest.raises(rollback.RollbackError, match="non_meo"):
        rollback._changes(RemovalTransaction(), {"meoui-qml"}, {})
