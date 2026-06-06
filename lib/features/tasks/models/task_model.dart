import 'package:uuid/uuid.dart';

enum TaskStatus { todo, inProgress, done }
enum TaskPriority { low, medium, high, critical }

extension TaskStatusExt on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.todo: return 'To Do';
      case TaskStatus.inProgress: return 'In Progress';
      case TaskStatus.done: return 'Done';
    }
  }
  String get emoji {
    switch (this) {
      case TaskStatus.todo: return '📋';
      case TaskStatus.inProgress: return '⚡';
      case TaskStatus.done: return '✅';
    }
  }
}

extension TaskPriorityExt on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low: return 'Low';
      case TaskPriority.medium: return 'Medium';
      case TaskPriority.high: return 'High';
      case TaskPriority.critical: return 'Critical';
    }
  }
  int get colorValue {
    switch (this) {
      case TaskPriority.low: return 0xFF4CAF82;
      case TaskPriority.medium: return 0xFFFFD93D;
      case TaskPriority.high: return 0xFFFF9F43;
      case TaskPriority.critical: return 0xFFFF6B6B;
    }
  }
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? deadline;
  final double estimatedHours;
  final int focusedMinutes; // total minutes from focus sessions
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? completedAt;

  TaskModel({
    String? id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.deadline,
    this.estimatedHours = 1.0,
    this.focusedMinutes = 0,
    this.tags = const [],
    DateTime? createdAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isOverdue =>
      deadline != null &&
      DateTime.now().isAfter(deadline!) &&
      status != TaskStatus.done;

  double get progressPercent =>
      estimatedHours <= 0 ? 0 : (focusedMinutes / 60 / estimatedHours).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'status': status.name,
    'priority': priority.name,
    'deadline': deadline?.toIso8601String(),
    'estimatedHours': estimatedHours,
    'focusedMinutes': focusedMinutes,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'],
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    status: TaskStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => TaskStatus.todo,
    ),
    priority: TaskPriority.values.firstWhere(
      (e) => e.name == json['priority'],
      orElse: () => TaskPriority.medium,
    ),
    deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
    estimatedHours: (json['estimatedHours'] as num?)?.toDouble() ?? 1.0,
    focusedMinutes: json['focusedMinutes'] ?? 0,
    tags: List<String>.from(json['tags'] ?? []),
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
  );

  TaskModel copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? deadline,
    double? estimatedHours,
    int? focusedMinutes,
    List<String>? tags,
    DateTime? completedAt,
  }) => TaskModel(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    deadline: deadline ?? this.deadline,
    estimatedHours: estimatedHours ?? this.estimatedHours,
    focusedMinutes: focusedMinutes ?? this.focusedMinutes,
    tags: tags ?? this.tags,
    createdAt: createdAt,
    completedAt: completedAt ?? this.completedAt,
  );
}
