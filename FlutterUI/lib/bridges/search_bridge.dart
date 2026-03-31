// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

class BackendService {
  final String _venvPython =
      "/home/shekong/Projects/Omnistore/python/.venv/bin/python";
  final String _scriptPath = "/home/shekong/Projects/Omnistore/python/main.py";

  Future<List<dynamic>> searchPackages(String query) async {
    print("Searching for packages matching '$query'");

    try {
      // 1. 运行 Python 进程
      final result = await Process.run(_venvPython, [
        _scriptPath,
        "-S",
        query,
        "--json",
      ]);

      // 2. 检查基础退出码
      if (result.exitCode != 0) {
        print("python error (Exit Code: ${result.exitCode})");
        print("error: ${result.stderr}");
        return [];
      }

      // 3. 提取并清理输出内容
      String output = result.stdout.toString().trim();
      if (output.isEmpty) {
        print("output is empty");
        return [];
      }

      // 4. 尝试解析 JSON
      final dynamic decoded = jsonDecode(output);

      // 5. 业务逻辑错误处理 (处理 Python 传回的 {"error": "..."})
      if (decoded is Map && decoded.containsKey('error')) {
        print("backend error: ${decoded['error']}");
        return [];
      }

      // 6. 正常返回列表
      if (decoded is List) {
        print(" ${decoded.length} packages found for query '$query'");
        return decoded;
      }

      return [];
    } catch (e) {
      print("error: $e");
      return [];
    }
  }
}
