import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class BackendService {
  // 建议：使用相对路径或通过配置文件获取，避免硬编码
  final String _venvPython =
      "/home/shekong/Projects/Omnistore/python/.venv/bin/python";
  final String _scriptPath = "/home/shekong/Projects/Omnistore/python/main.py";
  final String _workingDir = "/home/shekong/Projects/Omnistore/python";

  /// 搜索逻辑 (一次性返回结果)
  Future<List<dynamic>> searchPackages(String query) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "-S",
        query,
        "--json",
      ], workingDirectory: _workingDir);

      if (result.exitCode != 0) {
        debugPrint(
          "Search Exit Code 2 Error: ${result.stderr}",
        ); // 这里能看到具体的参数报错
        return [];
      }
      return jsonDecode(result.stdout.toString().trim());
    } catch (e) {
      debugPrint("Search Exception: $e");
      return [];
    }
  }

  // 在你的 backend_service.dart 中添加
  Future<Map<String, dynamic>> loadConfig() async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--get-config",
        "--json",
      ]);
      return jsonDecode(result.stdout);
    } catch (e) {
      return {}; // 返回默认或错误处理
    }
  }

  Future<bool> saveConfig(Map<String, dynamic> config) async {
    try {
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "--set-config",
        jsonEncode(config),
        "--json",
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 执行逻辑 (安装/卸载，流式返回日志)
  Stream<String> executeAction(
    String flag,
    String packageName,
    String source,
  ) async* {
    // 强制检查参数，防止传递空字符串导致 Exit Code 2
    if (packageName.isEmpty) {
      yield "[CALLBACK] {\"log\": \"错误：包名不能为空\"}";
      return;
    }

    try {
      final process = await Process.start(_venvPython, [
        _scriptPath,
        flag, // "-I" 或 "-R"
        packageName,
        "--source", source,
        "--json",
      ], workingDirectory: _workingDir);

      // 监听标准输出
      yield* process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      // 监听错误输出 (这是排查 Exit Code 2 的关键)
      process.stderr.transform(utf8.decoder).listen((data) {
        debugPrint("Python Stderr: $data");
      });
    } catch (e) {
      yield "[CALLBACK] {\"log\": \"启动失败: $e\"}";
    }
  }
}
