import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_localizations_en.dart';
import 'package:frontend/data/repositories/task_repository.dart';
import 'package:frontend/features/task_manager/presentation/controllers/task_controller.dart';

class _FakeTaskRepository extends TaskRepository {
  _FakeTaskRepository();

  @override
  Stream<String> executeAction(
    String flag,
    String packageName,
    String source, {
    String? url,
  }) async* {
    yield '[INFO] Starting action';
    yield '[PROGRESS] 50';
    yield '[SUCCESS] Completed action';
  }
}

class _ControlledTaskRepository extends TaskRepository {
  final output = StreamController<String>();
  bool cancelled = false;

  @override
  Stream<String> executeAction(
    String flag,
    String packageName,
    String source, {
    String? url,
  }) => output.stream;

  @override
  Stream<String> cleanSystem() async* {
    yield '[SUCCESS] Finished cleaning';
  }

  @override
  void cancelCurrentTask() {
    cancelled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'TaskController logVersion increments on task logs and clearing',
    () async {
      final repo = _FakeTaskRepository();
      final controller = TaskController(repo);
      addTearDown(controller.dispose);

      expect(controller.logVersion, 0);
      expect(controller.logEntries.isEmpty, isTrue);

      controller.clearLogs();
      expect(controller.logVersion, 1);
      expect(controller.logEntries.isEmpty, isTrue);
    },
  );
  test(
    'history changes only on completed tasks and clear, including cleanup',
    () async {
      final repo = _ControlledTaskRepository();
      final controller = TaskController(repo);
      addTearDown(controller.dispose);
      final l10n = AppLocalizationsEn();
      final pending = controller.runTask('-I', 'Example', 'Flatpak', l10n);
      expect(controller.completedTasksVersion, 0);
      repo.output.add('[INFO] Still running');
      await Future<void>.delayed(Duration.zero);
      expect(controller.completedTasks, isEmpty);
      expect(controller.completedTasksVersion, 0);
      repo.output.add('[SUCCESS] Finished');
      await repo.output.close();
      expect(await pending, isTrue);
      expect(controller.completedTasks.single.packageName, 'Example');
      final completed = controller.completedTasksVersion;
      expect(completed, greaterThan(0));
      controller.clearLogs();
      expect(controller.completedTasksVersion, completed);
      await controller.runCleanSystem(l10n);
      expect(controller.completedTasks.length, 2);
      expect(controller.completedTasksVersion, greaterThan(completed));
      final cleaned = controller.completedTasksVersion;
      controller.clearHistory();
      expect(controller.completedTasks, isEmpty);
      expect(controller.completedTasksVersion, greaterThan(cleaned));
    },
  );

  test('cancelled late output never becomes completed history', () async {
    final repo = _ControlledTaskRepository();
    final controller = TaskController(repo);
    addTearDown(controller.dispose);
    final l10n = AppLocalizationsEn();
    final pending = controller.runTask('-I', 'Example', 'Flatpak', l10n);
    controller.cancelTask(l10n);
    expect(repo.cancelled, isTrue);
    repo.output.add('[SUCCESS] Buffered old success');
    await repo.output.close();
    expect(await pending, isFalse);
    expect(controller.completedTasks, isEmpty);
    expect(controller.completedTasksVersion, 0);
  });
}
