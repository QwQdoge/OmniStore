import 'dart:async';
import 'package:flutter/foundation.dart';
import '../backend_service.dart';

/// Murphy-proof: Specialized service for AI methods.
class AiBridgeService {
  final BackendService _backend;

  AiBridgeService(this._backend);

  Future<String> call(
    List<String> args, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      final res = await _backend.runRaw([...args, "--json"], timeout: timeout);
      if (res == null) return "AI_TIMEOUT";
      final data = _backend.safeJsonDecode(res.stdout.toString());
      if (data is Map) return data['response']?.toString() ?? "AI_NO_RESPONSE";
      return "AI_PARSE_FAILED";
    } catch (e) {
      debugPrint("AiBridgeService.call error: $e");
      return "AI_ERROR";
    }
  }

  Future<String> explain(String name, String desc) async {
    return call(["--ai-explain", name.trim(), "--ai-desc", desc.trim()]);
  }

  Future<String> analyzeError(String log) async {
    return call(["--ai-analyze-error", log.trim()]);
  }

  Future<String> recommend(String prompt) async {
    return call([
      "--ai-recommend",
      prompt.trim(),
    ], timeout: const Duration(seconds: 90));
  }
}
