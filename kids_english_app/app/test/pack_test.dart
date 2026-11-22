import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:be_vui_tieng_anh/features/parent/topic_packs_tab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm thử đóng gói và nạp Content Pack (.bvpack)', () {
    late Directory tempDir;
    late Directory packsDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pack_test_');
      packsDir = Directory('${tempDir.path}/packs');
      await packsDir.create(recursive: true);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('Đóng gói một chủ đề thành .bvpack và giải nén nạp qua FileContentSource', () async {
      // 1. Tạo thư mục chủ đề giả lập
      final topicDir = Directory('${tempDir.path}/sample_topic');
      await topicDir.create();

      final sampleTopicJson = {
        "id": "t99_space",
        "level": 2,
        "order": 99,
        "title_en": "Space Adventure",
        "title_vi": "Khám phá Vũ trụ",
        "map_icon": "images/map/space.png",
        "words": [
          {
            "id": "t99_star",
            "text": "Star",
            "image": "images/topics/t99/star.png",
            "audio": "audio/words/star.mp3",
            "sentence": "Look at the star!",
            "sentence_audio": "audio/sentences/star_s.mp3"
          }
        ],
        "sentences": [],
        "lessons": [
          {
            "id": "t99_l1",
            "order": 1,
            "new_words": ["t99_star"],
            "steps": [
              {"type": "discover", "words": ["t99_star"]}
            ]
          }
        ],
        "commands": []
      };

      final topicJsonFile = File('${topicDir.path}/topic.json');
      await topicJsonFile.writeAsString(jsonEncode(sampleTopicJson));

      // 2. Tạo file ZIP (.bvpack)
      final archive = Archive();
      final bytes = await topicJsonFile.readAsBytes();
      archive.addFile(ArchiveFile('topic.json', bytes.length, bytes));

      final packFile = File('${tempDir.path}/space.bvpack');
      await packFile.writeAsBytes(ZipEncoder().encode(archive));
      expect(await packFile.exists(), isTrue);

      // 3. Giả lập giải nén vào thư mục packsDir
      final targetInstalledDir = Directory('${packsDir.path}/t99_space');
      await targetInstalledDir.create();
      final unzippedArchive = ZipDecoder().decodeBytes(await packFile.readAsBytes());
      for (final file in unzippedArchive) {
        if (file.isFile) {
          final outFile = File('${targetInstalledDir.path}/${file.name}');
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      // 4. Kiểm tra nạp bằng FileContentSource
      final source = FileContentSource(packsDir);
      final topics = await source.loadTopics();

      expect(topics.length, 1);
      final loaded = topics.first;
      expect(loaded.id, 't99_space');
      expect(loaded.titleEn, 'Space Adventure');
      expect(loaded.words.first.text, 'Star');
      expect(loaded.baseDir?.replaceAll(r'\', '/'), targetInstalledDir.path.replaceAll(r'\', '/'));
    });
  });
}
