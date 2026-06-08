import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/repositories/task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('TaskRepository streams stdout and stderr', () async {
    final repo = TaskRepository();
    
    // Attempting to install a nonexistent package from Pacman source
    final stream = repo.executeAction("-I", "nonexistent-pkg-abc-xyz", "Pacman");
    
    final logs = <String>[];
    await for (final line in stream) {
      logs.add(line);
      print("TEST STREAM OUT: $line");
    }

    expect(logs, isNotEmpty);
    
    // The stream should contain the stdout command running log, stderr output, or exit code error callback
    final hasExpectedLogs = logs.any((l) => 
      l.contains('errorStartFailed') || 
      l.contains('target not found') || 
      l.contains('Running') ||
      l.contains('exited with code')
    );
    expect(hasExpectedLogs, isTrue);

    // Verify it yields the start failed/exit code error callback because pacman failed and exited with 1
    final hasErrorCallback = logs.any((l) => l.contains('errorStartFailed'));
    expect(hasErrorCallback, isTrue);
  });
}
