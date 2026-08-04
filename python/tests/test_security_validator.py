import pytest
from core.security_validator import SecurityValidator

class TestSecurityValidator:
    # --------------------------------------------------------------------------
    # validate_string
    # --------------------------------------------------------------------------
    def test_validate_string_valid(self):
        assert SecurityValidator.validate_string(" valid-string_123. ") == "valid-string_123."

    def test_validate_string_null(self):
        with pytest.raises(ValueError, match="cannot be null"):
            SecurityValidator.validate_string(None)

    def test_validate_string_empty(self):
        with pytest.raises(ValueError, match="cannot be empty"):
            SecurityValidator.validate_string("   ")

    def test_validate_string_app_description_empty(self):
        assert SecurityValidator.validate_string("   ", name="App Description") == ""

    def test_validate_string_exceeds_max_length(self):
        with pytest.raises(ValueError, match="exceeds max length"):
            SecurityValidator.validate_string("a" * 11, max_length=10)

    def test_validate_string_forbidden_chars(self):
        with pytest.raises(ValueError, match="contains forbidden characters"):
            SecurityValidator.validate_string("echo 'hello'; rm -rf /")

    # --------------------------------------------------------------------------
    # validate_search_query
    # --------------------------------------------------------------------------
    def test_validate_search_query_valid(self):
        assert SecurityValidator.validate_search_query("  flutter+app-name@dev:1.0~beta=yes!#%^*[]{}+ ") == "flutter+app-name@dev:1.0~beta=yes!#%^*[]{}+"

    def test_validate_search_query_null(self):
        with pytest.raises(ValueError, match="cannot be null"):
            SecurityValidator.validate_search_query(None)

    def test_validate_search_query_empty(self):
        with pytest.raises(ValueError, match="cannot be empty"):
            SecurityValidator.validate_search_query("   ")

    def test_validate_search_query_too_long(self):
        with pytest.raises(ValueError, match="is too long"):
            SecurityValidator.validate_search_query("a" * 501)

    def test_validate_search_query_forbidden_shell_chars(self):
        for char in ";&|`$()\\'\"":
            with pytest.raises(ValueError, match="contains forbidden shell metacharacters"):
                SecurityValidator.validate_search_query(f"valid_query{char}invalid")

    def test_validate_search_query_invalid_chars(self):
        with pytest.raises(ValueError, match="contains invalid search characters"):
            # '?' is not in the allowed regex for search query
            SecurityValidator.validate_search_query("invalid?query")

    # --------------------------------------------------------------------------
    # validate_path
    # --------------------------------------------------------------------------
    def test_validate_path_valid(self):
        assert SecurityValidator.validate_path("  /var/log/app-1.log ") == "/var/log/app-1.log"
        assert SecurityValidator.validate_path("C:\\Windows\\Temp") == "C:\\Windows\\Temp"

    def test_validate_path_null(self):
        with pytest.raises(ValueError, match="cannot be null"):
            SecurityValidator.validate_path(None)

    def test_validate_path_empty(self):
        with pytest.raises(ValueError, match="cannot be empty"):
            SecurityValidator.validate_path("   ")

    def test_validate_path_too_long(self):
        with pytest.raises(ValueError, match="path too long"):
            SecurityValidator.validate_path("a/b/c" * 1000, max_length=10)

    def test_validate_path_traversal(self):
        with pytest.raises(ValueError, match="Path traversal \\('..'\\) detected"):
            SecurityValidator.validate_path("../etc/passwd")

    def test_validate_path_illegal_chars(self):
        with pytest.raises(ValueError, match="contains illegal characters"):
            SecurityValidator.validate_path("/var/log/my_app.log;")

    # --------------------------------------------------------------------------
    # validate_url
    # --------------------------------------------------------------------------
    def test_validate_url_valid(self):
        assert SecurityValidator.validate_url(" https://example.com/api/v1/data?id=123&type=json#top ") == "https://example.com/api/v1/data?id=123&type=json#top"
        assert SecurityValidator.validate_url("http://localhost:8080") == "http://localhost:8080"

    def test_validate_url_null(self):
        with pytest.raises(ValueError, match="cannot be null"):
            SecurityValidator.validate_url(None)

    def test_validate_url_empty(self):
        with pytest.raises(ValueError, match="cannot be empty"):
            SecurityValidator.validate_url("   ")

    def test_validate_url_invalid(self):
        with pytest.raises(ValueError, match="is not a valid or safe URL"):
            SecurityValidator.validate_url("ftp://example.com")
        with pytest.raises(ValueError, match="is not a valid or safe URL"):
            SecurityValidator.validate_url("https://example.com/api;rm -rf /")

    def test_validate_url_too_long(self):
        with pytest.raises(ValueError, match="exceeds length limit"):
            # URL regex will pass, but length limit is 2048
            SecurityValidator.validate_url("https://example.com/" + "a" * 2050)

    # --------------------------------------------------------------------------
    # validate_strict_id
    # --------------------------------------------------------------------------
    def test_validate_strict_id_valid(self):
        assert SecurityValidator.validate_strict_id("  my-app_id.123:@  ") == "my-app_id.123:@"

    def test_validate_strict_id_missing(self):
        with pytest.raises(ValueError, match="is missing"):
            SecurityValidator.validate_strict_id(None)
        with pytest.raises(ValueError, match="is missing"):
            SecurityValidator.validate_strict_id("")

    def test_validate_strict_id_invalid(self):
        with pytest.raises(ValueError, match="must be alphanumeric"):
            SecurityValidator.validate_strict_id("invalid id with spaces")
        with pytest.raises(ValueError, match="must be alphanumeric"):
            SecurityValidator.validate_strict_id("id/with/slashes")

    # --------------------------------------------------------------------------
    # validate_action_flag
    # --------------------------------------------------------------------------
    def test_validate_action_flag_valid(self):
        for flag in ["-I", "-R", "-U", "-S", "-L", "-C"]:
            assert SecurityValidator.validate_action_flag(flag) == flag

    def test_validate_action_flag_invalid(self):
        with pytest.raises(ValueError, match="Invalid action flag"):
            SecurityValidator.validate_action_flag("-X")
        with pytest.raises(ValueError, match="Invalid action flag"):
            SecurityValidator.validate_action_flag("invalid")

    # --------------------------------------------------------------------------
    # validate_payload_size
    # --------------------------------------------------------------------------
    def test_validate_payload_size_valid(self):
        data = "a" * (1 * 1024 * 1024) # 1 MB
        assert SecurityValidator.validate_payload_size(data, limit_mb=2) == data

    def test_validate_payload_size_exceeds(self):
        data = "a" * (3 * 1024 * 1024) # 3 MB
        with pytest.raises(ValueError, match="Payload size exceeds"):
            SecurityValidator.validate_payload_size(data, limit_mb=2)

    # --------------------------------------------------------------------------
    # safe_json_load
    # --------------------------------------------------------------------------
    def test_safe_json_load_valid(self):
        data = '{"key": "value", "list": [1, 2, 3]}'
        result = SecurityValidator.safe_json_load(data)
        assert result == {"key": "value", "list": [1, 2, 3]}

    def test_safe_json_load_exceeds_size(self):
        # Create valid JSON, but too large
        data = '{"key": "' + "a" * (3 * 1024 * 1024) + '"}'
        with pytest.raises(ValueError, match="Payload size exceeds"):
            SecurityValidator.safe_json_load(data, limit_mb=2)

    def test_safe_json_load_malformed(self):
        data = '{"key": "value", invalid json'
        with pytest.raises(ValueError, match="Malformed JSON payload"):
            SecurityValidator.safe_json_load(data)
