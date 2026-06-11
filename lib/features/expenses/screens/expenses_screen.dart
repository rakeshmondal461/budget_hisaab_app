import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../widgets/expense_card.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _touchedPieIndex = -1;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;
    final theme = Theme.of(context);

    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;
    final totalSpent = provider.totalSpentForMonth(year, month);
    final totalIncome = provider.totalIncomeForMonth(year, month);
    final budget = provider.budgetFor(year, month);
    final budgetAmount = budget.totalBudget;
    final expenses = provider.expensesForMonth(year, month);
    final categorySpend = provider.spendByCategory(year, month);
    final symbol = settings.currency;
    // Daily budget data (only meaningful for current month)
    final dailyLimit = isCurrentMonth
        ? provider.dailyBudgetLimit(year, month)
        : 0.0;
    final todaySpent = isCurrentMonth ? provider.totalSpentForDay(now) : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FloatingActionButton.small(
          //   heroTag: 'sms',
          //   backgroundColor: AppTheme.accentDark,
          //   foregroundColor: Colors.black87,
          //   onPressed: () => _importFromSms(context),
          //   child: const Icon(Icons.sms_outlined),
          // ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => context.push('/expenses/add'),
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => provider.load(),
        child: CustomScrollView(
          slivers: [
            // ── Month Selector ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _MonthSelector(
                selected: _selectedMonth,
                onChanged: (d) => setState(() => _selectedMonth = d),
              ),
            ),

            // ── Summary Card ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _SummaryCard(
                totalSpent: totalSpent,
                totalIncome: totalIncome,
                budgetAmount: budgetAmount,
                symbol: symbol,
                isDark: isDark,
              ),
            ),

            // ── Daily Budget Alert ─────────────────────────────────────────
            if (isCurrentMonth && dailyLimit > 0)
              SliverToBoxAdapter(
                child: _DailyBudgetAlert(
                  todaySpent: todaySpent,
                  dailyLimit: dailyLimit,
                  symbol: symbol,
                ),
              ),

            // ── Pie Chart ──────────────────────────────────────────────────
            if (categorySpend.isNotEmpty)
              SliverToBoxAdapter(
                child: _CategoryPieChart(
                  categorySpend: categorySpend,
                  symbol: symbol,
                  touchedIndex: _touchedPieIndex,
                  onTouch: (i) => setState(() => _touchedPieIndex = i),
                ),
              ),

            // ── Transactions Header ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Transactions', style: theme.textTheme.titleLarge),
                    Text(
                      '${expenses.length} records',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),

            // ── Transactions List ──────────────────────────────────────────
            if (expenses.isEmpty)
              SliverToBoxAdapter(child: _EmptyState(symbol: symbol))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final expense = expenses[i];
                  // Date separator
                  final showDate =
                      i == 0 || !_isSameDay(expenses[i - 1].date, expense.date);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDate)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Text(
                            _formatDateHeader(expense.date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ExpenseCard(
                        expense: expense,
                        symbol: symbol,
                        onDelete: () => provider.deleteExpense(expense.id),
                        onTap: () =>
                            context.push('/expenses/add', extra: expense),
                      ),
                    ],
                  );
                }, childCount: expenses.length),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1))))
      return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  Future<void> _importFromSms(BuildContext context) async {
    final provider = context.read<ExpenseProvider>();
    final theme = Theme.of(context); // capture before async gap

    // ── Step 1: Show a properly themed loading dialog ──────────────────────
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryDark),
              const SizedBox(height: 20),
              Text('Reading bank SMS…', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Scanning last 500 messages',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );

    // ── Step 2: Parse SMS with error safety ───────────────────────────────
    List<ExpenseModel> parsed = [];
    try {
      parsed = await provider.fetchSmsExpenses();
    } catch (_) {
      parsed = [];
    } finally {
      // Always dismiss the loading dialog, even on error
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) return;

    // ── Step 3: Handle empty result ───────────────────────────────────────
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No bank transactions found in SMS'),
          backgroundColor: theme.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    // ── Step 4: Show selection bottom sheet ───────────────────────────────
    final selected = <bool>[...List.filled(parsed.length, true)];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Found ${parsed.length} transactions',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          '${selected.where((v) => v).length} selected',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final toImport = [
                          for (int i = 0; i < parsed.length; i++)
                            if (selected[i]) parsed[i],
                        ];
                        if (toImport.isEmpty) {
                          Navigator.pop(ctx);
                          return;
                        }
                        await provider.importSmsExpenses(toImport);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Imported ${toImport.length} transactions',
                              ),
                              backgroundColor: AppTheme.successColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Import',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              // Transaction list
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: parsed.length,
                  itemBuilder: (_, i) => CheckboxListTile(
                    value: selected[i],
                    activeColor: AppTheme.primaryDark,
                    onChanged: (v) => setS(() => selected[i] = v!),
                    title: Text(
                      parsed[i].note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      '${parsed[i].isIncome ? '+' : '-'}₹${parsed[i].amount.toStringAsFixed(2)} · ${parsed[i].categoryLabel}',
                      style: theme.textTheme.bodySmall,
                    ),
                    secondary: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('MMM d').format(parsed[i].date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          parsed[i].isIncome
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: 14,
                          color: parsed[i].isIncome
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  const _MonthSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                onChanged(DateTime(selected.year, selected.month - 1)),
          ),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selected,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDatePickerMode: DatePickerMode.year,
              );
              if (picked != null) {
                onChanged(DateTime(picked.year, picked.month));
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                DateFormat('MMMM yyyy').format(selected),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                selected.year == DateTime.now().year &&
                    selected.month == DateTime.now().month
                ? null
                : () => onChanged(DateTime(selected.year, selected.month + 1)),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalSpent;
  final double totalIncome;
  final double budgetAmount;
  final String symbol;
  final bool isDark;

  const _SummaryCard({
    required this.totalSpent,
    required this.totalIncome,
    required this.budgetAmount,
    required this.symbol,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final budgetUsed = budgetAmount > 0
        ? (totalSpent / budgetAmount).clamp(0.0, 1.0)
        : 0.0;
    final budgetColor = budgetUsed > 0.9
        ? AppTheme.errorColor
        : budgetUsed > 0.7
        ? AppTheme.warningColor
        : AppTheme.successColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryDark,
            AppTheme.primaryDark.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Spent',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '$symbol${NumberFormat('#,##0.00').format(totalSpent)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(
                label: 'Income',
                value: '+$symbol${NumberFormat('#,##0').format(totalIncome)}',
                color: AppTheme.successColor,
              ),
              const SizedBox(width: 12),
              if (budgetAmount > 0)
                _StatChip(
                  label: 'Budget',
                  value: '$symbol${NumberFormat('#,##0').format(budgetAmount)}',
                  color: Colors.white60,
                ),
            ],
          ),
          if (budgetAmount > 0) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(budgetUsed * 100).toStringAsFixed(0)}% of budget used',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '$symbol${NumberFormat('#,##0').format(budgetAmount - totalSpent)} left',
                  style: TextStyle(
                    color: budgetAmount - totalSpent < 0
                        ? AppTheme.errorColor
                        : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budgetUsed,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(budgetColor),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final Map<ExpenseCategory, double> categorySpend;
  final String symbol;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _CategoryPieChart({
    required this.categorySpend,
    required this.symbol,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by Category', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 150,
                width: 150,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (response?.touchedSection != null) {
                          onTouch(
                            response!.touchedSection!.touchedSectionIndex,
                          );
                        } else {
                          onTouch(-1);
                        }
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      for (int i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].value,
                          color:
                              AppTheme.categoryColors[entries[i].key.index %
                                  AppTheme.categoryColors.length],
                          radius: touchedIndex == i ? 60 : 50,
                          title: touchedIndex == i
                              ? '${(entries[i].value / total * 100).toStringAsFixed(0)}%'
                              : '',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (int i = 0; i < entries.length.clamp(0, 5); i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.categoryColors[entries[i]
                                            .key
                                            .index %
                                        AppTheme.categoryColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entries[i].key.label,
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$symbol${NumberFormat('#,##0').format(entries[i].value)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String symbol;
  const _EmptyState({required this.symbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          Text('💸', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('No expenses yet', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first expense\nor import from bank SMS',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily Budget Alert Card ───────────────────────────────────────────────────
class _DailyBudgetAlert extends StatelessWidget {
  final double todaySpent;
  final double dailyLimit;
  final String symbol;

  const _DailyBudgetAlert({
    required this.todaySpent,
    required this.dailyLimit,
    required this.symbol,
  });

  Color _statusColor(double ratio) {
    if (ratio >= 1.0) return AppTheme.errorColor;
    if (ratio >= 0.75) return AppTheme.warningColor;
    return AppTheme.successColor;
  }

  String _statusLabel(double ratio) {
    if (ratio >= 1.0) return 'OVER LIMIT';
    if (ratio >= 0.75) return 'NEAR LIMIT';
    return 'ON TRACK';
  }

  IconData _statusIcon(double ratio) {
    if (ratio >= 1.0) return Icons.warning_rounded;
    if (ratio >= 0.75) return Icons.info_outline_rounded;
    return Icons.check_circle_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = dailyLimit > 0
        ? (todaySpent / dailyLimit).clamp(0.0, 2.0)
        : 0.0;
    final color = _statusColor(ratio);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(ratio), color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Spending",
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(ratio),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Overall today spend vs daily limit ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$symbol${NumberFormat('#,##0.00').format(todaySpent)}',
                        style: TextStyle(
                          color: color,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'of $symbol${NumberFormat('#,##0.00').format(dailyLimit)} daily limit',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      todaySpent > dailyLimit
                          ? '$symbol${NumberFormat('#,##0').format(todaySpent - dailyLimit)} over'
                          : '$symbol${NumberFormat('#,##0').format(dailyLimit - todaySpent)} left',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${(ratio * 100).toStringAsFixed(0)}% used',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
