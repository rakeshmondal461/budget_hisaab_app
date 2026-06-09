import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task_model.dart';
import '../../../core/theme/app_theme.dart';

class AddTaskScreen extends StatefulWidget {
  final String? editTaskId;
  const AddTaskScreen({super.key, this.editTaskId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  TaskPriority _priority = TaskPriority.medium;
  DateTime? _deadline;
  TaskModel? _editTask;

  @override
  void initState() {
    super.initState();
    if (widget.editTaskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _editTask = context.read<TaskProvider>().findById(widget.editTaskId!);
        if (_editTask != null) {
          _titleCtrl.text = _editTask!.title;
          _descCtrl.text = _editTask!.description;
          _tagsCtrl.text = _editTask!.tags.join(', ');
          setState(() {
            _priority = _editTask!.priority;
            _deadline = _editTask!.deadline;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.editTaskId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Title ──────────────────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                hintText: 'Task title...',
                hintStyle: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
                border: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              maxLines: 2,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Title is required' : null,
            ),
            const Divider(),
            const SizedBox(height: 12),

            // ── Description ────────────────────────────────────────────────
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                hintText: 'Description (optional)...',
                border: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 20),

            // ── Priority ───────────────────────────────────────────────────
            Text('Priority', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: TaskPriority.values.map((p) {
                final isSelected = _priority == p;
                final color = Color(p.colorValue);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.2)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? color : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              p.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isSelected ? color : null,
                                fontWeight: isSelected ? FontWeight.w700 : null,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Deadline ───────────────────────────────────────────────────
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              tileColor: theme.cardColor,
              leading: Icon(
                Icons.event,
                color: _deadline != null && DateTime.now().isAfter(_deadline!)
                    ? AppTheme.errorColor
                    : theme.colorScheme.primary,
              ),
              title: const Text('Deadline'),
              subtitle: Text(
                _deadline == null
                    ? 'No deadline set'
                    : DateFormat('EEE, MMM d yyyy').format(_deadline!),
                style: theme.textTheme.bodySmall,
              ),
              trailing: _deadline != null
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _deadline = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _deadline ?? DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),
            const SizedBox(height: 12),

            // ── Tags ───────────────────────────────────────────────────────
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
                hintText: 'work, personal, urgent',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 32),

            // ── Save Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                child: Text(
                  isEditing ? 'Update Task' : 'Create Task',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<TaskProvider>();
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (_editTask != null) {
      provider.updateTask(_editTask!.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        priority: _priority,
        deadline: _deadline,
        tags: tags,
      ));
    } else {
      provider.addTask(TaskModel(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        priority: _priority,
        deadline: _deadline,
        tags: tags,
      ));
    }
    context.pop();
  }
}
