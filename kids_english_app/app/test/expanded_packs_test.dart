import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:be_vui_tieng_anh/core/media.dart';
import 'package:be_vui_tieng_anh/data/content_repository.dart';
import 'package:be_vui_tieng_anh/data/models.dart';
import 'package:be_vui_tieng_anh/data/pack_installer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedIds = [
    't06_family',
    't07_wild_animals',
    't08_sea_bugs',
    't09_shapes',
    't10_numbers_sizes',
    't11_fruits',
    't12_food_drinks',
    't13_toys',
    't14_clothes',
    't15_my_house',
    't16_feelings',
    't17_actions',
    't18_routines',
    't19_tableware',
    't20_opposites',
    't21_vehicles',
    't22_weather_nature',
    't23_school',
    't24_jobs',
    't25_party_holidays',
  ];

  test('curriculum.json giữ nguyên 5 chủ đề built-in t01..t05', () {
    final cur = jsonDecode(File('assets/content/curriculum.json').readAsStringSync()) as Map<String, dynamic>;
    final ids = [for (final t in (cur['topics'] as List)) (t as Map)['id']];
    expect(ids, ['t01_hello', 't02_colors', 't03_numbers', 't04_animals', 't05_body']);
  });

  test('chủ đề t06..t25 chỉ phát hành qua gói: KHÔNG nằm trong app/assets', () {
    for (final id in expectedIds) {
      expect(File('assets/content/topics/$id.json').existsSync(), isFalse, reason: '$id không được nằm trong app');
      expect(Directory('assets/images/topics/$id').existsSync(), isFalse, reason: '$id không được nằm trong app');
    }
  });

  test('20 file JSON t06..t25 hợp lệ 100%, đủ từ vựng, bài hát, emoji', () {
    var totalWords = 0;
    for (var i = 0; i < expectedIds.length; i++) {
      final id = expectedIds[i];
      final order = i + 6;
      final expectedLevel = ((order - 1) ~/ 5) + 1;
      final file = File('../content_packs/$id/topic.json');
      expect(file.existsSync(), isTrue, reason: 'Thiếu ${file.path}');

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final topic = Topic.fromJson(json);
      expect(topic.id, id);
      expect(topic.order, order);
      expect(topic.level, expectedLevel);
      expect(validateTopic(topic), isEmpty, reason: id);
      expect(topic.lessons.length, 4, reason: '$id phải có 4 lessons');
      expect(topic.sentences.length, 2, reason: '$id phải có 2 sentences');
      expect(topic.commands, isNotEmpty, reason: '$id phải có TPR commands');
      expect(topic.song, isNotNull, reason: '$id phải có song');
      expect(topic.song!.lyrics.length, 8, reason: '$id song phải có 8 dòng lyrics');

      num prevT = -1;
      for (final l in topic.song!.lyrics) {
        expect(l.t > prevT, isTrue, reason: '$id lyric timestamp phải tăng dần');
        prevT = l.t;
      }

      for (final w in topic.words) {
        expect(w.vi, isNotNull);
        expect(w.vi!.trim(), isNotEmpty);
        expect(wordEmojiMap.containsKey(w.text.toLowerCase().trim()), isTrue,
            reason: 'Thiếu emoji cho "${w.text}" trong wordEmojiMap');
      }

      totalWords += topic.words.length;
    }
    expect(totalWords, 212);
  });

  test('20 gói .bvpack và index.json cài đặt qua PackInstaller thành công ở cả 2 thư mục', () async {
    for (final packDirPath in ['../docs/packs']) {
      final indexFile = File('$packDirPath/index.json');
      expect(indexFile.existsSync(), isTrue, reason: 'Thiếu ${indexFile.path}');
      final indexJson = jsonDecode(indexFile.readAsStringSync()) as Map<String, dynamic>;
      final packs = indexJson['packs'] as List;
      expect(packs.length, 20, reason: '${indexFile.path} phải có đủ 20 gói');
      expect([for (final p in packs) (p as Map)['id']], expectedIds);
      for (final p in packs) {
        expect((p as Map)['version'], greaterThanOrEqualTo(2), reason: '${p['id']} trong ${indexFile.path} phải >= version 2');
      }

      final tempRoot = await Directory.systemTemp.createTemp('verify_20_packs_');
      try {
        final installer = PackInstaller(tempRoot);
        for (final id in expectedIds) {
          final packFile = File('$packDirPath/$id.bvpack');
          expect(packFile.existsSync(), isTrue, reason: 'Thiếu ${packFile.path}');
          final bytes = await packFile.readAsBytes();

          final archive = ZipDecoder().decodeBytes(bytes);
          final names = archive.files.map((f) => f.name).toSet();
          expect(names.contains('topic.json'), isTrue, reason: '${packFile.path} thiếu topic.json');
          final hasSong = names.any((n) => RegExp(r'^audio/songs/s\d{2}_.+\.mp3$').hasMatch(n));
          expect(hasSong, isTrue, reason: '${packFile.path} thiếu file nhạc audio/songs/sXX_*.mp3');

          // Mọi đường dẫn media (ảnh + giọng đọc từ/câu/TPR + nhạc) trong topic.json phải có trong gói.
          final topicText = utf8.decode(archive.findFile('topic.json')!.content as List<int>);
          final refs = RegExp(r'"((?:images|audio)/[^"]+)"').allMatches(topicText).map((m) => m.group(1)!).toSet();
          final missingMedia = refs.where((r) => !names.contains(r)).toList();
          expect(missingMedia, isEmpty, reason: '${packFile.path} thiếu media: $missingMedia');

          final installedTopic = await installer.install(bytes);
          expect(installedTopic.id, id);
          expect(validateTopic(installedTopic), isEmpty);
          expect(File('${tempRoot.path}/$id/${installedTopic.song!.audio}').existsSync(), isTrue);

          // Kiểm tra đầy đủ toàn bộ ảnh PNG trong gói .bvpack
          expect(names.contains(installedTopic.mapIcon), isTrue,
              reason: '${packFile.path} thiếu map_icon: ${installedTopic.mapIcon}');
          expect(names.contains(installedTopic.song!.cover), isTrue,
              reason: '${packFile.path} thiếu song.cover: ${installedTopic.song!.cover}');
          for (final w in installedTopic.words) {
            expect(names.contains(w.image), isTrue,
                reason: '${packFile.path} thiếu word image: ${w.image}');
          }
          final stickers = <String>{};
          for (final lesson in installedTopic.lessons) {
            for (final step in lesson.steps) {
              if (step.type == 'celebrate' && step.sticker != null) {
                stickers.add(step.sticker!);
                final stkPath = 'images/stickers/${step.sticker}.png';
                expect(names.contains(stkPath), isTrue,
                    reason: '${packFile.path} thiếu sticker: $stkPath');
              }
            }
          }
          expect(stickers.length, 4, reason: '${packFile.path} phải có đủ 4 ảnh sticker');
          for (final cmd in installedTopic.commands) {
            expect(names.contains(cmd.image), isTrue,
                reason: '${packFile.path} thiếu TPR image: ${cmd.image}');
          }
        }

        final loaded = await FileContentSource(tempRoot).loadTopics();
        expect(loaded.length, 20);
      } finally {
        await tempRoot.delete(recursive: true);
      }
    }
  });
}
