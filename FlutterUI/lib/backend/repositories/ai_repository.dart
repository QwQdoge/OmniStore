import 'dart:convert';
import 'dart:io';
import '../../data/python_bridge.dart';

class AIRepository {
  Future<String> aiExplain(String appName, String description) async =>
      _aiCall(["--ai-explain", appName, "--ai-desc", description]);
  Future<String> aiSummarizeUpdate(
    String name,
    String current,
    String next,
  ) async => _aiCall(["--ai-changelog", "$name,$current,$next"]);
  Future<String> aiGenerateCLI(String name, String source) async =>
      _aiCall(["--ai-cli", "$name,$source"], timeout: 20);
  Future<String> aiDetectConflicts(String name) async =>
      _aiCall(["--ai-conflicts", name]);
  Future<String> aiPickOfTheDay() async => _aiCall(["--ai-pick"], timeout: 30);
  Future<String> aiSuggestCorrection(String query) async =>
      _aiCall(["--ai-correct", query], timeout: 15);
  Future<String> aiCompareVariants(String appName) async =>
      _aiCall(["--ai-compare", appName]);
  Future<String> aiSystemHealth() async => _aiCall(["--ai-health"]);
  Future<String> aiAnalyzeError(String errorLog) async =>
      _aiCall(["--ai-analyze-error", errorLog]);
  Future<String> aiRecommend(String prompt) async =>
      _aiCall(["--ai-recommend", prompt], timeout: 60);

  Future<String> _aiCall(List<String> args, {int timeout = 45}) async {
    try {
      final result = await Process.run(
        PythonBridge.venvPython,
        PythonBridge.buildArgs([...args, "--json"]),
        workingDirectory: PythonBridge.workingDir,
      ).timeout(Duration(seconds: timeout));

      final data = jsonDecode(result.stdout);
      return data['response'] ?? "AI Error: No response";
    } catch (e) {
      return "AI Exception: $e";
    }
  }
}
