import 'package:go_router/go_router.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/expenses/screens/add_expense_screen.dart';
import '../../features/expenses/models/expense_model.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/tasks/screens/add_task_screen.dart';
import '../../features/tasks/screens/focus_timer_screen.dart';
import '../../features/tasks/screens/task_detail_screen.dart';
import '../../features/budget/screens/budget_savings_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../widgets/main_scaffold.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/expenses',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/expenses',
          builder: (context, state) => const ExpensesScreen(),
        ),
        GoRoute(
          path: '/budget',
          builder: (context, state) => const BudgetSavingsScreen(),
        ),
        GoRoute(
          path: '/tasks',
          builder: (context, state) => const TasksScreen(),
        ),
      ],
    ),
    // Expenses
    GoRoute(
      path: '/expenses/add',
      builder: (context, state) {
        final expense = state.extra as ExpenseModel?;
        return AddExpenseScreen(editExpense: expense);
      },
    ),
    // Tasks
    GoRoute(
      path: '/tasks/add',
      builder: (context, state) {
        final taskId = state.uri.queryParameters['id'];
        return AddTaskScreen(editTaskId: taskId);
      },
    ),
    GoRoute(
      path: '/tasks/:id',
      builder: (context, state) =>
          TaskDetailScreen(taskId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/tasks/:id/focus',
      builder: (context, state) =>
          FocusTimerScreen(taskId: state.pathParameters['id']!),
    ),
    // Settings
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
