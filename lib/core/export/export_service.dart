import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../storage/local_storage_service.dart';

class ExportService {
  // _local kept for API compatibility; all exports now use the temp directory
  // ignore: unused_field
  final LocalStorageService? _local;

  ExportService([this._local]);

  // ── Helpers ──────────────────────────────────────────────────────────────────
  /// Returns a writable temp file. No storage permission needed on any Android.
  Future<File> _writeExportFile(String fileName, String content) async {
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/$fileName');
    await file.writeAsString(content);
    return file;
  }

  Future<File> _writeExportBytes(String fileName, List<int> bytes) async {
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }

  String get _ts =>
      DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
  String get _tsShort => DateTime.now().toIso8601String().substring(0, 10);

  // ═══════════════════════════════════════════════════════════════════════════
  // ── JSON Exports ──────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> exportAllToJson({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> tasks,
    required Map<String, dynamic> budgets,
  }) async {
    final data = {
      'exportedAt': _ts,
      'expenses': expenses,
      'budgets': budgets,
      'tasks': tasks,
    };
    // Write to temp dir so share_plus can access it without permissions
    final content = const JsonEncoder.withIndent('  ').convert(data);
    final file = await _writeExportFile('all_data_$_ts.json', content);
    await Share.shareXFiles([XFile(file.path)], text: 'HiSaab Export');
  }

  Future<void> exportExpensesToJson(List<Map<String, dynamic>> expenses) async {
    final content = const JsonEncoder.withIndent('  ').convert(expenses);
    final file = await _writeExportFile('expenses_$_tsShort.json', content);
    await Share.shareXFiles([XFile(file.path)], text: 'Expenses Export');
  }

  Future<void> exportTasksToJson(List<Map<String, dynamic>> tasks) async {
    final content = const JsonEncoder.withIndent('  ').convert(tasks);
    final file = await _writeExportFile('tasks_$_tsShort.json', content);
    await Share.shareXFiles([XFile(file.path)], text: 'Tasks Export');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── CSV Exports ───────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> exportExpensesToCsv(List<Map<String, dynamic>> expenses) async {
    final buf = StringBuffer();
    buf.writeln('Date,Amount,Category,Note,Type,From SMS,Bank');
    for (final e in expenses) {
      buf.writeln([
        _escapeCsv(e['date'] ?? ''),
        e['amount'] ?? 0,
        _escapeCsv(e['category'] ?? ''),
        _escapeCsv(e['note'] ?? ''),
        e['isIncome'] == true ? 'Income' : 'Expense',
        e['fromSms'] == true ? 'Yes' : 'No',
        _escapeCsv(e['bankName'] ?? ''),
      ].join(','));
    }
    final file =
        await _writeExportFile('expenses_$_tsShort.csv', buf.toString());
    await Share.shareXFiles([XFile(file.path)], text: 'Expenses CSV Export');
  }

  Future<void> exportTasksToCsv(List<Map<String, dynamic>> tasks) async {
    final buf = StringBuffer();
    buf.writeln(
        'Title,Status,Priority,Deadline,Tags');
    for (final t in tasks) {
      buf.writeln([
        _escapeCsv(t['title'] ?? ''),
        _escapeCsv(t['status'] ?? ''),
        _escapeCsv(t['priority'] ?? ''),
        _escapeCsv(t['deadline'] ?? ''),
        _escapeCsv((t['tags'] as List?)?.join('; ') ?? ''),
      ].join(','));
    }
    final file = await _writeExportFile('tasks_$_tsShort.csv', buf.toString());
    await Share.shareXFiles([XFile(file.path)], text: 'Tasks CSV Export');
  }

  Future<void> exportAllToCsv({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> tasks,
    required Map<String, dynamic> budgets,
  }) async {
    final buf = StringBuffer();

    // Expenses section
    buf.writeln('=== EXPENSES ===');
    buf.writeln('Date,Amount,Category,Note,Type');
    for (final e in expenses) {
      buf.writeln([
        _escapeCsv(e['date'] ?? ''),
        e['amount'] ?? 0,
        _escapeCsv(e['category'] ?? ''),
        _escapeCsv(e['note'] ?? ''),
        e['isIncome'] == true ? 'Income' : 'Expense',
      ].join(','));
    }
    buf.writeln();

    // Tasks section
    buf.writeln('=== TASKS ===');
    buf.writeln(
        'Title,Status,Priority,Deadline,Tags');
    for (final t in tasks) {
      buf.writeln([
        _escapeCsv(t['title'] ?? ''),
        _escapeCsv(t['status'] ?? ''),
        _escapeCsv(t['priority'] ?? ''),
        _escapeCsv(t['deadline'] ?? ''),
        _escapeCsv((t['tags'] as List?)?.join('; ') ?? ''),
      ].join(','));
    }
    buf.writeln();

    final file = await _writeExportFile('all_data_$_ts.csv', buf.toString());
    await Share.shareXFiles([XFile(file.path)], text: 'HiSaab CSV Export');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ── Excel Exports ─────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> exportExpensesToExcel(
      List<Map<String, dynamic>> expenses) async {
    final workbook = Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Expenses';

    final headers = ['Date', 'Amount', 'Category', 'Note', 'Type'];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#6C63FF';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    for (int i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      final row = i + 2;
      sheet.getRangeByIndex(row, 1).setText(e['date'] ?? '');
      sheet
          .getRangeByIndex(row, 2)
          .setNumber((e['amount'] as num?)?.toDouble() ?? 0);
      sheet.getRangeByIndex(row, 3).setText(e['category'] ?? '');
      sheet.getRangeByIndex(row, 4).setText(e['note'] ?? '');
      sheet
          .getRangeByIndex(row, 5)
          .setText(e['isIncome'] == true ? 'Income' : 'Expense');
    }

    for (int i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    final file = await _writeExportBytes('expenses_$_tsShort.xlsx', bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Expenses Excel Export');
  }

  Future<void> exportTasksToExcel(List<Map<String, dynamic>> tasks) async {
    final workbook = Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Tasks';

    final headers = [
      'Title',
      'Status',
      'Priority',
      'Deadline',
      'Tags'
    ];
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#6C63FF';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    for (int i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      final row = i + 2;
      sheet.getRangeByIndex(row, 1).setText(t['title'] ?? '');
      sheet.getRangeByIndex(row, 2).setText(t['status'] ?? '');
      sheet.getRangeByIndex(row, 3).setText(t['priority'] ?? '');
      sheet.getRangeByIndex(row, 4).setText(t['deadline'] ?? '');
      sheet
          .getRangeByIndex(row, 5)
          .setText((t['tags'] as List?)?.join(', ') ?? '');
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    final file = await _writeExportBytes('tasks_$_tsShort.xlsx', bytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Tasks Excel Export');
  }
}
