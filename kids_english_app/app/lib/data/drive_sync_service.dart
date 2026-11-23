import 'dart:convert';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'pack_installer.dart';

/// Khoá API tuỳ chọn (chỉ dùng khi chưa đăng nhập; thư mục Drive phải chia sẻ "Anyone with the link").
/// Truyền khi chạy: `--dart-define=DRIVE_API_KEY=...`
const driveApiKey = String.fromEnvironment('DRIVE_API_KEY');

/// Web client ID (OAuth "Web application") — google_sign_in v7 trên Android BẮT BUỘC có.
/// Truyền khi chạy: `--dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com`
const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

const driveReadonlyScope = 'https://www.googleapis.com/auth/drive.readonly';

// ---------------------------------------------------------------- Xác thực
class DriveAccount {
  const DriveAccount({required this.email, required this.accessToken});
  final String email;
  final String accessToken;
}

class DriveAuthException implements Exception {
  DriveAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lớp trừu tượng bọc đăng nhập Google để logic Drive test được bằng bản giả.
abstract class DriveAuth {
  /// Đăng nhập có giao diện. Trả null nếu người dùng huỷ. Ném [DriveAuthException] khi lỗi cấu hình.
  Future<DriveAccount?> signIn();

  /// Khôi phục phiên không hiện giao diện. Trả null nếu không thể.
  Future<DriveAccount?> signInSilently();

  Future<void> signOut();
}

/// Cài đặt thật dựa trên google_sign_in v7.
class GoogleDriveAuth implements DriveAuth {
  GoogleDriveAuth({this.serverClientId = googleServerClientId});
  final String serverClientId;
  Future<void>? _init;

  Future<void> _ensureInit() => _init ??= GoogleSignIn.instance.initialize(
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      );

  String _describe(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Chưa cấu hình đăng nhập Google (OAuth client / SHA-1). Xem docs/HUONG_DAN_CAU_HINH_GOOGLE_DRIVE.md. (${e.description ?? e.code.name})';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Không mở được màn hình đăng nhập Google.';
      default:
        return 'Đăng nhập Google thất bại: ${e.description ?? e.code.name}';
    }
  }

