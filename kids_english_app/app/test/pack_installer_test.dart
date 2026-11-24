import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:be_vui_tieng_anh/data/content_repository.dart';
import 'package:be_vui_tieng_anh/data/pack_installer.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> topicJson(String id, {String title = 'Space', String wordRef = 'w1'}) => {
      'id': id,
      'level': 2,
      'order': 99,
      'title_en': title,
      'title_vi': 'Vũ trụ',
      'map_icon': 'images/map/x.png',
      'words': [
        {'id': 'w1', 'text': 'Star', 'image': 'images/a.png', 'audio': 'audio/a.mp3'},
      ],
      'sentences': [],
      'lessons': [
        {
          'id': '${id}_l1',
          'order': 1,
          'new_words': [wordRef],
          'steps': [
            {
              'type': 'discover',
              'words': [wordRef],
            },
          ],
        },
      ],
    };

Uint8List zip(Map<String, List<int>> files) {
  final a = Archive();
  files.forEach((k, v) => a.addFile(ArchiveFile(k, v.length, v)));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

List<int> j(Object o) => utf8.encode(jsonEncode(o));

void main() {
  late Directory tmp;
  late Directory root;
  late PackInstaller installer;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('installer_test_');
    root = Directory('${tmp.path}/packs');
    installer = PackInstaller(root);
  });
  tearDown(() => tmp.delete(recursive: true));

  test('cài gói hợp lệ, giải nén đủ file và FileContentSource đọc được', () async {
    final t = await installer.install(zip({
      'topic.json': j(topicJson('t99_space')),
      'images/a.png': [1, 2, 3],
      'audio/a.mp3': [4, 5],
    }));
    expect(t.id, 't99_space');
    expect(File('${root.path}/t99_space/images/a.png').readAsBytesSync(), [1, 2, 3]);
    expect(installer.isInstalled('t99_space'), isTrue);
    final topics = await FileContentSource(root).loadTopics();
    expect(topics.single.id, 't99_space');
    expect(root.listSync().length, 1, reason: 'không còn thư mục tạm');
  });

  test('chấp nhận thư mục bọc ngoài duy nhất', () async {
    final t = await installer.install(zip({
      'wrapper/topic.json': j(topicJson('t98_wrap')),
      'wrapper/images/a.png': [9],
    }));
    expect(t.id, 't98_wrap');
    expect(File('${root.path}/t98_wrap/images/a.png').existsSync(), isTrue);
  });

  test('từ chối zip-slip (../, tuyệt đối, backslash, ổ đĩa)', () async {
    for (final bad in ['../evil.txt', '/abs.txt', r'..\evil.txt', 'a/../../evil.txt', 'C:/evil.txt']) {
      await expectLater(
        installer.install(zip({'topic.json': j(topicJson('t97_x')), bad: [1]})),
        throwsA(isA<PackException>()),
        reason: bad,
      );
    }
    expect(File('${tmp.path}/evil.txt').existsSync(), isFalse);
    expect(installer.isInstalled('t97_x'), isFalse);
  });

  test('từ chối gói thiếu topic.json, id không an toàn, topic không hợp lệ, zip hỏng', () async {
    await expectLater(installer.install(zip({'a.txt': [1]})), throwsA(isA<PackException>()));
    await expectLater(installer.install(zip({'topic.json': j(topicJson('../hack'))})), throwsA(isA<PackException>()));
    await expectLater(installer.install(zip({'topic.json': j(topicJson('Bad Id'))})), throwsA(isA<PackException>()));
    await expectLater(
      installer.install(zip({'topic.json': j(topicJson('t96_bad', wordRef: 'khong_ton_tai'))})),
      throwsA(isA<PackException>()),
    );
    await expectLater(installer.install(Uint8List.fromList([1, 2, 3])), throwsA(isA<PackException>()));
    expect(root.existsSync() ? root.listSync() : [], isEmpty);
  });

  test('cài lại thay thế hoàn toàn bản cũ', () async {
    await installer.install(zip({'topic.json': j(topicJson('t95_up', title: 'Old')), 'old.txt': [1]}));
    await installer.install(zip({'topic.json': j(topicJson('t95_up', title: 'New')), 'new.txt': [2]}));
    final topics = await FileContentSource(root).loadTopics();
    expect(topics.single.titleEn, 'New');
    expect(File('${root.path}/t95_up/old.txt').existsSync(), isFalse);
    expect(File('${root.path}/t95_up/new.txt').existsSync(), isTrue);
    expect(root.listSync().length, 1);
  });

  test('uninstall xoá gói và từ chối id lạ', () async {
    await installer.install(zip({'topic.json': j(topicJson('t94_rm'))}));
    expect(await installer.uninstall('t94_rm'), isTrue);
    expect(installer.isInstalled('t94_rm'), isFalse);
    expect(await installer.uninstall('t94_rm'), isFalse);
    expect(await installer.uninstall('../x'), isFalse);
  });
}
