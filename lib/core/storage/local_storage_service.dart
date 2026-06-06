import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static const String _folderName = 'DigitalCompanion';

  Future<Directory> get _appDir async {
    Directory? baseDir;

    if (Platform.isAndroid) {
      try {
        // getExternalStorageDirectory() returns an app-scoped path like
        // /sdcard/Android/data/<package>/files — no WRITE_EXTERNAL_STORAGE
        // permission required on any Android version.
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          baseDir = Directory('${extDir.path}/$_folderName');
        }
      } catch (_) {}
    }

    baseDir ??= Directory(
      '${(await getApplicationDocumentsDirectory()).path}/$_folderName',
    );

    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return baseDir;
  }

  Future<File> _file(String name) async {
    final dir = await _appDir;
    return File('${dir.path}/$name');
  }

  // ── Read ───────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> readList(String fileName) async {
    try {
      final file = await _file(fileName);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> readMap(String fileName) async {
    try {
      final file = await _file(fileName);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (e) {
      return {};
    }
  }

  // ── Write ──────────────────────────────────────────────────────────────────
  Future<void> writeList(String fileName, List<Map<String, dynamic>> data) async {
    final file = await _file(fileName);
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> writeMap(String fileName, Map<String, dynamic> data) async {
    final file = await _file(fileName);
    await file.writeAsString(jsonEncode(data));
  }

  // ── Export ─────────────────────────────────────────────────────────────────
  Future<File> exportJson(String fileName, dynamic data) async {
    final dir = await _appDir;
    final exportDir = Directory('${dir.path}/exports');
    if (!await exportDir.exists()) await exportDir.create();
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file;
  }

  Future<String> get appDirPath async => (await _appDir).path;
}
