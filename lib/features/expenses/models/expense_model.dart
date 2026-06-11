import 'package:uuid/uuid.dart';

// ── Expense Categories (spending) ───────────────────────────────────────────
enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  health,
  entertainment,
  other,
}

extension ExpenseCategoryExt on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food:
        return 'Food & Dining';
      case ExpenseCategory.transport:
        return 'Transport';
      case ExpenseCategory.shopping:
        return 'Shopping';
      case ExpenseCategory.bills:
        return 'Bills & Utilities';
      case ExpenseCategory.health:
        return 'Health';
      case ExpenseCategory.entertainment:
        return 'Entertainment';
      case ExpenseCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case ExpenseCategory.food:
        return '🍔';
      case ExpenseCategory.transport:
        return '🚗';
      case ExpenseCategory.shopping:
        return '🛍️';
      case ExpenseCategory.bills:
        return '📄';
      case ExpenseCategory.health:
        return '💊';
      case ExpenseCategory.entertainment:
        return '🎬';
      case ExpenseCategory.other:
        return '📦';
    }
  }
}

// ── Income Categories ───────────────────────────────────────────────────────
enum IncomeCategory { salary, business, freelance, investment, other }

extension IncomeCategoryExt on IncomeCategory {
  String get label {
    switch (this) {
      case IncomeCategory.salary:
        return 'Salary';
      case IncomeCategory.business:
        return 'Business';
      case IncomeCategory.freelance:
        return 'Freelance';
      case IncomeCategory.investment:
        return 'Investment';
      case IncomeCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case IncomeCategory.salary:
        return '💰';
      case IncomeCategory.business:
        return '💼';
      case IncomeCategory.freelance:
        return '💻';
      case IncomeCategory.investment:
        return '📈';
      case IncomeCategory.other:
        return '📦';
    }
  }
}

// ── Expense / Income Model ──────────────────────────────────────────────────
class ExpenseModel {
  final String id;
  final double amount;
  final ExpenseCategory? expenseCategory;
  final IncomeCategory? incomeCategory;
  final String note;
  final DateTime date;
  final bool isIncome;
  final bool fromSms;
  final String? bankName;

  ExpenseModel({
    String? id,
    required this.amount,
    this.expenseCategory,
    this.incomeCategory,
    this.note = '',
    required this.date,
    this.isIncome = false,
    this.fromSms = false,
    this.bankName,
  }) : id = id ?? const Uuid().v4(),
       assert(
         (!isIncome && expenseCategory != null) ||
             (isIncome && incomeCategory != null),
         'Expense must have expenseCategory; income must have incomeCategory',
       );

  // ── Display helpers ─────────────────────────────────────────────────────
  String get categoryLabel =>
      isIncome ? incomeCategory!.label : expenseCategory!.label;

  String get categoryEmoji =>
      isIncome ? incomeCategory!.emoji : expenseCategory!.emoji;

  /// Color index for [AppTheme.categoryColors].
  /// Income categories start after expense indices so they don't clash.
  int get categoryColorIndex => isIncome
      ? ExpenseCategory.values.length + incomeCategory!.index
      : expenseCategory!.index;

  // ── Serialization ───────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': isIncome ? incomeCategory!.name : expenseCategory!.name,
    'categoryType': isIncome ? 'income' : 'expense',
    'note': note,
    'date': date.toIso8601String(),
    'isIncome': isIncome,
    'fromSms': fromSms,
    'bankName': bankName,
  };

  /// Backward-compatible: old data has no `categoryType` field.
  /// We use `isIncome` to decide which enum to look up.
  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    final isIncome = json['isIncome'] ?? false;
    final catName = json['category'] as String? ?? 'other';

    ExpenseCategory? expCat;
    IncomeCategory? incCat;

    if (isIncome) {
      incCat = IncomeCategory.values.firstWhere(
        (e) => e.name == catName,
        orElse: () => IncomeCategory.other,
      );
    } else {
      expCat = ExpenseCategory.values.firstWhere(
        (e) => e.name == catName,
        orElse: () => ExpenseCategory.other,
      );
    }

    return ExpenseModel(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      expenseCategory: expCat,
      incomeCategory: incCat,
      note: json['note'] ?? '',
      date: DateTime.parse(json['date']),
      isIncome: isIncome,
      fromSms: json['fromSms'] ?? false,
      bankName: json['bankName'],
    );
  }

  ExpenseModel copyWith({
    double? amount,
    ExpenseCategory? expenseCategory,
    IncomeCategory? incomeCategory,
    String? note,
    DateTime? date,
    bool? isIncome,
  }) {
    final newIsIncome = isIncome ?? this.isIncome;
    return ExpenseModel(
      id: id,
      amount: amount ?? this.amount,
      expenseCategory: newIsIncome
          ? null
          : (expenseCategory ?? this.expenseCategory),
      incomeCategory: newIsIncome
          ? (incomeCategory ?? this.incomeCategory)
          : null,
      note: note ?? this.note,
      date: date ?? this.date,
      isIncome: newIsIncome,
      fromSms: fromSms,
      bankName: bankName,
    );
  }
}
