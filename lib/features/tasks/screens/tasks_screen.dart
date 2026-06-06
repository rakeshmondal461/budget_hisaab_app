import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/task_card.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskPriority? _filterPriority;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final theme = Theme.of(context);

    final overdue = provider.overdueTasks;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Tasks & Goals'),
        actions: [
          // Filter button
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_filterPriority != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.secondaryDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterMenu,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              child: _TabLabel(
                label: 'To Do',
                count: provider.todoTasks.length,
                color: theme.colorScheme.primary,
              ),
            ),
            Tab(
              child: _TabLabel(
                label: 'In Progress',
                count: provider.inProgressTasks.length,
                color: AppTheme.warningColor,
              ),
            ),
            Tab(
              child: _TabLabel(
                label: 'Done',
                count: provider.doneTasks.length,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/add'),
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
      body: Column(
        children: [
          // ── Overdue Warning Banner ─────────────────────────────────────
          if (overdue.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.errorColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: AppTheme.errorColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${overdue.length} overdue task${overdue.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _tabController.animateTo(0),
                    style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),

          // ── Tab Views ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TaskList(
                  tasks: _applyFilter(provider.todoTasks),
                  emptyMessage: 'No pending tasks 🎉',
                  emptySubtitle: 'Tap + to create a new task',
                ),
                _TaskList(
                  tasks: _applyFilter(provider.inProgressTasks),
                  emptyMessage: 'Nothing in progress',
                  emptySubtitle: 'Start working on a task to see it here',
                ),
                _TaskList(
                  tasks: _applyFilter(provider.doneTasks),
                  emptyMessage: 'No completed tasks yet',
                  emptySubtitle: 'Complete tasks to see them here',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TaskModel> _applyFilter(List<TaskModel> tasks) {
    if (_filterPriority == null) return tasks;
    return tasks.where((t) => t.priority == _filterPriority).toList();
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by Priority',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterPriority == null,
                  onSelected: (_) {
                    setState(() => _filterPriority = null);
                    Navigator.pop(context);
                  },
                ),
                ...TaskPriority.values.map((p) => FilterChip(
                      label: Text(p.label),
                      selected: _filterPriority == p,
                      selectedColor: Color(p.colorValue).withValues(alpha: 0.2),
                      onSelected: (_) {
                        setState(() => _filterPriority = p);
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _TabLabel(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<TaskModel> tasks;
  final String emptyMessage;
  final String emptySubtitle;

  const _TaskList({
    required this.tasks,
    required this.emptyMessage,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(emptyMessage,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              emptySubtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: tasks.length,
      itemBuilder: (_, i) => TaskCard(task: tasks[i]),
    );
  }
}
