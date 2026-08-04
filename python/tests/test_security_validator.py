import pytest

from core.security_validator import SecurityValidator


def test_safe_json_load_valid():
    """Verify that valid JSON is loaded correctly."""
    valid_json = '{"key": "value", "number": 42}'
    result = SecurityValidator.safe_json_load(valid_json)
    assert result == {"key": "value", "number": 42}


def test_safe_json_load_invalid():
    """Verify that invalid JSON raises a ValueError with a helpful message."""
    invalid_json = '{"key": "value",}'  # Trailing comma is invalid in standard JSON
    with pytest.raises(ValueError, match="Malformed JSON payload:"):
        SecurityValidator.safe_json_load(invalid_json)


def test_safe_json_load_exceeds_size_limit():
    """Verify that payloads exceeding the size limit raise a ValueError."""
    # Create a small valid JSON string
    small_json = '{"key": "value"}'

    # 0 limit will cause even this small payload to fail
    with pytest.raises(ValueError, match="Security: Payload size exceeds"):
        SecurityValidator.safe_json_load(small_json, limit_mb=0)
