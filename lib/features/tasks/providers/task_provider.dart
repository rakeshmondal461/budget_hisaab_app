import 'package:flutter/foundation.dart';
import '../models/task_model.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/google_drive_service.dart';
import '../../../core/services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  static const _tasksFile = 'tasks.json';

  final LocalStorageService _local;
  // ignore: unused_field
  final GoogleDriveService _drive;

  List<TaskModel> _tasks = [];
  bool _isLoading = false;

  List<TaskModel> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;

  List<TaskModel> get todoTasks =>
      _tasks.where((t) => t.status == TaskStatus.todo).toList();
  List<TaskModel> get inProgressTasks =>
      _tasks.where((t) => t.status == TaskStatus.inProgress).toList();
  List<TaskModel> get doneTasks =>
      _tasks.where((t) => t.status == TaskStatus.done).toList();
  List<TaskModel> get overdueTasks =>
      _tasks.where((t) => t.isOverdue).toList();

  TaskProvider(this._local, this._drive) {
    load();
  }

  TaskModel? findById(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────
  Future<void> addTask(TaskModel task) async {
    _tasks.insert(0, task);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> updateTask(TaskModel updated) async {
    final idx = _tasks.indexWhere((t) => t.id == updated.id);
    if (idx >= 0) {
      _tasks[idx] = updated;
      notifyListeners();
      await _saveTasks();
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> importTasks(List<TaskModel> imported) async {
    int addedCount = 0;
    for (final t in imported) {
      if (!_tasks.any((ex) => ex.id == t.id)) {
        _tasks.insert(0, t);
        addedCount++;
      }
    }
    if (addedCount > 0) {
      notifyListeners();
      await _saveTasks();
    }
  }

  Future<void> moveTaskStatus(String id, TaskStatus newStatus) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _tasks[idx] = _tasks[idx].copyWith(
        status: newStatus,
        completedAt: newStatus == TaskStatus.done ? DateTime.now() : null,
      );
      notifyListeners();
      await _saveTasks();
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final tasksList = await _local.readList(_tasksFile);
      _tasks = tasksList.map(TaskModel.fromJson).toList();

      try {
        await NotificationService().updateTaskReminder(_tasks);
      } catch (_) {}
    } catch (_) {} finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveTasks() async {
    final data = _tasks.map((t) => t.toJson()).toList();
    await _local.writeList(_tasksFile, data);
    try {
      await NotificationService().updateTaskReminder(_tasks);
    } catch (_) {}
  }

  List<Map<String, dynamic>> toJsonList() => _tasks.map((t) => t.toJson()).toList();
}
