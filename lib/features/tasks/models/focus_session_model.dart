import 'package:uuid/uuid.dart';

class FocusSessionModel {
  final String id;
  final String taskId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final bool completed; // false if user ended early

  FocusSessionModel({
    String? id,
    required this.taskId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.completed = true,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationMinutes': durationMinutes,
    'completed': completed,
  };

  factory FocusSessionModel.fromJson(Map<String, dynamic> json) => FocusSessionModel(
    id: json['id'],
    taskId: json['taskId'],
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    durationMinutes: json['durationMinutes'] ?? 25,
    completed: json['completed'] ?? true,
  );
}
