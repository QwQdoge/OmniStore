import pytest
from core.security_validator import SecurityValidator

def test_validate_string():
    assert SecurityValidator.validate_string("hello_world") == "hello_world"
    assert SecurityValidator.validate_string(" valid string ") == "valid string"
    assert SecurityValidator.validate_string("test.string-123/") == "test.string-123/"

    with pytest.raises(ValueError, match="cannot be null"):
        SecurityValidator.validate_string(None)

    with pytest.raises(ValueError, match="cannot be empty"):
        SecurityValidator.validate_string("")

    assert SecurityValidator.validate_string("", name="App Description") == ""

    with pytest.raises(ValueError, match="exceeds max length"):
        SecurityValidator.validate_string("a" * 1025)

    with pytest.raises(ValueError, match="Security Policy Violation"):
        SecurityValidator.validate_string("hello; world")

def test_validate_search_query():
    assert SecurityValidator.validate_search_query("my query 123") == "my query 123"
    assert SecurityValidator.validate_search_query("query with + and -") == "query with + and -"
    assert SecurityValidator.validate_search_query("pkg:name author:test") == "pkg:name author:test"

    with pytest.raises(ValueError, match="cannot be null"):
        SecurityValidator.validate_search_query(None)

    with pytest.raises(ValueError, match="cannot be empty"):
        SecurityValidator.validate_search_query("   ")

    with pytest.raises(ValueError, match="too long"):
        SecurityValidator.validate_search_query("a" * 501)

    with pytest.raises(ValueError, match="forbidden shell metacharacters"):
        SecurityValidator.validate_search_query("query; rm -rf")

    with pytest.raises(ValueError, match="invalid search characters"):
        SecurityValidator.validate_search_query("query\x00")

def test_validate_path():
    assert SecurityValidator.validate_path("/absolute/path/to/file") == "/absolute/path/to/file"
    assert SecurityValidator.validate_path("relative/path") == "relative/path"

    with pytest.raises(ValueError, match="cannot be null"):
        SecurityValidator.validate_path(None)

    with pytest.raises(ValueError, match="cannot be empty"):
        SecurityValidator.validate_path("  ")

    with pytest.raises(ValueError, match="path too long"):
        SecurityValidator.validate_path("a" * 4097)

    with pytest.raises(ValueError, match="Path traversal"):
        SecurityValidator.validate_path("../etc/passwd")

    with pytest.raises(ValueError, match="Path traversal"):
        SecurityValidator.validate_path("a/../../b")

    with pytest.raises(ValueError, match="illegal characters"):
        SecurityValidator.validate_path("path/with/|pipe")

def test_validate_url():
    assert SecurityValidator.validate_url("https://github.com/test") == "https://github.com/test"
    assert SecurityValidator.validate_url("http://localhost:8080") == "http://localhost:8080"

    with pytest.raises(ValueError, match="cannot be null"):
        SecurityValidator.validate_url(None)

    with pytest.raises(ValueError, match="cannot be empty"):
        SecurityValidator.validate_url("")

    with pytest.raises(ValueError, match="not a valid or safe URL"):
        SecurityValidator.validate_url("ftp://server")

    with pytest.raises(ValueError, match="not a valid or safe URL"):
        SecurityValidator.validate_url("https://test.com/a;b")

    with pytest.raises(ValueError, match="exceeds length limit"):
        SecurityValidator.validate_url("https://test.com/" + "a" * 2048)

def test_validate_strict_id():
    assert SecurityValidator.validate_strict_id("valid.id-123_@:") == "valid.id-123_@:"

    with pytest.raises(ValueError, match="is missing"):
        SecurityValidator.validate_strict_id("")

    with pytest.raises(ValueError, match="must be alphanumeric"):
        SecurityValidator.validate_strict_id("id with spaces")

def test_validate_action_flag():
    assert SecurityValidator.validate_action_flag("-I") == "-I"
    assert SecurityValidator.validate_action_flag("-R") == "-R"

    with pytest.raises(ValueError, match="Invalid action flag"):
        SecurityValidator.validate_action_flag("-X")

def test_validate_payload_size():
    assert SecurityValidator.validate_payload_size("test data") == "test data"

    large_data = "a" * (11 * 1024 * 1024)
    with pytest.raises(ValueError, match="Payload size exceeds"):
        SecurityValidator.validate_payload_size(large_data, limit_mb=10)

def test_safe_json_load():
    valid_json = '{"key": "value", "list": [1, 2, 3]}'
    assert SecurityValidator.safe_json_load(valid_json) == {"key": "value", "list": [1, 2, 3]}

    with pytest.raises(ValueError, match="Malformed JSON payload"):
        SecurityValidator.safe_json_load('{"key": "value"')

    large_json = '{"key": "' + 'a' * (11 * 1024 * 1024) + '"}'
    with pytest.raises(ValueError, match="Payload size exceeds"):
        SecurityValidator.safe_json_load(large_json, limit_mb=10)
