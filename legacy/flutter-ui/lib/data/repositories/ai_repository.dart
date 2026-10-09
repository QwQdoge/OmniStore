import '../../services/backend_service.dart';

/// Murphy-proof: AI repository that delegates all calls to BackendService.
/// This ensures consistent process management, locking, and daemon usage.
class AIRepository {
  Future<String> aiExplain(String appName, String description) async {
    try {
      return await BackendService.instance.aiExplain(appName, description);
    } catch (e) {
      return "⚠ AI Explanation failed: $e";
    }
  }

  Future<String> aiSummarizeUpdate(
    String name,
    String current,
    String next,
  ) async {
    try {
      return await BackendService.instance.aiSummarizeUpdate(
        name,
        current,
        next,
      );
    } catch (e) {
      return "⚠ AI Changelog summary failed: $e";
    }
  }

  Future<String> aiGenerateCLI(String name, String source) async {
    try {
      return await BackendService.instance.aiGenerateCLI(name, source);
    } catch (e) {
      return "⚠ AI CLI generation failed: $e";
    }
  }

  Future<String> aiDetectConflicts(String name) async {
    try {
      return await BackendService.instance.aiDetectConflicts(name);
    } catch (e) {
      return "⚠ AI Conflict detection failed: $e";
    }
  }

  Future<String> aiPickOfTheDay() async {
    try {
      return await BackendService.instance.aiPickOfTheDay();
    } catch (e) {
      return "⚠ AI Pick of the day failed: $e";
    }
  }

  Future<String> aiSuggestCorrection(String query) async {
    try {
      return await BackendService.instance.aiSuggestCorrection(query);
    } catch (e) {
      return query; // Graceful fallback
    }
  }

  Future<String> aiCompareVariants(String appName) async {
    try {
      return await BackendService.instance.aiCompareVariants(appName);
    } catch (e) {
      return "⚠ AI Variant comparison failed: $e";
    }
  }

  Future<String> aiSystemHealth() async {
    try {
      return await BackendService.instance.aiSystemHealth();
    } catch (e) {
      return "⚠ AI System health check failed: $e";
    }
  }

  Future<String> aiAnalyzeError(String errorLog) async {
    try {
      return await BackendService.instance.aiAnalyzeError(errorLog);
    } catch (e) {
      return "⚠ AI Error analysis failed: $e";
    }
  }

  Future<String> aiRecommend(String prompt) async {
    try {
      return await BackendService.instance.aiRecommend(prompt);
    } catch (e) {
      return "⚠ AI Recommendation failed: $e";
    }
  }
}
