enum TaskStatus { pending, downloading, installing, success, failed }

class TaskState {
  final String id;
  final TaskStatus status;
  final double progress; // 0.0 to 1.0, or -1.0 for indeterminate
  final String speed;
  final String message;
  final String? messageKey;
  final Map<String, dynamic>? messageArgs;
  final String stage;
  final String? packageName;
  final String? source;

  TaskState({
    required this.id,
    required this.status,
    required this.progress,
    this.speed = "",
    this.message = "",
    this.messageKey,
    this.messageArgs,
    this.stage = "",
    this.packageName,
    this.source,
  });

  TaskState copyWith({
    String? id,
    TaskStatus? status,
    double? progress,
    String? speed,
    String? message,
    String? messageKey,
    Map<String, dynamic>? messageArgs,
    String? stage,
    String? packageName,
    String? source,
  }) {
    return TaskState(
      id: id ?? this.id,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      message: message ?? this.message,
      messageKey: messageKey ?? this.messageKey,
      messageArgs: messageArgs ?? this.messageArgs,
      stage: stage ?? this.stage,
      packageName: packageName ?? this.packageName,
      source: source ?? this.source,
    );
  }

  @override
  String toString() {
    return 'TaskState(id: $id, status: $status, progress: $progress, speed: $speed, message: $message, stage: $stage, packageName: $packageName, source: $source)';
  }
}
