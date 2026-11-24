import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:be_vui_tieng_anh/app/providers.dart';
import 'package:be_vui_tieng_anh/data/drive_sync_service.dart';
import 'package:be_vui_tieng_anh/data/pack_installer.dart';
import 'package:be_vui_tieng_anh/data/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const folder = 'FOLDER';

class FakeAuth implements DriveAuth {
  FakeAuth(this.account);
  DriveAccount? account;
  @override
  Future<DriveAccount?> signIn() async => account;
  @override
  Future<DriveAccount?> signInSilently() async => account;
  @override
  Future<void> signOut() async => account = null;
}

Uint8List pack(String id) {
  final topic = {
    'id': id,
    'title_en': id,
    'words': [
      {'id': 'w1', 'text': 'A', 'image': 'images/a.png', 'audio': 'audio/a.mp3'},
    ],
    'lessons': [
      {
        'id': '${id}_l1',
        'new_words': ['w1'],
        'steps': [
          {
            'type': 'discover',
            'words': ['w1'],
          },
        ],
      },
    ],
  };
  final b = utf8.encode(jsonEncode(topic));
  final a = Archive()..addFile(ArchiveFile('topic.json', b.length, b));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

http.Response jsonResp(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json'});

typedef FakeFile = ({String name, String modified, List<int> bytes});

/// Drive giả.
class FakeDrive {
  FakeDrive(this.files, {this.folderStatus = 200, this.pageSize = 100});
  final Map<String, FakeFile> files;
  int folderStatus;
  int pageSize;
  final requests = <Uri>[];
  final headers = <Map<String, String>>[];
  final failing = <String>{};

  Future<http.Response> handle(http.Request r) async {
    requests.add(r.url);
    headers.add(r.headers);
    final seg = r.url.pathSegments; // drive, v3, files, <id>
    if (seg.length == 4 && seg[3] == folder) {
      return folderStatus == 200 ? jsonResp({'id': folder, 'name': 'kho'}) : jsonResp({'error': 'x'}, folderStatus);
    }
    if (seg.length == 3 && seg[2] == 'files') {
      expect(r.url.queryParameters['q'], contains("'$folder' in parents"));
      final entries = files.entries.toList();
      final start = int.parse(r.url.queryParameters['pageToken'] ?? '0');
      final end = (start + pageSize).clamp(0, entries.length);
      return jsonResp({
        'files': [
          for (final e in entries.sublist(start, end))
            {
              'id': e.key,
              'name': e.value.name,
              'mimeType': 'application/zip',
              'modifiedTime': e.value.modified,
              'size': '${e.value.bytes.length}',
            },
        ],
        if (end < entries.length) 'nextPageToken': '$end',
      });
    }
    if (seg.length == 4 && r.url.queryParameters['alt'] == 'media') {
      final id = seg[3];
      if (failing.contains(id)) return http.Response('boom', 500);
      return http.Response.bytes(files[id]!.bytes, 200);
    }
    return http.Response('?', 404);
  }
}

void main() {
  late Directory tmp;
  late PackInstaller installer;
  late Map<String, int> versions;
  const acc = DriveAccount(email: 'a@b.c', accessToken: 'TOKEN');

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('drive_test_');
    installer = PackInstaller(Directory('${tmp.path}/packs'));
    versions = {};
  });
  tearDown(() => tmp.delete(recursive: true));

  DriveSyncService svc(FakeDrive d, {DriveAccount? account = acc, String apiKey = ''}) => DriveSyncService(
        auth: FakeAuth(account),
        installer: installer,
        client: MockClient(d.handle),
        folderId: () => folder,
        readVersions: () => versions,
        writeVersions: (v) async => versions = Map.of(v),
        apiKey: apiKey,
      );

  List<int> indexBytes(List<Map<String, dynamic>> packs) => utf8.encode(jsonEncode({'packs': packs}));

  FakeFile idx(String modified, List<Map<String, dynamic>> packs) =>
      (name: 'index.json', modified: modified, bytes: indexBytes(packs));

  test('chưa đăng nhập -> notSignedIn, không gọi mạng', () async {
    final d = FakeDrive({});
    final s = svc(d, account: null);
    expect(await s.checkAccess(), DriveAccessStatus.notSignedIn);
    final r = await s.syncNow();
    expect(r.status, DriveAccessStatus.notSignedIn);
    expect(d.requests, isEmpty);
    expect(await s.syncInBackground(), 0);
  });

  test('403 và 404 trên thư mục -> noPermission', () async {
    for (final code in [403, 404]) {
      final d = FakeDrive({}, folderStatus: code);
      final s = svc(d);
      await s.signInSilently();
      expect(await s.checkAccess(), DriveAccessStatus.noPermission);
      expect((await s.syncNow()).status, DriveAccessStatus.noPermission);
      expect(await s.syncInBackground(), 0);
    }
  });

  test('403 do chưa bật Drive API / quota -> error, không phải noPermission', () async {
    for (final reason in ['accessNotConfigured', 'userRateLimitExceeded']) {
      final s = DriveSyncService(
        auth: FakeAuth(acc),
        installer: installer,
        client: MockClient((_) async => jsonResp({
              'error': {
                'code': 403,
                'errors': [
                  {'reason': reason},
                ],
              },
            }, 403)),
        folderId: () => folder,
        readVersions: () => versions,
        writeVersions: (v) async => versions = v,
      );
      await s.signInSilently();
      expect(await s.checkAccess(), DriveAccessStatus.error);
    }
  });

  test('lỗi mạng -> error, syncInBackground không ném', () async {
    final s = DriveSyncService(
      auth: FakeAuth(acc),
      installer: installer,
      client: MockClient((_) async => throw const SocketException('offline')),
      folderId: () => folder,
      readVersions: () => versions,
      writeVersions: (v) async => versions = v,
      apiKey: '',
    );
    await s.signInSilently();
    expect(await s.checkAccess(), DriveAccessStatus.error);
    expect((await s.syncNow()).status, DriveAccessStatus.error);
    expect(await s.syncInBackground(), 0);
  });

  test('theo index: cài mới, bỏ qua khi cùng version, cập nhật khi version cao hơn; gửi Bearer token', () async {
    final d = FakeDrive({
      'i': idx('2026-01-01T00:00:00Z', [
        {'id': 't06_fruits', 'version': 1, 'file': 't06_fruits.bvpack'},
      ]),
      'p6': (name: 't06_fruits.bvpack', modified: '2026-01-01T00:00:00Z', bytes: pack('t06_fruits')),
    });
    final s = svc(d);
    await s.signInSilently();
    var r = await s.syncNow();
    expect(r.status, DriveAccessStatus.ready);
    expect(r.installed, 1);
    expect(r.errors, isEmpty);
    expect(versions['t06_fruits'], 1);
    expect(installer.isInstalled('t06_fruits'), isTrue);
    expect(d.headers.every((h) => h['Authorization'] == 'Bearer TOKEN'), isTrue);

    r = await s.syncNow();
    expect(r.installed, 0);
    expect(r.upToDate, 1);

    d.files['i'] = idx('2026-02-01T00:00:00Z', [
      {'id': 't06_fruits', 'version': 2, 'file': 't06_fruits.bvpack'},
    ]);
    r = await s.syncNow();
    expect(r.installed, 1);
    expect(versions['t06_fruits'], 2);
    expect(await s.syncInBackground(), 0);
  });

  test('gói đã bị gỡ khỏi máy thì được cài lại dù version cũ còn', () async {
    final d = FakeDrive({
      'i': idx('2026-01-01T00:00:00Z', [
        {'id': 't06_fruits', 'version': 1, 'file': 't06_fruits.bvpack'},
      ]),
      'p6': (name: 't06_fruits.bvpack', modified: '2026-01-01T00:00:00Z', bytes: pack('t06_fruits')),
    });
    final s = svc(d);
    await s.signInSilently();
    await s.syncNow();
    await installer.uninstall('t06_fruits');
    expect((await s.syncNow()).installed, 1);
  });

  test('fallback modifiedTime cho file không có trong index', () async {
    final d = FakeDrive({
      'p7': (name: 't07_transport.zip', modified: '2026-03-01T10:00:00Z', bytes: pack('t07_transport')),
    });
    final s = svc(d);
    await s.signInSilently();
    var r = await s.syncNow();
    expect(r.installed, 1);
    expect(versions['t07_transport'], DateTime.parse('2026-03-01T10:00:00Z').millisecondsSinceEpoch);
    expect((await s.syncNow()).upToDate, 1);

    d.files['p7'] = (name: 't07_transport.zip', modified: '2026-03-02T10:00:00Z', bytes: pack('t07_transport'));
    r = await s.syncNow();
    expect(r.installed, 1);
  });

  test('một gói lỗi (tải 500 / zip hỏng / thiếu file) không chặn gói khác', () async {
    final d = FakeDrive({
      'i': idx('2026-01-01T00:00:00Z', [
        {'id': 'a_bad_dl', 'version': 1, 'file': 'a_bad_dl.bvpack'},
        {'id': 'b_corrupt', 'version': 1, 'file': 'b_corrupt.bvpack'},
        {'id': 'c_missing', 'version': 1, 'file': 'c_missing.bvpack'},
        {'id': 'd_ok', 'version': 1, 'file': 'd_ok.bvpack'},
      ]),
      'f1': (name: 'a_bad_dl.bvpack', modified: '2026-01-01T00:00:00Z', bytes: pack('a_bad_dl')),
      'f2': (name: 'b_corrupt.bvpack', modified: '2026-01-01T00:00:00Z', bytes: [1, 2, 3]),
      'f4': (name: 'd_ok.bvpack', modified: '2026-01-01T00:00:00Z', bytes: pack('d_ok')),
    })..failing.add('f1');
    final s = svc(d);
    await s.signInSilently();
    final r = await s.syncNow();
    expect(r.status, DriveAccessStatus.ready);
    expect(r.installed, 1);
    expect(r.errors.length, 3);
    expect(installer.isInstalled('d_ok'), isTrue);
    expect(versions.containsKey('a_bad_dl'), isFalse);
  });

  test('phân trang files.list bằng nextPageToken', () async {
    final d = FakeDrive({
      for (var i = 0; i < 5; i++)
        'f$i': (name: 'p0$i.bvpack', modified: '2026-01-01T00:00:00Z', bytes: pack('p0$i')),
    }, pageSize: 2);
    final s = svc(d);
    await s.signInSilently();
    expect((await s.syncNow()).installed, 5);
  });

  test('API key công khai khi chưa đăng nhập: dùng ?key=, không có Authorization', () async {
    final d = FakeDrive({
      'p8': (name: 'p08.bvpack', modified: '2026-01-01T00:00:00Z', bytes: pack('p08')),
    });
    final s = svc(d, account: null, apiKey: 'KEY123');
    expect(await s.checkAccess(), DriveAccessStatus.ready);
    expect((await s.syncNow()).installed, 1);
    expect(d.requests.every((u) => u.queryParameters['key'] == 'KEY123'), isTrue);
    expect(d.headers.every((h) => !h.containsKey('Authorization')), isTrue);
  });

  test('cài đặt Drive: mặc định, lưu và đọc lại, version map đọc an toàn', () async {
    final dir = await Directory.systemTemp.createTemp('settings_test_');
    final st = await Storage.open(path: dir.path);
    try {
      final c = ProviderContainer(overrides: [storageProvider.overrideWithValue(st)]);
      var s = c.read(settingsProvider);
      expect(s.autoSyncDrive, isFalse);
      expect(s.driveFolderId, '10d5w1ZMGNRy4OmdX6_6nnhpaIu1H6hHm');
      expect(s.lastDriveSyncAt, isNull);
      expect(st.installedPackVersions(), isEmpty);

      await c.read(settingsProvider.notifier).setAutoSyncDrive(true);
      await c.read(settingsProvider.notifier).markDriveSynced(DateTime.utc(2026, 11, 23));
      await st.putInstalledPackVersions({'t06': 3});
      c.dispose();

      final c2 = ProviderContainer(overrides: [storageProvider.overrideWithValue(st)]);
      s = c2.read(settingsProvider);
      expect(s.autoSyncDrive, isTrue);
      expect(s.lastDriveSyncAt, startsWith('2026-11-23'));
      expect(st.installedPackVersions(), {'t06': 3});
      c2.dispose();
    } finally {
      await Hive.close();
      await dir.delete(recursive: true);
    }
  });
}
