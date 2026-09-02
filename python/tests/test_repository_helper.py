import importlib.util
from pathlib import Path

import pytest


HELPER_PATH = Path(__file__).resolve().parents[1] / "helpers" / "meo_repository_helper.py"
SPEC = importlib.util.spec_from_file_location("meo_repository_helper", HELPER_PATH)
helper = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(helper)


def request(repositories):
    return {"schema": "org.meo.pacman-repositories", "version": 1, "repositories": repositories}


def test_custom_repository_requires_https_and_reserves_distribution_names(monkeypatch):
    monkeypatch.setattr(helper, "_active_repositories", lambda: {"core", "extra"})
    monkeypatch.setattr(helper, "_managed_names", lambda: set())

    assert helper.validate(request([{"name": "local-tools", "url": "https://packages.example/repo/$arch"}]))
    with pytest.raises(ValueError, match="HTTPS"):
        helper.validate(request([{"name": "local-tools", "url": "http://packages.example/repo"}]))
    with pytest.raises(ValueError, match="reserved"):
        helper.validate(request([{"name": "core", "url": "https://packages.example/repo"}]))


def test_apply_preserves_non_utf8_pacman_conf_bytes(tmp_path, monkeypatch):
    pacman_conf = tmp_path / "pacman.conf"
    fragment = tmp_path / "omnistore-repositories.conf"
    original = b"[options]\n# preserved: \x80\xff\xfe\n[core]\nInclude = /etc/pacman.d/mirrorlist\n"
    pacman_conf.write_bytes(original)
    monkeypatch.setattr(helper, "PACMAN_CONF", pacman_conf)
    monkeypatch.setattr(helper, "MANAGED_FRAGMENT", fragment)

    helper.apply([{"name": "local-tools", "url": "https://packages.example/repo/$arch"}])

    assert pacman_conf.read_bytes().startswith(original)
    assert helper.INCLUDE_LINE.encode() in pacman_conf.read_bytes()
    assert "SigLevel = Required DatabaseOptional" in fragment.read_text()
    assert "[local-tools]" in fragment.read_text()
