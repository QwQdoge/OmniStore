enum TaskStatus {
  pending,
  downloading,
  installing,
  success,
  failed,
}

class TaskState {
  final String id;
  final TaskStatus status;
  final double progress; // 0.0 to 1.0, or -1.0 for indeterminate
  final String speed;
  final String message;

  TaskState({
    required this.id,
    required this.status,
    required this.progress,
    this.speed = "",
    this.message = "",
  });

  TaskState copyWith({
    String? id,
    TaskStatus? status,
    double? progress,
    String? speed,
    String? message,
  }) {
    return TaskState(
      id: id ?? this.id,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      message: message ?? this.message,
    );
  }

  @override
  String toString() {
    return 'TaskState(id: $id, status: $status, progress: $progress, speed: $speed, message: $message)';
  }
}
