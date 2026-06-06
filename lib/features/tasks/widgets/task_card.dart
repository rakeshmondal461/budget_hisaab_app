import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import '../../../core/theme/app_theme.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.read<TaskProvider>();
    final priorityColor = Color(task.priority.colorValue);

    return Dismissible(
      key: Key(task.id),
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
                title: const Text('Delete Task'),
                content: const Text('Are you sure?'),
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
      onDismissed: (_) => provider.deleteTask(task.id),
      child: GestureDetector(
        onTap: () => context.push('/tasks/${task.id}'),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: task.isOverdue
                ? Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4))
                : Border.all(color: priorityColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Priority dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: priorityColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: task.status == TaskStatus.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Focus button
                  if (task.status != TaskStatus.done)
                    GestureDetector(
                      onTap: () => context.push('/tasks/${task.id}/focus'),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.play_arrow,
                            size: 18, color: theme.colorScheme.primary),
                      ),
                    ),
                ],
              ),

              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  task.description,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 10),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progressPercent,
                  minHeight: 4,
                  backgroundColor: priorityColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(priorityColor),
                ),
              ),

              const SizedBox(height: 10),

              // Footer
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    '${(task.focusedMinutes / 60).toStringAsFixed(1)}/${task.estimatedHours.toStringAsFixed(1)}h',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (task.deadline != null) ...[
                    Icon(
                      Icons.event,
                      size: 14,
                      color: task.isOverdue
                          ? AppTheme.errorColor
                          : theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d').format(task.deadline!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: task.isOverdue ? AppTheme.errorColor : null,
                        fontWeight: task.isOverdue ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Tags
                  ...task.tags.take(2).map((tag) => Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
