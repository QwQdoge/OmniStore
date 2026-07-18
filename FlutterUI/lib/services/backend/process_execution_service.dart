import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'process_registry.dart';
import 'platform_environment.dart';

/// Murphy-proof: Specialized service for process execution and lifecycle management.
class ProcessExecutionService {
  final ProcessRegistry _registry;
  final PlatformEnvironment _env = PlatformEnvironment.instance;

  ProcessExecutionService(this._registry);

  Future<ProcessResult?> run({
    required List<String> args,
    Duration timeout = const Duration(seconds: 30),
    String? apiKey,
  }) async {
    if (kIsWeb) return null;

    if (!File(_env.venvPython).existsSync() && _env.venvPython != 'python') {
      debugPrint(
        "Backend Error: Python environment missing at ${_env.venvPython}",
      );
      return null;
    }

    Process? process;
    try {
      final env = <String, String>{};
      if (apiKey != null && apiKey.isNotEmpty) {
        env['OMNISTORE_AI_API_KEY'] = apiKey;
      }

      process = await Process.start(
        _env.venvPython,
        _env.buildArgs(args),
        workingDirectory: _env.workingDir,
        environment: env.isEmpty ? null : env,
      ).timeout(const Duration(seconds: 10));

      _registry.add(process);

      final stdoutFuture = process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();
      final stderrFuture = process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .join();

      final exitCode = await process.exitCode.timeout(timeout);
      final stdout = await stdoutFuture;
      final stderr = await stderrFuture;

      return ProcessResult(process.pid, exitCode, stdout, stderr);
    } catch (e) {
      debugPrint("ProcessExecutionService.run failed: $e");
      if (process != null) await _registry.kill(process);
      return null;
    } finally {
      if (process != null) _registry.remove(process);
    }
  }

  Stream<String> stream({
    required List<String> args,
    String? apiKey,
    Function(Process)? onProcessStarted,
  }) async* {
    if (kIsWeb) yield "[CALLBACK] {\"log\": \"Web sandbox\"}";

    if (!File(_env.venvPython).existsSync() && _env.venvPython != 'python') {
      yield "[CALLBACK] {\"type\": \"log\", \"message\": \"[ERROR] Python environment missing\", \"level\": \"ERROR\"}";
      return;
    }

    Process? process;
    final controller = StreamController<String>();

    try {
      final env = <String, String>{};
      if (apiKey != null && apiKey.isNotEmpty) {
        env['OMNISTORE_AI_API_KEY'] = apiKey;
      }

      process = await Process.start(
        _env.venvPython,
        _env.buildArgs(args),
        workingDirectory: _env.workingDir,
        environment: env.isEmpty ? null : env,
        runInShell: true,
      ).timeout(const Duration(seconds: 10));

      _registry.add(process);
      if (onProcessStarted != null) onProcessStarted(process);

      final stderrDone = Completer<void>();

      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            (data) {
              if (!controller.isClosed) controller.add(data);
            },
            onError: (e) {
              if (!controller.isClosed) {
                controller.add("[CALLBACK] {\"error\": \"$e\"}");
              }
            },
            onDone: () async {
              await stderrDone.future;
              if (process != null) _registry.remove(process);
              if (!controller.isClosed) controller.close();
            },
          );

      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            (data) {
              debugPrint("Stderr: $data");
              if (!controller.isClosed) controller.add("[ERROR] $data");
            },
            onError: (e) {
              if (!controller.isClosed) controller.add("[ERROR] $e");
              if (!stderrDone.isCompleted) stderrDone.complete();
            },
            onDone: () {
              if (!stderrDone.isCompleted) stderrDone.complete();
            },
          );

      controller.onCancel = () async {
        await _registry.kill(process);
        if (!controller.isClosed) await controller.close();
      };

      yield* controller.stream;
    } catch (e) {
      debugPrint("ProcessExecutionService.stream exception: $e");
      if (!controller.isClosed) await controller.close();
      if (process != null) await _registry.kill(process);
    }
  }
}
