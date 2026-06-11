import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../../../core/theme/app_theme.dart';

class ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final String symbol;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.symbol,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = AppTheme.categoryColors[
        expense.categoryColorIndex % AppTheme.categoryColors.length];
    final amountColor =
        expense.isIncome ? AppTheme.successColor : AppTheme.errorColor;

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete Expense'),
                content:
                    const Text('Are you sure you want to delete this expense?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete',
                        style: TextStyle(color: AppTheme.errorColor)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(expense.categoryEmoji,
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expense.note.isEmpty
                                ? expense.categoryLabel
                                : expense.note,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (expense.fromSms)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentDark.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SMS',
                              style: TextStyle(
                                  color: AppTheme.accentDark,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          expense.categoryLabel,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: catColor),
                        ),
                        if (expense.bankName != null) ...[
                          Text(' · ', style: theme.textTheme.bodySmall),
                          Text(expense.bankName!,
                              style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${expense.isIncome ? '+' : '-'}$symbol${NumberFormat('#,##0.00').format(expense.amount)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('h:mm a').format(expense.date),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
