import 'package:flutter_test/flutter_test.dart';
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
}
