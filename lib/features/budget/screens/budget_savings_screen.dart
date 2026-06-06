import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../expenses/models/expense_model.dart';
import '../../expenses/models/budget_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../features/settings/providers/settings_provider.dart';

class BudgetSavingsScreen extends StatefulWidget {
  const BudgetSavingsScreen({super.key});
  @override
  State<BudgetSavingsScreen> createState() => _BudgetSavingsScreenState();
}

class _BudgetSavingsScreenState extends State<BudgetSavingsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  // Savings Plan
  final _incomeCtrl = TextEditingController();
  final _savingsAmountCtrl = TextEditingController();
  double _savingsPercent = 0.0;
  bool _syncing = false;

  // Manual Budget
  final _totalCtrl = TextEditingController();
  final _catControllers = <ExpenseCategory, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    for (final cat in ExpenseCategory.values) {
      _catControllers[cat] = TextEditingController();
    }
    _savingsAmountCtrl.addListener(_syncPercentFromAmount);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBudget());
  }

  void _loadBudget() {
    final provider = context.read<ExpenseProvider>();
    final now = DateTime.now();
    final b = provider.budgetFor(now.year, now.month);
    if (b.totalBudget > 0 || b.isAutoMode || b.monthlyIncome > 0) {
      // Show overview first when a budget is already saved
      _tabController.index = 2;
    }
    if (b.isAutoMode || b.monthlyIncome > 0) {
      _incomeCtrl.text =
          b.monthlyIncome > 0 ? b.monthlyIncome.toStringAsFixed(0) : '';
      _syncing = true;
      _savingsAmountCtrl.text =
          b.savingsTarget > 0 ? b.savingsTarget.toStringAsFixed(0) : '';
      _syncing = false;
      if (b.monthlyIncome > 0) {
        _savingsPercent =
            (b.savingsTarget / b.monthlyIncome * 100).clamp(0.0, 80.0);
      }
    } else if (b.totalBudget > 0) {
      _totalCtrl.text =
          b.totalBudget > 0 ? b.totalBudget.toStringAsFixed(0) : '';
      for (final cat in ExpenseCategory.values) {
        final v = b.categoryBudgets[cat] ?? 0;
        _catControllers[cat]!.text = v > 0 ? v.toStringAsFixed(0) : '';
      }
    }
    setState(() {});
  }

  void _syncPercentFromAmount() {
    if (_syncing) return;
    final income = double.tryParse(_incomeCtrl.text) ?? 0;
    final amount = double.tryParse(_savingsAmountCtrl.text) ?? 0;
    if (income > 0) {
      setState(
          () => _savingsPercent = (amount / income * 100).clamp(0.0, 80.0));
    }
  }

  void _onSliderChanged(double v) {
    final income = double.tryParse(_incomeCtrl.text) ?? 0;
    setState(() => _savingsPercent = v);
    _syncing = true;
    _savingsAmountCtrl.text = (income * v / 100).toStringAsFixed(0);
    _syncing = false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _incomeCtrl.dispose();
    _savingsAmountCtrl.dispose();
    _totalCtrl.dispose();
    for (final c in _catControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _daysInMonth(DateTime dt) => DateTime(dt.year, dt.month + 1, 0).day;

  void _applyAutoToManual(
      Map<ExpenseCategory, double> preview, double spendable) {
    _totalCtrl.text = spendable.toStringAsFixed(0);
    for (final cat in ExpenseCategory.values) {
      final v = preview[cat] ?? 0;
      _catControllers[cat]!.text = v > 0 ? v.toStringAsFixed(0) : '';
    }
    setState(() {});
    _tabController.animateTo(1);
    _snack('Auto limits applied to Manual Budget ✏️ — adjust as needed!');
  }

  void _saveAuto(ExpenseProvider p) {
    final income = double.tryParse(_incomeCtrl.text) ?? 0;
    final target = double.tryParse(_savingsAmountCtrl.text) ?? 0;
    if (income <= 0) {
      _snack('Enter your monthly income', error: true);
      return;
    }
    final now = DateTime.now();
    p.saveBudget(BudgetModel.fromSavingsPlan(
        income: income,
        savingsTarget: target,
        month: now.month,
        year: now.year));
    _snack('Savings plan saved! 🎯');
    _tabController.animateTo(2);
  }

  void _saveManual(ExpenseProvider p) {
    final total = double.tryParse(_totalCtrl.text) ?? 0;
    final cats = <ExpenseCategory, double>{};
    for (final cat in ExpenseCategory.values) {
      final v = double.tryParse(_catControllers[cat]!.text) ?? 0;
      if (v > 0) cats[cat] = v;
    }
    final now = DateTime.now();
    p.saveBudget(BudgetModel(
        categoryBudgets: cats,
        totalBudget: total,
        isAutoMode: false,
        month: now.month,
        year: now.year));
    _snack('Budget saved! ✅');
    _tabController.animateTo(2);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.errorColor : AppTheme.successColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final symbol = context.watch<SettingsProvider>().currency;
    final isDark = context.watch<ThemeProvider>().isDark;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final actualSavings = provider.actualSavingsForMonth(now.year, now.month);
    final budget = provider.budgetFor(now.year, now.month);
    final progress = provider.savingsProgressForMonth(now.year, now.month);
    final catSpend = provider.spendByCategory(now.year, now.month);
    final totalSpent = provider.totalSpentForMonth(now.year, now.month);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Budget & Savings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          // Hide Save on the overview tab
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) => _tabController.index == 2
                ? const SizedBox.shrink()
                : TextButton.icon(
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryDark,
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => _tabController.index == 0
                        ? _saveAuto(provider)
                        : _saveManual(provider),
                  ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryDark,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryDark,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          tabs: const [
            Tab(text: '🎯  Savings Plan'),
            Tab(text: '✏️  Manual Budget'),
            Tab(text: '📊  Overview'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAutoTab(context, provider, symbol, isDark, theme, actualSavings,
              budget, progress, now),
          _buildManualTab(
              context, provider, symbol, theme, catSpend, totalSpent),
          _buildOverviewTab(
              context, budget, provider, symbol, theme, now, catSpend),
        ],
      ),
    );
  }

  // ── Tab 1: Savings Plan ──────────────────────────────────────────────────
  Widget _buildAutoTab(
    BuildContext ctx,
    ExpenseProvider provider,
    String symbol,
    bool isDark,
    ThemeData theme,
    double actualSavings,
    BudgetModel budget,
    double progress,
    DateTime now,
  ) {
    final income = double.tryParse(_incomeCtrl.text) ?? 0;
    final target = double.tryParse(_savingsAmountCtrl.text) ?? 0;
    final spendable = (income - target).clamp(0.0, double.infinity);
    final daysInMonth = _daysInMonth(now);
    final preview = income > 0
        ? BudgetModel.fromSavingsPlan(
                income: income,
                savingsTarget: target,
                month: now.month,
                year: now.year)
            .categoryBudgets
        : <ExpenseCategory, double>{};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Progress Ring Card
        _SavingsRingCard(
          actualSavings: actualSavings,
          savingsTarget: budget.savingsTarget,
          progress: progress,
          symbol: symbol,
          isDark: isDark,
          month: DateFormat('MMMM yyyy').format(now),
        ),
        const SizedBox(height: 16),

        // Income Input
        _SectionLabel('Monthly Income', Icons.account_balance_outlined,
            AppTheme.successColor),
        const SizedBox(height: 6),
        _buildAmountInput(_incomeCtrl, symbol, 'e.g. 50000',
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),

        // Savings Target
        _SectionLabel(
            'Savings Target', Icons.savings_outlined, AppTheme.primaryDark),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildAmountInput(_savingsAmountCtrl, symbol, '0',
                        onChanged: (_) {}),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_savingsPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: AppTheme.primaryDark,
                  thumbColor: AppTheme.primaryDark,
                  inactiveTrackColor:
                      AppTheme.primaryDark.withValues(alpha: 0.2),
                  overlayColor: AppTheme.primaryDark.withValues(alpha: 0.1),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: _savingsPercent,
                  min: 0,
                  max: 80,
                  divisions: 80,
                  onChanged: income > 0 ? _onSliderChanged : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0%', style: theme.textTheme.bodySmall),
                  Text('Max 80%', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Spendable Summary Card
        if (income > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryDark,
                  AppTheme.primaryDark.withValues(alpha: 0.75)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined,
                    color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Spendable Budget',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '$symbol${NumberFormat('#,##0').format(spendable)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$symbol${NumberFormat('#,##0.00').format(spendable / daysInMonth)} / day',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Income',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    Text('$symbol${NumberFormat('#,##0').format(income)}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Savings',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                    Text('$symbol${NumberFormat('#,##0').format(target)}',
                        style: const TextStyle(
                            color: AppTheme.accentDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // ── Budget Preview Section ──────────────────────────────────────────
        if (preview.isNotEmpty) ...[
          _BudgetPreviewCard(
            preview: preview,
            daysInMonth: daysInMonth,
            symbol: symbol,
            theme: theme,
            month: DateFormat('MMMM').format(now),
          ),
          const SizedBox(height: 16),

          // Apply to Manual Budget button
          OutlinedButton.icon(
            onPressed: () => _applyAutoToManual(preview, spendable),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Apply to Manual Budget & Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryDark,
              side: const BorderSide(color: AppTheme.primaryDark, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Auto Category Breakdown detail tiles
          Row(
            children: [
              Text('Category Breakdown', style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Priority Order',
                    style: TextStyle(
                        color: AppTheme.primaryDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final cat in ExpenseCategory.values)
            _AutoCategoryTile(
              cat: cat,
              allocated: preview[cat] ?? 0,
              daysInMonth: daysInMonth,
              symbol: symbol,
              theme: theme,
            ),
        ],
      ],
    );
  }

  // ── Tab 2: Manual Budget ─────────────────────────────────────────────────
  Widget _buildManualTab(
    BuildContext ctx,
    ExpenseProvider provider,
    String symbol,
    ThemeData theme,
    Map<ExpenseCategory, double> catSpend,
    double totalSpent,
  ) {
    final total = double.tryParse(_totalCtrl.text) ?? 0;
    final allocated = _catControllers.values
        .fold(0.0, (s, c) => s + (double.tryParse(c.text) ?? 0));
    final remaining = total - allocated;
    final overBudget = total > 0 && allocated > total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Total Budget
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryDark,
                AppTheme.primaryDark.withValues(alpha: 0.7)
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Monthly Budget',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _totalCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  prefixText: '$symbol ',
                  prefixStyle:
                      const TextStyle(color: Colors.white70, fontSize: 22),
                  hintText: '0',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                ),
                onChanged: (_) => setState(() {}),
              ),
              Text(
                'Spent $symbol${NumberFormat('#,##0.00').format(totalSpent)} this month',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Live Allocation Summary ────────────────────────────────────────
        if (total > 0)
          _buildAllocationSummary(
              total, allocated, remaining, overBudget, symbol, theme),
        if (total > 0) const SizedBox(height: 16),

        Text('Category Limits', style: theme.textTheme.titleMedium),
        Text('Optional per-category spending caps',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 10),
        for (final cat in ExpenseCategory.values)
          _ManualCategoryTile(
            cat: cat,
            controller: _catControllers[cat]!,
            spent: catSpend[cat] ?? 0,
            symbol: symbol,
            theme: theme,
            onChanged: () => setState(() {}),
          ),
        const SizedBox(height: 20),

        // Over-budget warning
        if (overBudget)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppTheme.errorColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Category totals exceed your budget by $symbol${NumberFormat('#,##0').format(allocated - total)}. Reduce some limits to save.',
                    style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        // Save button — disabled when over budget
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: overBudget ? null : () => _saveManual(provider),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor:
                  AppTheme.errorColor.withValues(alpha: 0.15),
              disabledForegroundColor: AppTheme.errorColor,
            ),
            child: Text(
              overBudget ? 'Over Budget — Fix Limits First' : 'Save Budget',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Budget Overview (read-only) ───────────────────────────────────
  Widget _buildOverviewTab(
    BuildContext ctx,
    BudgetModel budget,
    ExpenseProvider provider,
    String symbol,
    ThemeData theme,
    DateTime now,
    Map<ExpenseCategory, double> catSpend,
  ) {
    final hasBudget =
        budget.totalBudget > 0 || budget.categoryBudgets.isNotEmpty;
    final daysInMonth = _daysInMonth(now);
    final totalSpent = provider.totalSpentForMonth(now.year, now.month);
    final allocated = budget.categoryBudgets.values.fold(0.0, (s, v) => s + v);
    final remaining = budget.totalBudget - totalSpent;
    final spendRatio = budget.totalBudget > 0
        ? (totalSpent / budget.totalBudget).clamp(0.0, 1.0)
        : 0.0;

    if (!hasBudget) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text('No Budget Saved Yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Set up a Savings Plan or Manual Budget\nand save it to see your overview here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.savings_outlined, size: 16),
                  label: const Text('Savings Plan'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Manual Budget'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── Header summary card ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryDark,
                AppTheme.primaryDark.withValues(alpha: 0.72)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(now),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          budget.isAutoMode
                              ? '🎯 Savings Plan Budget'
                              : '✏️ Manual Budget',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  // Edit button
                  GestureDetector(
                    onTap: () =>
                        _tabController.animateTo(budget.isAutoMode ? 0 : 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Edit',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Total / Spent / Remaining
              Row(
                children: [
                  _OverviewStatBox(
                      label: 'Budget',
                      value:
                          '$symbol${NumberFormat('#,##0').format(budget.totalBudget)}',
                      light: true),
                  const SizedBox(width: 10),
                  _OverviewStatBox(
                      label: 'Spent',
                      value:
                          '$symbol${NumberFormat('#,##0').format(totalSpent)}',
                      light: true),
                  const SizedBox(width: 10),
                  _OverviewStatBox(
                    label: remaining >= 0 ? 'Remaining' : 'Over by',
                    value:
                        '$symbol${NumberFormat('#,##0').format(remaining.abs())}',
                    light: true,
                    accent: remaining < 0,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Spend progress
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: spendRatio,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation(
                    spendRatio > 0.9
                        ? AppTheme.errorColor
                        : AppTheme.accentDark,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(spendRatio * 100).toStringAsFixed(1)}% of budget spent  •  $symbol${NumberFormat('#,##0.0').format(budget.totalBudget / daysInMonth)}/day limit',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              // Savings info
              if (budget.isAutoMode && budget.savingsTarget > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.savings_outlined,
                          color: AppTheme.accentDark, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Savings target: $symbol${NumberFormat('#,##0').format(budget.savingsTarget)} / month  (${(budget.savingsTarget / budget.monthlyIncome * 100).toStringAsFixed(0)}% of income)',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Allocation bar ──
        if (allocated > 0 && budget.totalBudget > 0) ...[
          _buildAllocationSummary(
            budget.totalBudget,
            allocated,
            budget.totalBudget - allocated,
            allocated > budget.totalBudget,
            symbol,
            theme,
          ),
          const SizedBox(height: 20),
        ],

        // ── Category breakdown table ──
        Row(
          children: [
            Text('Category Limits', style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Text('${DateFormat('MMMM').format(now)} · $daysInMonth days',
                style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 10),

        for (final cat in ExpenseCategory.values) ...[
          if ((budget.categoryBudgets[cat] ?? 0) > 0)
            _OverviewCategoryRow(
              cat: cat,
              monthly: budget.categoryBudgets[cat]!,
              daily: budget.categoryBudgets[cat]! / daysInMonth,
              spent: catSpend[cat] ?? 0,
              symbol: symbol,
              theme: theme,
            ),
        ],

        // If no category limits set
        if (budget.categoryBudgets.isEmpty ||
            budget.categoryBudgets.values.every((v) => v == 0))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No per-category limits were set.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildAmountInput(
    TextEditingController ctrl,
    String symbol,
    String hint, {
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixText: '$symbol ',
        hintText: hint,
      ),
    );
  }

  Widget _buildAllocationSummary(
    double total,
    double allocated,
    double remaining,
    bool overBudget,
    String symbol,
    ThemeData theme,
  ) {
    final ratio = (allocated / total).clamp(0.0, 1.0);
    final barColor = overBudget
        ? AppTheme.errorColor
        : ratio > 0.85
            ? AppTheme.warningColor
            : AppTheme.successColor;
    final unallocated = allocated == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overBudget
              ? AppTheme.errorColor.withValues(alpha: 0.5)
              : AppTheme.primaryDark.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Icon(
                overBudget
                    ? Icons.error_outline_rounded
                    : Icons.pie_chart_outline_rounded,
                size: 16,
                color: overBudget ? AppTheme.errorColor : AppTheme.primaryDark,
              ),
              const SizedBox(width: 6),
              Text(
                'Budget Allocation',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: overBudget ? AppTheme.errorColor : null,
                ),
              ),
              const Spacer(),
              if (overBudget)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('OVER BUDGET',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Three stat boxes
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'Budget',
                  value: '$symbol${NumberFormat('#,##0').format(total)}',
                  color: AppTheme.primaryDark,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  label: 'Allocated',
                  value: '$symbol${NumberFormat('#,##0').format(allocated)}',
                  color: barColor,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatBox(
                  label: overBudget ? 'Over by' : 'Remaining',
                  value:
                      '$symbol${NumberFormat('#,##0').format(remaining.abs())}',
                  color:
                      overBudget ? AppTheme.errorColor : AppTheme.successColor,
                  theme: theme,
                  highlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: unallocated ? 0 : ratio,
              minHeight: 10,
              backgroundColor: barColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unallocated
                    ? 'No categories set yet'
                    : '${(ratio * 100).toStringAsFixed(1)}% allocated',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!unallocated && !overBudget)
                Text(
                  '${((1 - ratio) * 100).toStringAsFixed(1)}% free',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Savings Ring Card ─────────────────────────────────────────────────────────
class _SavingsRingCard extends StatelessWidget {
  final double actualSavings;
  final double savingsTarget;
  final double progress;
  final String symbol;
  final bool isDark;
  final String month;

  const _SavingsRingCard({
    required this.actualSavings,
    required this.savingsTarget,
    required this.progress,
    required this.symbol,
    required this.isDark,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = progress >= 1.0
        ? AppTheme.successColor
        : progress >= 0.5
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    final hasTarget = savingsTarget > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _RingPainter(
                  progress: hasTarget ? progress : 0, color: color),
              child: Center(
                child: Text(
                  hasTarget ? '${(progress * 100).toStringAsFixed(0)}%' : '—',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: hasTarget ? 14 : 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(month, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text('Savings This Month', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '$symbol${NumberFormat('#,##0').format(actualSavings.clamp(0, double.infinity))}',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasTarget)
                  Text(
                    'of $symbol${NumberFormat('#,##0').format(savingsTarget)} target',
                    style: theme.textTheme.bodySmall,
                  ),
                if (!hasTarget)
                  Text('Set a savings target above',
                      style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 8;
    final stroke = 8.0;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _SectionLabel(this.text, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

// ── Budget Preview Card ───────────────────────────────────────────────────────
class _BudgetPreviewCard extends StatelessWidget {
  final Map<ExpenseCategory, double> preview;
  final int daysInMonth;
  final String symbol;
  final ThemeData theme;
  final String month;

  const _BudgetPreviewCard({
    required this.preview,
    required this.daysInMonth,
    required this.symbol,
    required this.theme,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppTheme.primaryDark.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryDark.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview_rounded,
                    size: 18, color: AppTheme.primaryDark),
                const SizedBox(width: 8),
                Text('Budget Preview — $month',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: AppTheme.primaryDark)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$daysInMonth days',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          // Column headers
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                const Expanded(
                    child: Text('Category',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 90,
                    child: Text('Monthly',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 80,
                    child: Text('Daily',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // Rows
          for (final cat in ExpenseCategory.values) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          Text(cat.label, style: theme.textTheme.bodyMedium)),
                  SizedBox(
                    width: 90,
                    child: Text(
                      '$symbol${NumberFormat('#,##0').format(preview[cat] ?? 0)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.categoryColors[
                              ExpenseCategory.values.indexOf(cat) %
                                  AppTheme.categoryColors.length]),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      '$symbol${NumberFormat('#,##0.0').format((preview[cat] ?? 0) / daysInMonth)}',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            if (cat != ExpenseCategory.values.last)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Auto Category Tile ────────────────────────────────────────────────────────
class _AutoCategoryTile extends StatelessWidget {
  final ExpenseCategory cat;
  final double allocated;
  final int daysInMonth;
  final String symbol;
  final ThemeData theme;

  const _AutoCategoryTile({
    required this.cat,
    required this.allocated,
    required this.daysInMonth,
    required this.symbol,
    required this.theme,
  });

  static const _priorityBadge = {
    ExpenseCategory.food: '⭐ Priority',
    ExpenseCategory.transport: '⭐ Priority',
    ExpenseCategory.health: '⭐ Priority',
  };

  @override
  Widget build(BuildContext context) {
    final idx = ExpenseCategory.values.indexOf(cat);
    final catColor =
        AppTheme.categoryColors[idx % AppTheme.categoryColors.length];
    final badge = _priorityBadge[cat];
    final daily = daysInMonth > 0 ? allocated / daysInMonth : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: catColor, width: 3)),
      ),
      child: Row(
        children: [
          Text(cat.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.label, style: theme.textTheme.titleMedium),
                if (badge != null)
                  Text(badge,
                      style: TextStyle(
                          color: catColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$symbol${NumberFormat('#,##0').format(allocated)}',
                style: TextStyle(
                    color: catColor, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              Text(
                '$symbol${NumberFormat('#,##0.0').format(daily)}/day',
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                '${(BudgetModel.priorityWeights[cat]! * 100).toStringAsFixed(0)}% of spendable',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Manual Category Tile ──────────────────────────────────────────────────────
class _ManualCategoryTile extends StatelessWidget {
  final ExpenseCategory cat;
  final TextEditingController controller;
  final double spent;
  final String symbol;
  final ThemeData theme;
  final VoidCallback onChanged;

  const _ManualCategoryTile({
    required this.cat,
    required this.controller,
    required this.spent,
    required this.symbol,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final idx = ExpenseCategory.values.indexOf(cat);
    final catColor =
        AppTheme.categoryColors[idx % AppTheme.categoryColors.length];
    final limit = double.tryParse(controller.text) ?? 0;
    final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final barColor = ratio > 0.9
        ? AppTheme.errorColor
        : ratio > 0.7
            ? AppTheme.warningColor
            : AppTheme.successColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: catColor, width: 3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.label, style: theme.textTheme.titleMedium),
                    if (spent > 0)
                      Text(
                          'Spent: $symbol${NumberFormat('#,##0').format(spent)}',
                          style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    prefixText: symbol,
                    hintText: 'No limit',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: catColor.withValues(alpha: 0.4)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: catColor, width: 1.5),
                    ),
                    filled: false,
                  ),
                ),
              ),
            ],
          ),
          if (limit > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: barColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(barColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(ratio * 100).toStringAsFixed(0)}% used',
                    style: theme.textTheme.bodySmall),
                Text(
                  '$symbol${NumberFormat('#,##0').format((limit - spent).clamp(0, limit))} left',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stat Box ──────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ThemeData theme;
  final bool highlighted;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? color.withValues(alpha: 0.1)
            : color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: highlighted
            ? Border.all(color: color.withValues(alpha: 0.35), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Overview Stat Box (white-on-dark chip) ────────────────────────────────────
class _OverviewStatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool light;
  final bool accent;

  const _OverviewStatBox({
    required this.label,
    required this.value,
    this.light = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accent
              ? AppTheme.errorColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: accent ? AppTheme.errorColor : Colors.white54,
                  fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                  color: accent ? AppTheme.errorColor : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overview Category Row (read-only with spend progress) ─────────────────────
class _OverviewCategoryRow extends StatelessWidget {
  final ExpenseCategory cat;
  final double monthly;
  final double daily;
  final double spent;
  final String symbol;
  final ThemeData theme;

  const _OverviewCategoryRow({
    required this.cat,
    required this.monthly,
    required this.daily,
    required this.spent,
    required this.symbol,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final idx = ExpenseCategory.values.indexOf(cat);
    final catColor =
        AppTheme.categoryColors[idx % AppTheme.categoryColors.length];
    final ratio = monthly > 0 ? (spent / monthly).clamp(0.0, 1.0) : 0.0;
    final barColor = ratio > 0.9
        ? AppTheme.errorColor
        : ratio > 0.7
            ? AppTheme.warningColor
            : AppTheme.successColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: catColor, width: 3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.label, style: theme.textTheme.titleSmall),
                    Text(
                      'Spent: $symbol${NumberFormat('#,##0').format(spent)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$symbol${NumberFormat('#,##0').format(monthly)}/mo',
                    style: TextStyle(
                        color: catColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                  Text(
                    '$symbol${NumberFormat('#,##0.0').format(daily)}/day',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: barColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(ratio * 100).toStringAsFixed(0)}% used',
                  style: theme.textTheme.bodySmall),
              Text(
                (monthly - spent) >= 0
                    ? '$symbol${NumberFormat('#,##0').format(monthly - spent)} left'
                    : '$symbol${NumberFormat('#,##0').format((spent - monthly).abs())} over',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: barColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
