from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_flutter_client_is_gone():
    for name in ("legacy", "FlutterUI", "NativeUI"):
        assert not (ROOT / name).exists()
