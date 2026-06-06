import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/google_drive_service.dart';
import '../../../core/export/export_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../features/expenses/providers/expense_provider.dart';
import '../../../features/tasks/providers/task_provider.dart';

import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();
    final driveService = context.watch<GoogleDriveService>();
    final isDark = themeProvider.isDark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          _SettingsTile(
            icon: isDark ? Icons.dark_mode : Icons.light_mode,
            iconColor: AppTheme.accentDark,
            title: 'Theme',
            subtitle: isDark ? 'Dark Mode' : 'Light Mode',
            trailing: Switch(
              value: isDark,
              onChanged: (_) => themeProvider.toggle(),
              activeThumbColor: AppTheme.primaryDark,
            ),
          ),

          // ── Preferences ───────────────────────────────────────────────────
          _SectionHeader('Preferences'),
          _SettingsTile(
            icon: Icons.currency_exchange,
            iconColor: AppTheme.successColor,
            title: 'Currency',
            subtitle: '${settings.currency} (${settings.currencyCode})',
            onTap: () => _showCurrencyPicker(context, settings),
          ),
          _SettingsTile(
            icon: Icons.notifications_active_outlined,
            iconColor: AppTheme.warningColor,
            title: 'Daily Task Reminders',
            subtitle: 'Remind me of pending tasks at 7 PM',
            trailing: Switch(
              value: settings.notificationsEnabled,
              onChanged: (val) async {
                await settings.setNotificationsEnabled(val);
                if (context.mounted) {
                  final tasks = context.read<TaskProvider>().tasks;
                  await NotificationService().updateTaskReminder(tasks);
                }
              },
              activeThumbColor: AppTheme.primaryDark,
            ),
          ),

          // ── Google Drive ──────────────────────────────────────────────────
          _SectionHeader('Cloud Sync'),
          if (driveService.isSignedIn) ...[
            _SettingsTile(
              icon: Icons.account_circle,
              iconColor: AppTheme.primaryDark,
              title: 'Google Account',
              subtitle: driveService.userEmail ?? 'Signed in',
              trailing: TextButton(
                onPressed: () => driveService.signOut(),
                child: const Text('Sign Out',
                    style: TextStyle(color: AppTheme.errorColor)),
              ),
            ),
            _SettingsTile(
              icon: Icons.sync,
              iconColor: AppTheme.successColor,
              title: 'Auto Sync to Drive',
              subtitle: 'Sync data automatically on app open',
              trailing: Switch(
                value: settings.driveAutoSync,
                onChanged: settings.setDriveAutoSync,
                activeThumbColor: AppTheme.primaryDark,
              ),
            ),
          ] else
            _SettingsTile(
              icon: Icons.cloud_upload_outlined,
              iconColor: AppTheme.primaryDark,
              title: 'Connect Google Drive',
              subtitle: 'Backup & sync your data to Drive',
              onTap: () async {
                final success = await driveService.signIn();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Connected to Google Drive'
                          : 'Sign in failed'),
                      backgroundColor:
                          success ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  );
                }
              },
            ),

          // ── Export ────────────────────────────────────────────────────────
          _SectionHeader('Data Export'),

          // Expenses
          _SettingsTile(
            icon: Icons.table_chart_outlined,
            iconColor: AppTheme.accentDark,
            title: 'Export Expenses to Excel',
            subtitle: 'Share as .xlsx file',
            onTap: () => _exportExpenses(context, format: 'excel'),
          ),
          _SettingsTile(
            icon: Icons.receipt_long_outlined,
            iconColor: AppTheme.warningColor,
            title: 'Export Expenses to CSV',
            subtitle: 'Spreadsheet-compatible .csv file',
            onTap: () => _exportExpenses(context, format: 'csv'),
          ),
          _SettingsTile(
            icon: Icons.code,
            iconColor: AppTheme.primaryDark,
            title: 'Export Expenses to JSON',
            subtitle: 'Raw data export',
            onTap: () => _exportExpenses(context, format: 'json'),
          ),

          // Tasks
          _SettingsTile(
            icon: Icons.checklist_outlined,
            iconColor: AppTheme.successColor,
            title: 'Export Tasks to CSV',
            subtitle: 'Tasks, status & focus hours',
            onTap: () => _exportTasks(context, format: 'csv'),
          ),
          _SettingsTile(
            icon: Icons.task_outlined,
            iconColor: AppTheme.primaryDark,
            title: 'Export Tasks to Excel',
            subtitle: 'Tasks as .xlsx file',
            onTap: () => _exportTasks(context, format: 'excel'),
          ),

          // Full Data
          _SettingsTile(
            icon: Icons.download_outlined,
            iconColor: AppTheme.successColor,
            title: 'Export All Data (JSON)',
            subtitle: 'Complete backup — expenses, tasks, budgets',
            onTap: () => _exportAll(context, format: 'json'),
          ),
          _SettingsTile(
            icon: Icons.download_for_offline_outlined,
            iconColor: AppTheme.warningColor,
            title: 'Export All Data (CSV)',
            subtitle: 'Complete backup as .csv',
            onTap: () => _exportAll(context, format: 'csv'),
          ),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline,
            iconColor: Colors.grey,
            title: 'HiSaab',
            subtitle: 'v1.0.0 · Your personal productivity app',
          ),
          _SettingsTile(
            icon: Icons.folder_outlined,
            iconColor: Colors.grey,
            title: 'Data Storage Location',
            subtitle: 'Internal Storage / DigitalCompanion/',
            onTap: () async {
              final local = context.read<LocalStorageService>();
              final path = await local.appDirPath;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(path)),
                );
              }
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text('Select Currency',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...SettingsProvider.currencies.map((c) => ListTile(
                leading:
                    Text(c['symbol']!, style: const TextStyle(fontSize: 24)),
                title: Text(c['name']!),
                subtitle: Text(c['code']!),
                trailing: settings.currencyCode == c['code']
                    ? const Icon(Icons.check, color: AppTheme.primaryDark)
                    : null,
                onTap: () {
                  settings.setCurrency(c['symbol']!, c['code']!);
                  Navigator.pop(context);
                },
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _exportExpenses(BuildContext context,
      {required String format}) async {
    final expenseProvider = context.read<ExpenseProvider>();
    final local = context.read<LocalStorageService>();
    final exportService = ExportService(local);

    try {
      switch (format) {
        case 'excel':
          await exportService
              .exportExpensesToExcel(expenseProvider.toJsonList());
          break;
        case 'csv':
          await exportService.exportExpensesToCsv(expenseProvider.toJsonList());
          break;
        default:
          await exportService
              .exportExpensesToJson(expenseProvider.toJsonList());
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _exportTasks(BuildContext context,
      {required String format}) async {
    final taskProvider = context.read<TaskProvider>();
    final local = context.read<LocalStorageService>();
    final exportService = ExportService(local);

    try {
      switch (format) {
        case 'excel':
          await exportService.exportTasksToExcel(taskProvider.toJsonList());
          break;
        case 'csv':
          await exportService.exportTasksToCsv(taskProvider.toJsonList());
          break;
        default:
          await exportService.exportTasksToJson(taskProvider.toJsonList());
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _exportAll(BuildContext context,
      {required String format}) async {
    final expenseProvider = context.read<ExpenseProvider>();
    final taskProvider = context.read<TaskProvider>();
    final local = context.read<LocalStorageService>();
    final exportService = ExportService(local);

    try {
      final expenses = expenseProvider.toJsonList();
      final tasks = taskProvider.toJsonList();
      final sessions = taskProvider.sessionsToJsonList();
      final budgets = expenseProvider.budgetsToJson();

      if (format == 'csv') {
        await exportService.exportAllToCsv(
          expenses: expenses,
          tasks: tasks,
          focusSessions: sessions,
          budgets: budgets,
        );
      } else {
        await exportService.exportAllToJson(
          expenses: expenses,
          tasks: tasks,
          focusSessions: sessions,
          budgets: budgets,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right,
                  color: theme.textTheme.bodySmall?.color)
              : null),
    );
  }
}
