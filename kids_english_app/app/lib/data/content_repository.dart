import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'models.dart';

/// Một nguồn nội dung (assets trong APK, hoặc các gói `.bvpack` đã cài ở giai đoạn sau).
abstract class ContentSource {
  Future<List<Topic>> loadTopics();
}

/// Đọc `assets/content/curriculum.json` rồi từng file chủ đề.
class AssetContentSource implements ContentSource {
  final String root;
  final AssetBundle? bundle;
  AssetContentSource({this.root = 'assets/content', this.bundle});

  @override
  Future<List<Topic>> loadTopics() async {
    final b = bundle ?? rootBundle;
    final cur = jsonDecode(await b.loadString('$root/curriculum.json')) as Map<String, dynamic>;
    final topics = <Topic>[];
    for (final entry in (cur['topics'] as List)) {
      final file = (entry as Map<String, dynamic>)['file'] as String;
      final j = jsonDecode(await b.loadString('$root/$file')) as Map<String, dynamic>;
      topics.add(Topic.fromJson(j));
    }
    return topics;
  }
}

/// Nguồn nạp chủ đề từ các gói đã cài trong bộ nhớ máy: `<installedPacksDir>/<topicId>/topic.json`.
/// Bỏ qua thư mục bắt đầu bằng "." (thư mục tạm/sao lưu của PackInstaller).
class FileContentSource implements ContentSource {
  FileContentSource(this.installedPacksDir);
  final Directory installedPacksDir;

  @override
  Future<List<Topic>> loadTopics() async {
    if (!await installedPacksDir.exists()) return [];

    final topics = <Topic>[];
    final entities = await installedPacksDir.list().toList();

    for (final entity in entities) {
      if (entity is! Directory) continue;
      final name = entity.path.replaceAll(r'\', '/').split('/').last;
      if (name.startsWith('.')) continue;
      final topicFile = File('${entity.path}/topic.json');
      if (await topicFile.exists()) {
        try {
          final json = jsonDecode(await topicFile.readAsString()) as Map<String, dynamic>;
          topics.add(Topic.fromJson(json, baseDir: entity.path));
        } catch (_) {}
      }
    }
    return topics;
  }
}

/// Gộp nhiều nguồn thành một danh sách chủ đề duy nhất, sắp theo level → order.
/// Chủ đề trùng id: nguồn đứng sau ghi đè nguồn đứng trước (gói cập nhật thắng built-in).
class ContentRegistry {
  final List<ContentSource> sources;
  ContentRegistry(this.sources);

  Future<List<Topic>> load() async {
    final byId = <String, Topic>{};
    for (final s in sources) {
      for (final t in await s.loadTopics()) {
        byId[t.id] = t;
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) {
        final c = a.level.compareTo(b.level);
        return c != 0 ? c : a.order.compareTo(b.order);
      });
    return list;
  }
}

/// Kiểm tra tính toàn vẹn của một chủ đề; trả về danh sách lỗi (rỗng = hợp lệ).
List<String> validateTopic(Topic t) {
  final errors = <String>[];
  final ids = <String>{};
  for (final w in t.words) {
    if (!ids.add(w.id)) errors.add('${t.id}: từ trùng id ${w.id}');
  }
  for (final l in t.lessons) {
    for (final w in l.newWords) {
      if (t.wordById(w) == null) errors.add('${l.id}: new_words tham chiếu từ không tồn tại "$w"');
    }
    if (l.sentenceId != null && t.sentenceById(l.sentenceId!) == null) {
      errors.add('${l.id}: sentence "${l.sentenceId}" không tồn tại');
    }
    for (final s in l.steps) {
      for (final w in s.words) {
        if (t.wordById(w) == null) errors.add('${l.id}/${s.type}: từ "$w" không tồn tại');
      }
    }
    final tip = l.parentTip;
    if (tip != null) {
      for (final sid in tip.sentenceIds) {
        if (t.sentenceById(sid) == null) errors.add('${l.id}: parent_tip tham chiếu câu "$sid" không tồn tại');
      }
    }
  }
  return errors;
}
