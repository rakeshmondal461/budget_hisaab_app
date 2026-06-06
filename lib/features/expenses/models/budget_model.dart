import 'expense_model.dart';

class BudgetModel {
  final Map<ExpenseCategory, double> categoryBudgets;
  final double totalBudget;
  final double savingsTarget;
  final double monthlyIncome;
  final bool isAutoMode;
  final int month;
  final int year;

  /// Priority weights for auto budget allocation.
  /// Food, Transport & Health get first priority.
  static const Map<ExpenseCategory, double> priorityWeights = {
    ExpenseCategory.food: 0.25,
    ExpenseCategory.transport: 0.15,
    ExpenseCategory.health: 0.10,
    ExpenseCategory.bills: 0.15,
    ExpenseCategory.shopping: 0.15,
    ExpenseCategory.entertainment: 0.10,
    ExpenseCategory.other: 0.10,
  };

  BudgetModel({
    required this.categoryBudgets,
    required this.totalBudget,
    this.savingsTarget = 0,
    this.monthlyIncome = 0,
    this.isAutoMode = false,
    required this.month,
    required this.year,
  });

  factory BudgetModel.empty(int month, int year) => BudgetModel(
        categoryBudgets: {},
        totalBudget: 0,
        month: month,
        year: year,
      );

  /// Auto-calculates category budgets from a savings plan.
  /// spendable = income - savingsTarget, then split by [priorityWeights].
  factory BudgetModel.fromSavingsPlan({
    required double income,
    required double savingsTarget,
    required int month,
    required int year,
  }) {
    final spendable = (income - savingsTarget).clamp(0.0, income);
    final catBudgets = <ExpenseCategory, double>{};
    for (final entry in priorityWeights.entries) {
      catBudgets[entry.key] = spendable * entry.value;
    }
    return BudgetModel(
      categoryBudgets: catBudgets,
      totalBudget: spendable,
      savingsTarget: savingsTarget,
      monthlyIncome: income,
      isAutoMode: true,
      month: month,
      year: year,
    );
  }

  Map<String, dynamic> toJson() => {
        'categoryBudgets': categoryBudgets.map((k, v) => MapEntry(k.name, v)),
        'totalBudget': totalBudget,
        'savingsTarget': savingsTarget,
        'monthlyIncome': monthlyIncome,
        'isAutoMode': isAutoMode,
        'month': month,
        'year': year,
      };

  factory BudgetModel.fromJson(Map<String, dynamic> json) => BudgetModel(
        categoryBudgets:
            (json['categoryBudgets'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(
            ExpenseCategory.values.firstWhere(
              (e) => e.name == k,
              orElse: () => ExpenseCategory.other,
            ),
            (v as num).toDouble(),
          ),
        ),
        totalBudget: (json['totalBudget'] as num?)?.toDouble() ?? 0,
        savingsTarget: (json['savingsTarget'] as num?)?.toDouble() ?? 0,
        monthlyIncome: (json['monthlyIncome'] as num?)?.toDouble() ?? 0,
        isAutoMode: json['isAutoMode'] ?? false,
        month: json['month'] ?? DateTime.now().month,
        year: json['year'] ?? DateTime.now().year,
      );

  BudgetModel copyWith({
    Map<ExpenseCategory, double>? categoryBudgets,
    double? totalBudget,
    double? savingsTarget,
    double? monthlyIncome,
    bool? isAutoMode,
  }) =>
      BudgetModel(
        categoryBudgets: categoryBudgets ?? this.categoryBudgets,
        totalBudget: totalBudget ?? this.totalBudget,
        savingsTarget: savingsTarget ?? this.savingsTarget,
        monthlyIncome: monthlyIncome ?? this.monthlyIncome,
        isAutoMode: isAutoMode ?? this.isAutoMode,
        month: month,
        year: year,
      );
}
