import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_package.dart';

class BackendService {
  final String _venvPython = "/home/shekong/Projects/Omnistore/python/.venv/bin/python";
  final String _scriptPath = "/home/shekong/Projects/Omnistore/python/main.py";
  final String _workingDir = "/home/shekong/Projects/Omnistore/python";

  // 全局进度通知器
  static final ValueNotifier<double?> globalProgress = ValueNotifier(null);
  static final ValueNotifier<String> globalStatus = ValueNotifier("Ready");
  static final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  
  // 当前正在操作的 app（用于跨页面状态恢复）
  static final ValueNotifier<AppPackage?> activeApp = ValueNotifier(null);
  static final ValueNotifier<String?> activeFlag = ValueNotifier(null); // "-I" or "-R"
  static Process? activeProcess;

  static void cancelCurrentTask() {
    if (activeProcess != null) {
      activeProcess!.kill(ProcessSignal.sigterm);
      activeProcess = null;
      isDownloading.value = false;
      globalStatus.value = "任务已取消";
      globalProgress.value = null;
      activeApp.value = null;
      activeFlag.value = null;
    }
  }

  /// 搜索逻辑
  Future<List<dynamic>> searchPackages(String query) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "-S", query, "--json",
      ], workingDirectory: _workingDir);

      if (result.exitCode != 0) return [];
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      return [];
    }
  }

  /// 获取已安装列表
  Future<List<dynamic>> listInstalled() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "-L", "--json",
      ], workingDirectory: _workingDir);

      if (result.exitCode != 0) return [];
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("ListInstalled Exception: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> loadConfig() async {
    try {
      final result = await Process.run(_venvPython, [_scriptPath, "--get-config", "--json"]);
      return jsonDecode(result.stdout);
    } catch (e) { return {}; }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath, "--set-config", jsonEncode(config), "--json",
      ]);
      return result.exitCode == 0;
    } catch (e) { return false; }
  }

  Stream<String> executeAction(String flag, String packageName, String source, {String? url}) async* {
    if (packageName.isEmpty) {
      yield "[CALLBACK] {\"log\": \"错误：包名不能为空\"}";
      return;
    }

    try {
      List<String> args = [_scriptPath, flag, packageName, "--source", source, "--json"];
      if (url != null && url.isNotEmpty) {
        args.addAll(["--url", url]);
      }

      final process = await Process.start(_venvPython, args, workingDirectory: _workingDir);

      yield* process.stdout.transform(utf8.decoder).transform(const LineSplitter());

      process.stderr.transform(utf8.decoder).listen((data) {
        debugPrint("Python Stderr: $data");
      });
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"启动失败: $e\"}";
    }
  }
}
