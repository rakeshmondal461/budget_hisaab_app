import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/expense_model.dart';
import '../models/budget_model.dart';
import '../services/sms_parser_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/google_drive_service.dart';

class ExpenseProvider extends ChangeNotifier {
  static const _expensesFile = 'expenses.json';
  static const _budgetsFile = 'budgets.json';

  final LocalStorageService _local;
  final GoogleDriveService _drive;

  List<ExpenseModel> _expenses = [];
  Map<String, BudgetModel> _budgets = {}; // key: "year-month"
  bool _isLoading = false;
  String? _error;

  List<ExpenseModel> get expenses => List.unmodifiable(_expenses);
  bool get isLoading => _isLoading;
  String? get error => _error;

  ExpenseProvider(this._local, this._drive) {
    load();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _budgetKey(int year, int month) => '$year-$month';

  BudgetModel budgetFor(int year, int month) =>
      _budgets[_budgetKey(year, month)] ?? BudgetModel.empty(month, year);

  List<ExpenseModel> expensesForMonth(int year, int month) =>
      _expenses.where((e) => e.date.year == year && e.date.month == month).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  double totalSpentForMonth(int year, int month) =>
      expensesForMonth(year, month)
          .where((e) => !e.isIncome)
          .fold(0.0, (sum, e) => sum + e.amount);

  double totalIncomeForMonth(int year, int month) =>
      expensesForMonth(year, month)
          .where((e) => e.isIncome)
          .fold(0.0, (sum, e) => sum + e.amount);

  Map<ExpenseCategory, double> spendByCategory(int year, int month) {
    final map = <ExpenseCategory, double>{};
    for (final e in expensesForMonth(year, month).where((e) => !e.isIncome)) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  /// Actual savings = income tracked − expenses tracked for the month.
  double actualSavingsForMonth(int year, int month) =>
      totalIncomeForMonth(year, month) - totalSpentForMonth(year, month);

  /// Progress toward the savings target (0.0–1.0). Returns 0 if no target set.
  double savingsProgressForMonth(int year, int month) {
    final budget = budgetFor(year, month);
    if (budget.savingsTarget <= 0) return 0;
    return (actualSavingsForMonth(year, month) / budget.savingsTarget).clamp(0.0, 1.0);
  }

  /// Sum of expenses for a specific calendar day, excluding income.
  double totalSpentForDay(DateTime day) =>
      _expenses
          .where((e) =>
              !e.isIncome &&
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day)
          .fold(0.0, (s, e) => s + e.amount);

  /// Per-category spend for a specific calendar day.
  Map<ExpenseCategory, double> spendByCategoryForDay(DateTime day) {
    final map = <ExpenseCategory, double>{};
    for (final e in _expenses.where((e) =>
        !e.isIncome &&
        e.date.year == day.year &&
        e.date.month == day.month &&
        e.date.day == day.day)) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  /// Daily budget limit = totalBudget / daysInMonth.
  /// Returns 0 if no budget is set.
  double dailyBudgetLimit(int year, int month) {
    final b = budgetFor(year, month);
    if (b.totalBudget <= 0) return 0;
    final days = DateTime(year, month + 1, 0).day;
    return b.totalBudget / days;
  }

  /// Per-category daily limit = categoryBudget / daysInMonth.
  Map<ExpenseCategory, double> dailyCategoryLimits(int year, int month) {
    final b = budgetFor(year, month);
    final days = DateTime(year, month + 1, 0).day;
    return b.categoryBudgets.map((k, v) => MapEntry(k, v / days));
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────
  Future<void> addExpense(ExpenseModel expense) async {
    _expenses.insert(0, expense);
    notifyListeners();
    await _save();
  }

  Future<void> updateExpense(ExpenseModel updated) async {
    final idx = _expenses.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      _expenses[idx] = updated;
      notifyListeners();
      await _save();
    }
  }

  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> saveBudget(BudgetModel budget) async {
    _budgets[_budgetKey(budget.year, budget.month)] = budget;
    notifyListeners();
    await _saveBudgets();
  }

  // ── SMS Import ─────────────────────────────────────────────────────────────
  Future<List<ExpenseModel>> fetchSmsExpenses() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) return [];
    return SmsParserService.parseTransactions();
  }

  Future<void> importSmsExpenses(List<ExpenseModel> selected) async {
    for (final e in selected) {
      if (!_expenses.any((ex) =>
          ex.bankName == e.bankName &&
          ex.amount == e.amount &&
          ex.date == e.date)) {
        _expenses.insert(0, e);
      }
    }
    notifyListeners();
    await _save();
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_drive.isSignedIn) {
        await _drive.downloadFile(_expensesFile);
        await _drive.downloadFile(_budgetsFile);
      }

      final expensesList = await _local.readList(_expensesFile);
      _expenses = expensesList.map(ExpenseModel.fromJson).toList();

      final budgetsMap = await _local.readMap(_budgetsFile);
      _budgets = budgetsMap.map(
        (k, v) => MapEntry(k, BudgetModel.fromJson(v as Map<String, dynamic>)),
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final data = _expenses.map((e) => e.toJson()).toList();
    await _local.writeList(_expensesFile, data);
    if (_drive.isSignedIn) {
      await _drive.uploadFile(_expensesFile, data.toString());
    }
  }

  Future<void> _saveBudgets() async {
    final data = _budgets.map((k, v) => MapEntry(k, v.toJson()));
    await _local.writeMap(_budgetsFile, data);
  }

  List<Map<String, dynamic>> toJsonList() =>
      _expenses.map((e) => e.toJson()).toList();

  Map<String, dynamic> budgetsToJson() =>
      _budgets.map((k, v) => MapEntry(k, v.toJson()));
}
