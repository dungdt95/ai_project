import 'dart:convert';
import 'dart:io';

import 'package:be_vui_tieng_anh/data/content_repository.dart';
import 'package:be_vui_tieng_anh/data/leitner.dart';
import 'package:be_vui_tieng_anh/data/models.dart';
import 'package:be_vui_tieng_anh/data/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// AssetBundle đọc thẳng từ đĩa để test nội dung thật trong assets/content.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nội dung JSON', () {
    test('nạp được 5 chủ đề, đúng thứ tự, đủ tham chiếu', () async {
      final topics = await ContentRegistry([AssetContentSource(bundle: _DiskBundle())]).load();
      expect(topics.map((t) => t.id).toList(),
          ['t01_hello', 't02_colors', 't03_numbers', 't04_animals', 't05_body']);
      for (final t in topics) {
        expect(validateTopic(t), isEmpty, reason: t.id);
        expect(t.lessons, isNotEmpty);
        expect(t.song, isNotNull);
      }
      expect(topics.fold<int>(0, (a, t) => a + t.words.length), 52);
    });

    test('mọi đường dẫn ảnh/âm thanh theo đúng quy ước ASSET_SPEC', () async {
      final topics = await ContentRegistry([AssetContentSource(bundle: _DiskBundle())]).load();
      final dog = topics[3].wordById('t04_dog')!;
      expect(dog.image, 'images/topics/t04_animals/dog.png');
      expect(dog.audio, 'audio/words/t04_dog.mp3');
      expect(dog.sentenceAudio, 'audio/sentences/t04_dog_s.mp3');
    });

    test('validateTopic phát hiện tham chiếu hỏng', () {
      final j = jsonDecode(File('assets/content/topics/t01_hello.json').readAsStringSync()) as Map<String, dynamic>;
      (j['lessons'] as List).first['new_words'] = ['khong_ton_tai'];
      final errors = validateTopic(Topic.fromJson(j));
      expect(errors, isNotEmpty);
    });

    test('registry: id trùng thì nguồn sau ghi đè nguồn trước', () async {
      final a = AssetContentSource(bundle: _DiskBundle());
      final topics = await ContentRegistry([a, a]).load();
      expect(topics.length, 5);
    });
  });

  group('Leitner', () {
    final now = DateTime(2026, 1, 10, 9);
    test('đúng thì lên box, sai thì về box 1', () {
      var s = WordStat(nextReview: now);
      s = s.update(isCorrect: true, now: now);
      expect(s.box, 2);
      s = s.update(isCorrect: true, now: now);
      expect(s.box, 3);
      expect(s.mastered, isTrue);
      expect(s.nextReview, DateTime(2026, 1, 13));
      s = s.update(isCorrect: false, now: now);
      expect(s.box, 1);
      expect(s.wrong, 1);
    });

    test('box tối đa 5', () {
      var s = WordStat(nextReview: now);
      for (var i = 0; i < 10; i++) {
        s = s.update(isCorrect: true, now: now);
      }
      expect(s.box, 5);
      expect(s.nextReview, DateTime(2026, 1, 24));
    });
  });

  group('Storage', () {
    late Directory dir;
    late Storage st;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('bevui_test_');
      st = await Storage.open(path: dir.path);
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('hồ sơ, tiến độ, thống kê từ, xoá hồ sơ dọn dữ liệu', () async {
      final p = await st.addProfile('An', 'monkey');
      expect(st.profiles().single.nickname, 'An');
      expect(st.isLessonDone(p.id, 'l1'), isFalse);
      await st.completeLesson(p.id, 'l1', stars: 2);
      await st.completeLesson(p.id, 'l1', stars: 1);
      expect(st.starsFor(p.id, 'l1'), 2);
      await st.recordWordAttempt(p.id, 'w1', correct: true);
      expect(st.wordStat(p.id, 'w1')!.box, 2);
      await st.addPlaySeconds(p.id, 60);
      expect(st.secondsPlayed(p.id, DateTime.now()), 60);
      await st.deleteProfile(p.id);
      expect(st.profiles(), isEmpty);
      expect(st.isLessonDone(p.id, 'l1'), isFalse);
      expect(st.wordStat(p.id, 'w1'), isNull);
    });

    test('cài đặt: gợi ý tiếng Việt mặc định tắt và lưu được', () async {
      expect(st.setting(SettingKeys.viHints, false), isFalse);
      await st.putSetting(SettingKeys.viHints, true);
      expect(st.setting(SettingKeys.viHints, false), isTrue);
    });
  });
}
