import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'process_registry.dart';
import 'platform_environment.dart';

/// Executes backend processes while keeping lifecycle and protocol handling in
/// one place. Human-readable messages and machine-readable severity are kept
/// separate so callers never have to infer success from log text.
class ProcessExecutionService {
  final ProcessRegistry _registry;
  final PlatformEnvironment _env = PlatformEnvironment.instance;

  ProcessExecutionService(this._registry);

  String _event({
    required String type,
    required String level,
    required String message,
    Map<String, dynamic> extra = const {},
  }) =>
      '[CALLBACK] ${jsonEncode(<String, dynamic>{
        'type': type,
        'level': level,
        'message': message,
        ...extra,
      })}';

  String _errorEvent(String message, {Object? error, int? exitCode}) => _event(
    type: 'error',
    level: 'error',
    message: message,
    extra: {
      if (error != null) 'error': error.toString(),
      if (exitCode != null) 'exitCode': exitCode,
    },
  );

  Future<ProcessResult?> run({
    required List<String> args,
    Duration timeout = const Duration(seconds: 30),
    String? apiKey,
  }) async {
    if (kIsWeb) return null;

    if (!File(_env.venvPython).existsSync() && _env.venvPython != 'python') {
      debugPrint(
        "Python environment missing at ${_env.venvPython}",
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
        runInShell: false,
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
    if (kIsWeb) {
      yield _event(
        type: 'log',
        level: 'info',
        message: 'Web sandbox',
      );
      return;
    }

    if (!File(_env.venvPython).existsSync() && _env.venvPython != 'python') {
      yield _errorEvent(
        'Python environment missing',
        error: _env.venvPython,
      );
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
        // Arguments are already passed as a list. Avoiding a shell removes an
        // unnecessary quoting/injection surface and makes exit semantics more
        // predictable across platforms.
        runInShell: false,
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
                controller.add(
                  _errorEvent('Failed to read process stdout', error: e),
                );
              }
            },
            onDone: () async {
              await stderrDone.future;

              try {
                final exitCode = await process!.exitCode;
                if (exitCode != 0 && !controller.isClosed) {
                  controller.add(
                    _errorEvent(
                      'Backend process exited unsuccessfully',
                      exitCode: exitCode,
                    ),
                  );
                }
              } catch (e) {
                if (!controller.isClosed) {
                  controller.add(
                    _errorEvent('Failed to obtain process exit code', error: e),
                  );
                }
              } finally {
                _registry.remove(process!);
                if (!controller.isClosed) await controller.close();
              }
            },
          );

      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(
            (data) {
              debugPrint("Backend stderr: $data");
              if (!controller.isClosed && data.trim().isNotEmpty) {
                // stderr is a stream, not a severity. Many CLI tools use it for
                // warnings/progress even on successful exit. The process exit
                // code above is the authoritative failure signal.
                controller.add(
                  _event(
                    type: 'log',
                    level: 'warning',
                    message: data,
                    extra: const {'stream': 'stderr'},
                  ),
                );
              }
            },
            onError: (e) {
              if (!controller.isClosed) {
                controller.add(
                  _errorEvent('Failed to read process stderr', error: e),
                );
              }
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
      if (!controller.isClosed) {
        controller.add(_errorEvent('Failed to start backend process', error: e));
        await controller.close();
      }
      if (process != null) await _registry.kill(process);
    } finally {
      if (process != null) _registry.remove(process);
    }
  }
}
