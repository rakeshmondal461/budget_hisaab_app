import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/settings/providers/settings_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  final ExpenseModel? editExpense;
  const AddExpenseScreen({super.key, this.editExpense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  ExpenseCategory _expenseCategory = ExpenseCategory.food;
  IncomeCategory _incomeCategory = IncomeCategory.salary;
  DateTime _date = DateTime.now();
  bool _isIncome = false;

  @override
  void initState() {
    super.initState();
    if (widget.editExpense != null) {
      final e = widget.editExpense!;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _noteCtrl.text = e.note;
      _date = e.date;
      _isIncome = e.isIncome;
      if (e.isIncome) {
        _incomeCategory = e.incomeCategory ?? IncomeCategory.salary;
      } else {
        _expenseCategory = e.expenseCategory ?? ExpenseCategory.food;
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbol = context.watch<SettingsProvider>().currency;
    final isEditing = widget.editExpense != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Expense'),
                    content: const Text(
                        'Are you sure you want to delete this expense?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: AppTheme.errorColor)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  context
                      .read<ExpenseProvider>()
                      .deleteExpense(widget.editExpense!.id);
                  context.pop();
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Income/Expense Toggle ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TypeTab(
                      label: 'Expense',
                      icon: Icons.arrow_upward,
                      isSelected: !_isIncome,
                      color: AppTheme.errorColor,
                      onTap: () => setState(() => _isIncome = false),
                    ),
                  ),
                  Expanded(
                    child: _TypeTab(
                      label: 'Income',
                      icon: Icons.arrow_downward,
                      isSelected: _isIncome,
                      color: AppTheme.successColor,
                      onTap: () => setState(() => _isIncome = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Amount ─────────────────────────────────────────────────────
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.displayMedium?.copyWith(
                color: _isIncome ? AppTheme.successColor : AppTheme.errorColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Amount ($symbol)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if (double.tryParse(v) == null) return 'Invalid number';
                if (double.parse(v) <= 0) return 'Amount must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Category ───────────────────────────────────────────────────
            Text('Category', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _isIncome ? _buildIncomeCategories(theme) : _buildExpenseCategories(theme),
            const SizedBox(height: 20),

            // ── Date ───────────────────────────────────────────────────────
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              tileColor: theme.cardColor,
              leading:
                  Icon(Icons.calendar_today, color: theme.colorScheme.primary),
              title: Text('Date', style: theme.textTheme.titleMedium),
              subtitle: Text(
                DateFormat('EEEE, MMMM d yyyy').format(_date),
                style: theme.textTheme.bodySmall,
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),

            // ── Note ───────────────────────────────────────────────────────
            TextFormField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'What was this for?',
                prefixIcon: const Icon(Icons.notes),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),

            // ── Save Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isIncome
                      ? AppTheme.successColor
                      : theme.colorScheme.primary,
                ),
                child: Text(
                  isEditing ? 'Update' : 'Save',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Expense Category Chips ──────────────────────────────────────────────
  Widget _buildExpenseCategories(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.values.map((cat) {
        final isSelected = _expenseCategory == cat;
        final color = AppTheme.categoryColors[
            cat.index % AppTheme.categoryColors.length];
        return GestureDetector(
          onTap: () => setState(() => _expenseCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  cat.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Income Category Chips ───────────────────────────────────────────────
  Widget _buildIncomeCategories(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: IncomeCategory.values.map((cat) {
        final isSelected = _incomeCategory == cat;
        final color = AppTheme.categoryColors[
            (ExpenseCategory.values.length + cat.index) %
                AppTheme.categoryColors.length];
        return GestureDetector(
          onTap: () => setState(() => _incomeCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  cat.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ExpenseProvider>();
    final expense = ExpenseModel(
      id: widget.editExpense?.id,
      amount: double.parse(_amountCtrl.text),
      expenseCategory: _isIncome ? null : _expenseCategory,
      incomeCategory: _isIncome ? _incomeCategory : null,
      note: _noteCtrl.text.trim(),
      date: _date,
      isIncome: _isIncome,
    );

    if (widget.editExpense != null) {
      provider.updateExpense(expense);
    } else {
      provider.addExpense(expense);
    }
    context.pop();
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
