import 'package:uuid/uuid.dart';

enum ExpenseCategory {
  food,
  transport,
  shopping,
  bills,
  health,
  entertainment,
  other,
  salary,
  freelance,
  investment,
}

extension ExpenseCategoryExt on ExpenseCategory {
  String get label {
    switch (this) {
      case ExpenseCategory.food: return 'Food & Dining';
      case ExpenseCategory.transport: return 'Transport';
      case ExpenseCategory.shopping: return 'Shopping';
      case ExpenseCategory.bills: return 'Bills & Utilities';
      case ExpenseCategory.health: return 'Health';
      case ExpenseCategory.entertainment: return 'Entertainment';
      case ExpenseCategory.other: return 'Other';
      case ExpenseCategory.salary: return 'Salary';
      case ExpenseCategory.freelance: return 'Freelance';
      case ExpenseCategory.investment: return 'Investment';
    }
  }

  String get emoji {
    switch (this) {
      case ExpenseCategory.food: return '🍔';
      case ExpenseCategory.transport: return '🚗';
      case ExpenseCategory.shopping: return '🛍️';
      case ExpenseCategory.bills: return '📄';
      case ExpenseCategory.health: return '💊';
      case ExpenseCategory.entertainment: return '🎬';
      case ExpenseCategory.other: return '📦';
      case ExpenseCategory.salary: return '💰';
      case ExpenseCategory.freelance: return '💻';
      case ExpenseCategory.investment: return '📈';
    }
  }
}

class ExpenseModel {
  final String id;
  final double amount;
  final ExpenseCategory category;
  final String note;
  final DateTime date;
  final bool isIncome;
  final bool fromSms;
  final String? bankName;

  ExpenseModel({
    String? id,
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
    this.isIncome = false,
    this.fromSms = false,
    this.bankName,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': category.name,
    'note': note,
    'date': date.toIso8601String(),
    'isIncome': isIncome,
    'fromSms': fromSms,
    'bankName': bankName,
  };

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
    id: json['id'],
    amount: (json['amount'] as num).toDouble(),
    category: ExpenseCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => ExpenseCategory.other,
    ),
    note: json['note'] ?? '',
    date: DateTime.parse(json['date']),
    isIncome: json['isIncome'] ?? false,
    fromSms: json['fromSms'] ?? false,
    bankName: json['bankName'],
  );

  ExpenseModel copyWith({
    double? amount,
    ExpenseCategory? category,
    String? note,
    DateTime? date,
    bool? isIncome,
  }) => ExpenseModel(
    id: id,
    amount: amount ?? this.amount,
    category: category ?? this.category,
    note: note ?? this.note,
    date: date ?? this.date,
    isIncome: isIncome ?? this.isIncome,
    fromSms: fromSms,
    bankName: bankName,
  );
}