  @override
  Future<DriveAccount?> signIn() async {
    try {
      await _ensureInit();
      final account = await GoogleSignIn.instance.authenticate(scopeHint: const [driveReadonlyScope]);
      final authz = await account.authorizationClient.authorizeScopes(const [driveReadonlyScope]);
      return DriveAccount(email: account.email, accessToken: authz.accessToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw DriveAuthException(_describe(e));
    } catch (e) {
      throw DriveAuthException('Đăng nhập Google thất bại: $e');
    }
  }

  @override
  Future<DriveAccount?> signInSilently() async {
    try {
      await _ensureInit();
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account == null) return null;
      final authz = await account.authorizationClient.authorizationForScopes(const [driveReadonlyScope]);
      if (authz == null) return null;
      return DriveAccount(email: account.email, accessToken: authz.accessToken);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureInit();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

// ------------------------------------------------------------------ Drive
enum DriveAccessStatus { notSignedIn, noPermission, ready, error }

class DriveFile {
  const DriveFile({required this.id, required this.name, this.mimeType = '', this.modifiedTime, this.size});
  final String id;
  final String name;
  final String mimeType;
  final DateTime? modifiedTime;
  final int? size;

  factory DriveFile.fromJson(Map<String, dynamic> j) => DriveFile(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        mimeType: (j['mimeType'] ?? '') as String,
        modifiedTime: DateTime.tryParse((j['modifiedTime'] ?? '') as String),
        size: int.tryParse('${j['size'] ?? ''}'),
      );
}

class DriveSyncResult {
  const DriveSyncResult({
    required this.status,
    this.installed = 0,
    this.upToDate = 0,
    this.errors = const [],
    this.message,
  });
  final DriveAccessStatus status;
  final int installed;
  final int upToDate;
  final List<String> errors;
  final String? message;
}

class _Candidate {
  _Candidate({required this.key, required this.file, required this.version, required this.fromIndex});
  final String key;
  final DriveFile file;
  final int version;
  final bool fromIndex;
}

/// Logic Drive REST v3: kiểm tra quyền, đọc index.json, tải & cài gói.
class DriveSyncService {
  DriveSyncService({
    required this.auth,
    required this.installer,
    required this.client,
    required this.folderId,
    required this.readVersions,
    required this.writeVersions,
    this.apiKey = driveApiKey,
  });

  final DriveAuth auth;
  final PackInstaller installer;
  final http.Client client;
  final String Function() folderId;
  final Map<String, int> Function() readVersions;
  final Future<void> Function(Map<String, int>) writeVersions;
  final String apiKey;

  static const _base = 'https://www.googleapis.com/drive/v3';

  DriveAccount? _account;
  DriveAccount? get account => _account;

  Future<DriveAccount?> signIn() async => _account = await auth.signIn() ?? _account;

  Future<DriveAccount?> signInSilently() async => _account = await auth.signInSilently();

  Future<void> signOut() async {
    await auth.signOut();
    _account = null;
  }

  bool get _canRequest => _account != null || apiKey.isNotEmpty;

  Uri _uri(String path, Map<String, String> q) {
    final params = {...q};
    if (_account == null && apiKey.isNotEmpty) params['key'] = apiKey;
    return Uri.parse('$_base/$path').replace(queryParameters: params);
  }

  Map<String, String> get _headers => {'Authorization': ?(_account == null ? null : 'Bearer ${_account!.accessToken}')};

  /// Kiểm tra quyền truy cập thư mục kho chủ đề.
  Future<DriveAccessStatus> checkAccess() async {
    if (!_canRequest) return DriveAccessStatus.notSignedIn;
    try {
      final r = await client.get(_uri('files/${folderId()}', {'fields': 'id,name'}), headers: _headers);
      if (r.statusCode == 200) return DriveAccessStatus.ready;
      if (r.statusCode == 403 && _isConfigOrQuotaError(r.body)) return DriveAccessStatus.error;
      if (r.statusCode == 403 || r.statusCode == 404) return DriveAccessStatus.noPermission;
      if (r.statusCode == 401) {
        _account = null;
        return apiKey.isNotEmpty ? DriveAccessStatus.error : DriveAccessStatus.notSignedIn;
      }
      return DriveAccessStatus.error;
    } catch (_) {
      return DriveAccessStatus.error;
    }
  }

  /// 403 do chưa bật Drive API / hết hạn mức không phải là "chưa được cấp quyền thư mục".
  static bool _isConfigOrQuotaError(String body) =>
      RegExp(r'accessNotConfigured|SERVICE_DISABLED|rateLimitExceeded|userRateLimitExceeded|dailyLimitExceeded')
          .hasMatch(body);

  Future<List<DriveFile>> listFolder() async {
    final out = <DriveFile>[];
    String? token;
    do {
      final r = await client.get(
        _uri('files', {
          'q': "'${folderId()}' in parents and trashed=false",
          'fields': 'nextPageToken,files(id,name,mimeType,modifiedTime,size)',
          'pageSize': '100',
          'pageToken': ?token,
        }),
        headers: _headers,
      );
      if (r.statusCode != 200) throw Exception('Không đọc được danh sách thư mục (HTTP ${r.statusCode})');
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      for (final f in (j['files'] as List? ?? const [])) {
        out.add(DriveFile.fromJson(f as Map<String, dynamic>));
      }
      token = j['nextPageToken'] as String?;
    } while (token != null && token.isNotEmpty);
    return out;
  }

  Future<Uint8List> _download(DriveFile f) async {
    final r = await client.get(_uri('files/${f.id}', {'alt': 'media'}), headers: _headers);
    if (r.statusCode != 200) throw Exception('Tải ${f.name} thất bại (HTTP ${r.statusCode})');
    return r.bodyBytes;
  }

  static bool _isPackFile(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.bvpack') || n.endsWith('.zip');
  }

  static String _baseName(String name) {
    final i = name.lastIndexOf('.');
    return i > 0 ? name.substring(0, i) : name;
  }

  /// Kiểm tra & nạp các gói mới/cập nhật. Không ném lỗi — mọi vấn đề nằm trong kết quả.
  Future<DriveSyncResult> syncNow({void Function(String message)? onProgress}) async {
    void say(String m) => onProgress?.call(m);
    try {
      say('Đang kiểm tra quyền truy cập...');
      final status = await checkAccess();
      if (status != DriveAccessStatus.ready) return DriveSyncResult(status: status);

      say('Đang đọc danh sách gói...');
      final files = await listFolder();
      final errors = <String>[];
      final byName = {for (final f in files) f.name: f};
      final candidates = <_Candidate>[];
      final inIndex = <String>{};

      final indexFile = byName['index.json'];
      if (indexFile != null) {
        try {
          final j = jsonDecode(utf8.decode(await _download(indexFile))) as Map<String, dynamic>;
          for (final p in (j['packs'] as List? ?? const [])) {
            try {
              final m = p as Map<String, dynamic>;
              final id = m['id'] as String;
              final fileName = m['file'] as String;
              final version = (m['version'] as num).toInt();
              inIndex.add(fileName);
              final f = byName[fileName];
              if (f == null) {
                errors.add('$id: không thấy file $fileName trong thư mục');
                continue;
              }
              candidates.add(_Candidate(key: id, file: f, version: version, fromIndex: true));
            } catch (e) {
              errors.add('index.json: mục gói không hợp lệ ($e)');
            }
          }
        } catch (e) {
          errors.add('index.json không đọc được: $e');
        }
      }
      for (final f in files) {
        if (!_isPackFile(f.name) || inIndex.contains(f.name)) continue;
        final t = f.modifiedTime;
        if (t == null) continue;
        candidates.add(_Candidate(key: _baseName(f.name), file: f, version: t.millisecondsSinceEpoch, fromIndex: false));
      }

      final versions = readVersions();
      var installed = 0;
      var upToDate = 0;
      for (final c in candidates) {
        final cur = versions[c.key];
        final needs = cur == null || cur < c.version || (c.fromIndex && !installer.isInstalled(c.key));
        if (!needs) {
          upToDate++;
          continue;
        }
        try {
          say('Đang tải ${c.key}...');
          final bytes = await _download(c.file);
          say('Đang cài ${c.key}...');
          final topic = await installer.install(bytes);
          versions[topic.id] = c.version;
          versions[c.key] = c.version;
          await writeVersions(versions);
          installed++;
          say('Đã cài ${topic.titleEn}');
        } catch (e) {
          errors.add('${c.key}: $e');
        }
      }
      return DriveSyncResult(status: DriveAccessStatus.ready, installed: installed, upToDate: upToDate, errors: errors);
    } catch (e) {
      return DriveSyncResult(status: DriveAccessStatus.error, errors: ['$e'], message: '$e');
    }
  }

  /// Đồng bộ ngầm: chỉ dùng đăng nhập im lặng; không bao giờ ném lỗi. Trả số gói đã cài.
  Future<int> syncInBackground() async {
    try {
      if (_account == null) await signInSilently();
      if (!_canRequest) return 0;
      final r = await syncNow();
      return r.status == DriveAccessStatus.ready ? r.installed : 0;
    } catch (_) {
      return 0;
    }
  }
}

