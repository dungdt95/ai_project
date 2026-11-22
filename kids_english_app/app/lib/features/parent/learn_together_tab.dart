import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models.dart';

class LearnTogetherTab extends ConsumerWidget {
  const LearnTogetherTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider).value ?? const <Topic>[];
    final audio = ref.read(audioProvider);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: topics.length,
      itemBuilder: (ctx, i) {
        final topic = topics[i];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 2,
          child: ExpansionTile(
            initiallyExpanded: i == 0,
            leading: CircleAvatar(
              backgroundColor: AppColors.yellow,
              child: Text('${topic.order}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
            ),
            title: Text(
              "${topic.titleVi} (${topic.titleEn})",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text("${topic.sentences.length} câu giao tiếp gợi ý"),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const Text(
                      "💡 Mẹo cùng bé nói tiếng Anh tại nhà:",
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange),
                    ),
                    const SizedBox(height: 8),
                    for (final s in topic.sentences) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            IconButton.filled(
                              iconSize: 24,
                              style: IconButton.styleFrom(backgroundColor: AppColors.teal),
                              icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
                              onPressed: () => audio.play(s.audio, s.text, baseDir: topic.baseDir),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.text,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                                  ),
                                  Text(
                                    s.vi,
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                                  ),
                                  Text(
                                    "Phát âm: ${s.pronVi}",
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.orange),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
