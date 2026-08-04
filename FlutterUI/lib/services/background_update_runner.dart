import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'backend/platform_environment.dart';

List<String> resolveLaunchArguments(List<String> dartArguments) {
  if (Platform.isLinux) {
    try {
      return {
        ...dartArguments,
        ...parseProcCommandLine(
          File('/proc/self/cmdline').readAsBytesSync(),
        ).skip(1),
      }.toList(growable: false);
    } on FileSystemException {
      // Fall through for non-procfs environments.
    }
  }
  return Platform.executableArguments;
}

List<String> parseProcCommandLine(List<int> bytes) {
  final arguments = <String>[];
  var start = 0;
  for (var index = 0; index <= bytes.length; index++) {
    if (index == bytes.length || bytes[index] == 0) {
      if (index > start) {
        arguments.add(utf8.decode(bytes.sublist(start, index)));
      }
      start = index + 1;
    }
  }
  return arguments;
}

/// Runs one update check without creating a Flutter window or a tray instance.
/// The systemd timer invokes this entry point; installation always remains an
/// explicit user action in the main application.
Future<int> runBackgroundUpdateCheck() async {
  final environment = PlatformEnvironment.instance;
  try {
    final result = await Process.run(
      environment.venvPython,
      environment.buildArgs(const ['--check-updates', '--json']),
      workingDirectory: environment.workingDir,
    ).timeout(const Duration(minutes: 8));

    if (result.exitCode != 0) {
      stderr.writeln('OmniStore update check failed: ${result.stderr}');
      return result.exitCode;
    }

    final updates = parseBackgroundUpdateOutput(result.stdout.toString());
    await _writeUpdateState(updates);
    if (updates.isNotEmpty) {
      await _notify(updates.length);
    }
    return 0;
  } on TimeoutException {
    stderr.writeln('OmniStore update check timed out.');
    return 124;
  } catch (error) {
    stderr.writeln('OmniStore update check failed: $error');
    return 1;
  }
}

List<Map<String, dynamic>> parseBackgroundUpdateOutput(String output) {
  for (final line in output.trim().split('\n').reversed) {
    try {
      final decoded = jsonDecode(line.trim());
      final payload = decoded is Map<String, dynamic>
          ? decoded['response']
          : decoded;
      if (payload is List) {
        return payload
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    } on FormatException {
      continue;
    }
  }
  throw const FormatException('Backend returned no update JSON payload.');
}

Future<void> _writeUpdateState(List<Map<String, dynamic>> updates) async {
  final stateRoot =
      Platform.environment['XDG_STATE_HOME'] ??
      p.join(
        Platform.environment['HOME'] ?? Directory.current.path,
        '.local',
        'state',
      );
  final stateDir = Directory(p.join(stateRoot, 'omnistore'));
  await stateDir.create(recursive: true);
  final stateFile = File(p.join(stateDir.path, 'update-state.json'));
  await stateFile.writeAsString(
    jsonEncode({
      'checked_at': DateTime.now().toUtc().toIso8601String(),
      'count': updates.length,
      'updates': updates,
    }),
    flush: true,
  );
}

Future<void> _notify(int count) async {
  if (!Platform.isLinux) return;
  final lookup = await Process.run('which', const ['notify-send']);
  if (lookup.exitCode != 0) return;
  await Process.run('notify-send', [
    '--app-name=OmniStore',
    '--icon=omnistore',
    'OmniStore updates available',
    '$count package${count == 1 ? '' : 's'} can be updated. Open OmniStore to review them.',
  ]).timeout(const Duration(seconds: 10));
}
