import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/content_repository.dart';
import '../../data/models.dart';

/// Nguồn nạp chủ đề từ các gói file đã cài đặt trong bộ nhớ máy
class FileContentSource implements ContentSource {
  FileContentSource(this.installedPacksDir);
  final Directory installedPacksDir;

  @override
  Future<List<Topic>> loadTopics() async {
    if (!await installedPacksDir.exists()) return [];

    final topics = <Topic>[];
    final entities = await installedPacksDir.list().toList();

    for (final entity in entities) {
      if (entity is Directory) {
        final topicFile = File('${entity.path}/topic.json');
        if (await topicFile.exists()) {
          try {
            final content = await topicFile.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            topics.add(Topic.fromJson(json, baseDir: entity.path));
          } catch (_) {}
        }
      }
    }
    return topics;
  }
}

class TopicPacksTab extends ConsumerStatefulWidget {
  const TopicPacksTab({super.key});

  @override
  ConsumerState<TopicPacksTab> createState() => _TopicPacksTabState();
}

class _TopicPacksTabState extends ConsumerState<TopicPacksTab> {
  bool _isImporting = false;

  Future<void> _importPack() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bvpack', 'zip'],
    );

    if (result.isEmpty || result.first.path == null) return;

    setState(() => _isImporting = true);
    final filePath = result.first.path!;

    try {
      final bytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final appDir = await getApplicationSupportDirectory();
      final packsDir = Directory('${appDir.path}/packs');
      if (!await packsDir.exists()) await packsDir.create(recursive: true);

      // Tìm pack.json hoặc topic.json để lấy ID
      String topicId = 'pack_${DateTime.now().millisecondsSinceEpoch}';
      for (final file in archive) {
        if (file.name == 'pack.json' || file.name == 'topic.json') {
          final content = utf8.decode(file.content as List<int>);
          final j = jsonDecode(content);
          if (j['id'] != null) topicId = j['id'];
          break;
        }
      }

      final targetDir = Directory('${packsDir.path}/$topicId');
      if (await targetDir.exists()) await targetDir.delete(recursive: true);
      await targetDir.create(recursive: true);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('${targetDir.path}/$filename');
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data);
        }
      }

      // Làm mới danh sách nguồn nội dung
      ref.invalidate(topicsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.teal,
            content: Text("Đã nạp thành công gói chủ đề: $topicId!"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Lỗi khi nạp gói: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.extension_rounded, color: AppColors.orange, size: 28),
                    SizedBox(width: 8),
                    Text(
                      "Nạp thêm chủ đề mới (.bvpack)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "Bạn có thể bổ sung các chủ đề học mới (Level 2, Level 3...) bất cứ lúc nào bằng cách chọn file gói dữ liệu .bvpack hoặc .zip mà không cần cài lại app.",
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: _isImporting ? null : _importPack,
                  icon: _isImporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.file_upload_outlined),
                  label: Text(_isImporting ? "Đang xử lý..." : "Chọn file gói từ thiết bị"),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text("Danh sách các chủ đề hiện có:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        topicsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text("Lỗi: $e"),
          data: (topics) => Column(
            children: topics.map((t) {
              final isBuiltin = t.baseDir == null;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isBuiltin ? AppColors.teal : AppColors.pink,
                    child: Icon(isBuiltin ? Icons.check_circle_outline : Icons.cloud_done_outlined, color: Colors.white),
                  ),
                  title: Text(t.titleEn, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${t.titleVi} • ${t.words.length} từ vựng • ${isBuiltin ? 'Tích hợp sẵn' : 'Gói cài thêm'}"),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
