import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class GoogleDriveService extends ChangeNotifier {
  static const _folderName = 'DigitalCompanion';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );
  bool _isInitialized = false;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      // initialization is not required in standard GoogleSignIn
      _isInitialized = true;
    }
  }

  GoogleSignInAccount? _account;
  String? _folderId;
  bool _isSignedIn = false;

  bool get isSignedIn => _isSignedIn;
  String? get userEmail => _account?.email;
  String? get displayName => _account?.displayName;

  Future<drive.DriveApi?> _getDriveApi() async {
    if (_account == null) return null;
    try {
      final headers = await _account!.authHeaders;
      return drive.DriveApi(_AuthClient(headers));
    } catch (e) {
      return null;
    }
  }

  Future<bool> signIn() async {
    try {
      await _ensureInitialized();
      _account = await _googleSignIn.signIn();
      _isSignedIn = _account != null;
      if (_isSignedIn) await _ensureFolder();
      notifyListeners();
      return _isSignedIn;
    } catch (e) {
      _isSignedIn = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _folderId = null;
    _isSignedIn = false;
    notifyListeners();
  }

  Future<void> tryRestoreSession() async {
    try {
      await _ensureInitialized();
      _account = await _googleSignIn.signInSilently();
      _isSignedIn = _account != null;
      if (_isSignedIn) await _ensureFolder();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _ensureFolder() async {
    final api = await _getDriveApi();
    if (api == null) return;

    final list = await api.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and name='$_folderName' and trashed=false",
      spaces: 'drive',
    );

    if (list.files != null && list.files!.isNotEmpty) {
      _folderId = list.files!.first.id;
    } else {
      final folder = drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder);
      _folderId = created.id;
    }
  }

  Future<void> uploadFile(String fileName, String content) async {
    if (!_isSignedIn || _folderId == null) return;
    final api = await _getDriveApi();
    if (api == null) return;

    // Check if file exists
    final list = await api.files.list(
      q: "name='$fileName' and '$_folderId' in parents and trashed=false",
      spaces: 'drive',
    );

    final media = drive.Media(
      Stream.fromIterable([utf8.encode(content)]),
      utf8.encode(content).length,
      contentType: 'application/json',
    );

    if (list.files != null && list.files!.isNotEmpty) {
      // Update
      final fileId = list.files!.first.id!;
      await api.files.update(drive.File(), fileId, uploadMedia: media);
    } else {
      // Create
      final file = drive.File()
        ..name = fileName
        ..parents = [_folderId!];
      await api.files.create(file, uploadMedia: media);
    }
  }

  Future<String?> downloadFile(String fileName) async {
    if (!_isSignedIn || _folderId == null) return null;
    final api = await _getDriveApi();
    if (api == null) return null;

    final list = await api.files.list(
      q: "name='$fileName' and '$_folderId' in parents and trashed=false",
      spaces: 'drive',
    );

    if (list.files == null || list.files!.isEmpty) return null;

    final fileId = list.files!.first.id!;
    final response = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }
}
