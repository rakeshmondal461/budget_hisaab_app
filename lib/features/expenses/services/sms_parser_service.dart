import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import '../models/expense_model.dart';

class SmsParserService {
  static final _amountRegex = RegExp(
    r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
    caseSensitive: false,
  );

  static final _debitKeywords = [
    'debited', 'debit', 'spent', 'paid', 'purchase', 'transaction',
    'withdrawn', 'withdrawal', 'payment', 'sent',
  ];

  static final _creditKeywords = [
    'credited', 'credit', 'received', 'deposited', 'refund',
  ];

  static final _bankPatterns = [
    RegExp(r'\bHDFC\b', caseSensitive: false),
    RegExp(r'\bSBI\b', caseSensitive: false),
    RegExp(r'\bICICI\b', caseSensitive: false),
    RegExp(r'\bAxis\b', caseSensitive: false),
    RegExp(r'\bKotak\b', caseSensitive: false),
    RegExp(r'\bIDFC\b', caseSensitive: false),
    RegExp(r'\bYES BANK\b', caseSensitive: false),
    RegExp(r'\bPNB\b', caseSensitive: false),
    RegExp(r'\bCanara\b', caseSensitive: false),
    RegExp(r'\bBoB\b', caseSensitive: false),
    RegExp(r'\bUnion Bank\b', caseSensitive: false),
    RegExp(r'\bIndusInd\b', caseSensitive: false),
    RegExp(r'\bAmazon Pay\b', caseSensitive: false),
    RegExp(r'\bPhonePe\b', caseSensitive: false),
    RegExp(r'\bPaytm\b', caseSensitive: false),
    RegExp(r'\bGPay\b', caseSensitive: false),
    RegExp(r'\bGoogle Pay\b', caseSensitive: false),
    RegExp(r'\bUPI\b', caseSensitive: false),
  ];

  static Future<List<ExpenseModel>> parseTransactions() async {
    try {
      final query = SmsQuery();
      // Read inbox messages
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 500,
      );

      final expenses = <ExpenseModel>[];
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

      for (final msg in messages) {
        final date = msg.date ?? DateTime.now();
        if (date.isBefore(threeDaysAgo)) continue;

        final body = msg.body ?? '';
        if (body.isEmpty) continue;

        final amountMatch = _amountRegex.firstMatch(body);
        if (amountMatch == null) continue;

        final amountStr = amountMatch.group(1)!.replaceAll(',', '');
        final amount = double.tryParse(amountStr);
        if (amount == null || amount <= 0) continue;

        // Determine debit or credit
        final bodyLower = body.toLowerCase();
        final isDebit = _debitKeywords.any((k) => bodyLower.contains(k));
        final isCredit = _creditKeywords.any((k) => bodyLower.contains(k));

        if (!isDebit && !isCredit) continue;

        // Detect bank
        String? bankName;
        for (final pattern in _bankPatterns) {
          if (pattern.hasMatch(body)) {
            bankName = pattern.firstMatch(body)!.group(0);
            break;
          }
        }

        // Guess category from message
        final isIncomeEntry = isCredit && !isDebit;
        final category = _guessCategory(body);

        expenses.add(ExpenseModel(
          amount: amount,
          expenseCategory: isIncomeEntry ? null : category,
          incomeCategory: isIncomeEntry ? IncomeCategory.other : null,
          note: _extractNote(body),
          date: date,
          isIncome: isIncomeEntry,
          fromSms: true,
          bankName: bankName,
        ));
      }

      return expenses;
    } catch (e) {
      return [];
    }
  }

  static ExpenseCategory _guessCategory(String body) {
    final b = body.toLowerCase();
    if (b.contains('swiggy') || b.contains('zomato') || b.contains('food') ||
        b.contains('restaurant') || b.contains('cafe') || b.contains('hotel') ||
        b.contains('pizza') || b.contains('burger')) {
      return ExpenseCategory.food;
    }
    if (b.contains('uber') || b.contains('ola') || b.contains('metro') ||
        b.contains('irctc') || b.contains('railway') || b.contains('bus') ||
        b.contains('petrol') || b.contains('fuel') || b.contains('cab')) {
      return ExpenseCategory.transport;
    }
    if (b.contains('amazon') || b.contains('flipkart') || b.contains('myntra') ||
        b.contains('shop') || b.contains('mall') || b.contains('store')) {
      return ExpenseCategory.shopping;
    }
    if (b.contains('electricity') || b.contains('water') || b.contains('gas') ||
        b.contains('bill') || b.contains('jio') || b.contains('airtel') ||
        b.contains('bsnl') || b.contains('recharge')) {
      return ExpenseCategory.bills;
    }
    if (b.contains('hospital') || b.contains('pharmacy') || b.contains('medical') ||
        b.contains('doctor') || b.contains('health') || b.contains('clinic')) {
      return ExpenseCategory.health;
    }
    if (b.contains('netflix') || b.contains('hotstar') || b.contains('prime') ||
        b.contains('spotify') || b.contains('movie') || b.contains('cinema') ||
        b.contains('theatre') || b.contains('pvr')) {
      return ExpenseCategory.entertainment;
    }
    return ExpenseCategory.other;
  }

  static String _extractNote(String body) {
    // Try to find merchant name via common patterns
    final patterns = [
      RegExp(r'at\s+([A-Z][A-Za-z0-9\s]+?)(?:\s+on|\s+for|\s+ref|\s+via|\.)', caseSensitive: false),
      RegExp(r'to\s+([A-Z][A-Za-z0-9\s]+?)(?:\s+on|\s+for|\s+ref|\.)', caseSensitive: false),
      RegExp(r'for\s+([A-Z][A-Za-z0-9\s]+?)(?:\s+on|\s+ref|\.)', caseSensitive: false),
    ];
    for (final p in patterns) {
      final match = p.firstMatch(body);
      if (match != null) {
        return match.group(1)!.trim();
      }
    }
    // Fallback: first 60 chars of body
    return body.length > 60 ? body.substring(0, 60) : body;
  }
}
