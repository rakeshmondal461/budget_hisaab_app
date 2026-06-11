import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../../features/expenses/models/expense_model.dart';
import '../../features/tasks/models/task_model.dart';
import '../../features/expenses/providers/expense_provider.dart';
import '../../features/tasks/providers/task_provider.dart';

class ImportService {
  Future<String?> _pickFile(List<String> allowedExtensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (result != null && result.files.single.path != null) {
      return result.files.single.path;
    }
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'yes' || v == 'true' || v == '1' || v == 'income';
    }
    return false;
  }

  // ── JSON Import ───────────────────────────────────────────────────────────
  Future<void> importExpensesFromJson(ExpenseProvider provider) async {
    final path = await _pickFile(['json']);
    if (path == null) return;

    final file = File(path);
    final content = await file.readAsString();
    final data = jsonDecode(content);

    List<ExpenseModel> expenses = [];
    final Iterable listSource = data is List ? data : (data is Map && data.containsKey('expenses') ? data['expenses'] : []);
    
    for (final e in listSource) {
      try {
        expenses.add(ExpenseModel.fromJson(e as Map<String, dynamic>));
      } catch (_) {}
    }

    if (expenses.isNotEmpty) {
      await provider.importExpenses(expenses);
    }
  }

  Future<void> importTasksFromJson(TaskProvider provider) async {
    final path = await _pickFile(['json']);
    if (path == null) return;

    final file = File(path);
    final content = await file.readAsString();
    final data = jsonDecode(content);

    List<TaskModel> tasks = [];
    final Iterable listSource = data is List ? data : (data is Map && data.containsKey('tasks') ? data['tasks'] : []);
    
    for (final e in listSource) {
      try {
        tasks.add(TaskModel.fromJson(e as Map<String, dynamic>));
      } catch (_) {}
    }

    if (tasks.isNotEmpty) {
      await provider.importTasks(tasks);
    }
  }

  Future<void> importAllFromJson(ExpenseProvider expenseProvider, TaskProvider taskProvider) async {
    final path = await _pickFile(['json']);
    if (path == null) return;

    final file = File(path);
    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;

    if (data.containsKey('expenses')) {
      final list = data['expenses'] as List;
      final expenses = <ExpenseModel>[];
      for (final e in list) {
        try {
          expenses.add(ExpenseModel.fromJson(e as Map<String, dynamic>));
        } catch (_) {}
      }
      await expenseProvider.importExpenses(expenses);
    }

    if (data.containsKey('tasks')) {
      final list = data['tasks'] as List;
      final tasks = <TaskModel>[];
      for (final e in list) {
        try {
          tasks.add(TaskModel.fromJson(e as Map<String, dynamic>));
        } catch (_) {}
      }
      await taskProvider.importTasks(tasks);
    }

    if (data.containsKey('budgets')) {
      final budgetsData = data['budgets'] as Map<String, dynamic>;
      await expenseProvider.importBudgets(budgetsData);
    }
  }

  // ── CSV Import ────────────────────────────────────────────────────────────
  Future<void> importExpensesFromCsv(ExpenseProvider provider) async {
    final path = await _pickFile(['csv']);
    if (path == null) return;

    final file = File(path);
    final content = await file.readAsString();
    final rows = Csv().decode(content);
    if (rows.length <= 1) return; // Only header or empty

    final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();
    
    int colDate = headers.indexOf('date');
    int colAmount = headers.indexOf('amount');
    int colCategory = headers.indexOf('category');
    int colNote = headers.indexOf('note');
    int colType = headers.indexOf('type');
    int colFromSms = headers.indexOf('from sms');
    int colBank = headers.indexOf('bank');

    if (colDate == -1 || colAmount == -1 || colCategory == -1) {
      throw Exception('CSV must contain Date, Amount, and Category columns.');
    }

    List<ExpenseModel> expenses = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= colAmount) continue;

      try {
        final dateStr = row[colDate].toString();
        final amount = _parseDouble(row[colAmount]);
        final categoryStr = row[colCategory].toString();
        final note = colNote != -1 && row.length > colNote ? row[colNote].toString() : '';
        final isIncome = colType != -1 && row.length > colType ? _parseBool(row[colType]) : false;
        final fromSms = colFromSms != -1 && row.length > colFromSms ? _parseBool(row[colFromSms]) : false;
        final bankName = colBank != -1 && row.length > colBank ? row[colBank].toString() : null;

        ExpenseCategory? expCat;
        IncomeCategory? incCat;

        if (isIncome) {
          incCat = IncomeCategory.values.firstWhere(
            (e) => e.name.toLowerCase() == categoryStr.toLowerCase() || e.label.toLowerCase() == categoryStr.toLowerCase(),
            orElse: () => IncomeCategory.other,
          );
        } else {
          expCat = ExpenseCategory.values.firstWhere(
            (e) => e.name.toLowerCase() == categoryStr.toLowerCase() || e.label.toLowerCase() == categoryStr.toLowerCase(),
            orElse: () => ExpenseCategory.other,
          );
        }

        expenses.add(ExpenseModel(
          amount: amount,
          expenseCategory: expCat,
          incomeCategory: incCat,
          note: note,
          date: DateTime.parse(dateStr),
          isIncome: isIncome,
          fromSms: fromSms,
          bankName: bankName?.isEmpty == true ? null : bankName,
        ));
      } catch (_) {
        // Skip invalid rows
      }
    }

    if (expenses.isNotEmpty) {
      await provider.importExpenses(expenses);
    }
  }

  Future<void> importTasksFromCsv(TaskProvider provider) async {
    final path = await _pickFile(['csv']);
    if (path == null) return;

    final file = File(path);
    final content = await file.readAsString();
    final rows = Csv().decode(content);
    if (rows.length <= 1) return;

    final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();

    int colTitle = headers.indexOf('title');
    int colStatus = headers.indexOf('status');
    int colPriority = headers.indexOf('priority');
    int colDeadline = headers.indexOf('deadline');
    int colTags = headers.indexOf('tags');

    if (colTitle == -1) {
      throw Exception('CSV must contain a Title column.');
    }

    List<TaskModel> tasks = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= colTitle) continue;

      try {
        final title = row[colTitle].toString();
        final statusStr = colStatus != -1 && row.length > colStatus ? row[colStatus].toString() : '';
        final priorityStr = colPriority != -1 && row.length > colPriority ? row[colPriority].toString() : '';
        final deadlineStr = colDeadline != -1 && row.length > colDeadline ? row[colDeadline].toString() : '';
        final tagsStr = colTags != -1 && row.length > colTags ? row[colTags].toString() : '';

        final status = TaskStatus.values.firstWhere(
          (e) => e.name.toLowerCase() == statusStr.toLowerCase() || e.label.toLowerCase() == statusStr.toLowerCase(),
          orElse: () => TaskStatus.todo,
        );

        final priority = TaskPriority.values.firstWhere(
          (e) => e.name.toLowerCase() == priorityStr.toLowerCase() || e.label.toLowerCase() == priorityStr.toLowerCase(),
          orElse: () => TaskPriority.medium,
        );

        final deadline = deadlineStr.isNotEmpty ? DateTime.tryParse(deadlineStr) : null;
        final tags = tagsStr.isNotEmpty ? tagsStr.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : <String>[];

        tasks.add(TaskModel(
          title: title,
          status: status,
          priority: priority,
          deadline: deadline,
          tags: tags,
        ));
      } catch (_) {
        // Skip invalid rows
      }
    }

    if (tasks.isNotEmpty) {
      await provider.importTasks(tasks);
    }
  }
}
