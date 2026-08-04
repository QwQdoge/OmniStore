🧪 [testing improvement description]

🎯 **What:** Added comprehensive unit tests for `SecurityValidator.safe_json_load` in `python/tests/test_security_validator.py`.
📊 **Coverage:** The tests cover the happy path (valid JSON), the untested error path (`json.JSONDecodeError`), and the edge case where the payload exceeds the size limit (`limit_mb`).
✨ **Result:** Increased test coverage for `SecurityValidator.safe_json_load`, ensuring malformed JSON and oversized payloads are handled correctly.
